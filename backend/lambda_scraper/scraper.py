"""
Eagle Eats — AWS Lambda Menu Scraper
Runs daily at 5 AM CST via CloudWatch cron: 0 11 * * ? *

Scrapes all 5 UNT dining halls from diningmenus.unt.edu,
parses menu items + nutrition labels, writes to Supabase via REST API.

Uses only `requests` + `beautifulsoup4` — no heavy SDKs, no binary deps.
"""

import os
import re
import time
import json
import logging
from datetime import datetime, timezone, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

BASE_URL = "https://diningmenus.unt.edu"
BROWSER_UA = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 "
    "Mobile/15E148 Safari/604.1"
)
HEADERS = {"User-Agent": BROWSER_UA}
REQUEST_TIMEOUT = 20

HALLS = [
    {"id": "mean-greens",   "location_id": 10},
    {"id": "champs",        "location_id": 15},
    {"id": "bruceteria",    "location_id": 20},
    {"id": "kitchen-west",  "location_id": 25},
    {"id": "eagle-landing", "location_id": 31},
]

DIETARY_TAGS = {
    "Vegan":      {"id": "vegan",      "label": "Vegan",      "color": "00853E", "icon": "leaf.fill"},
    "Vegetarian": {"id": "vegetarian", "label": "Vegetarian", "color": "27AE60", "icon": "leaf"},
    "Halal":      {"id": "halal",      "label": "Halal",      "color": "F59E0B", "icon": "checkmark.circle.fill"},
}

# ---------------------------------------------------------------------------
# Supabase REST API (no SDK needed)
# ---------------------------------------------------------------------------

class SupabaseREST:
    """Lightweight Supabase client using raw HTTP requests."""

    def __init__(self):
        self.url = os.environ["SUPABASE_URL"].rstrip("/")
        self.key = os.environ["SUPABASE_SERVICE_KEY"]
        self.headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates",
        }

    def upsert(self, table: str, rows: list[dict]):
        """Upsert rows into a table (POST with merge-duplicates)."""
        endpoint = f"{self.url}/rest/v1/{table}"
        resp = requests.post(endpoint, headers=self.headers,
                             json=rows, timeout=30)
        if resp.status_code not in (200, 201):
            logger.error(f"Supabase upsert {table} failed: {resp.status_code} {resp.text[:200]}")
        return resp

    def select(self, table: str, query: str) -> list[dict]:
        """Select rows from a table with query parameters."""
        endpoint = f"{self.url}/rest/v1/{table}?{query}"
        headers = {**self.headers, "Prefer": ""}
        resp = requests.get(endpoint, headers=headers, timeout=15)
        if resp.status_code == 200:
            return resp.json()
        logger.error(f"Supabase select {table} failed: {resp.status_code}")
        return []

    def rpc(self, function_name: str):
        """Call a Postgres function via Supabase RPC."""
        endpoint = f"{self.url}/rest/v1/rpc/{function_name}"
        resp = requests.post(endpoint, headers=self.headers, json={}, timeout=15)
        return resp

# ---------------------------------------------------------------------------
# HTML Parsing — Menu Page
# ---------------------------------------------------------------------------

def parse_meal_period(label: str) -> str | None:
    upper = label.upper().strip()
    if "BREAKFAST" in upper or "BKFST" in upper:
        return "Breakfast"
    if "LUNCH" in upper:
        return "Lunch"
    if "DINNER" in upper:
        return "Dinner"
    if "LATE" in upper or "NIGHT" in upper:
        return "Late Night"
    return None


def map_category(station_name: str) -> str:
    lower = station_name.lower()
    mapping = [
        (["grill"], "Grill"),
        (["soup"], "Soup & Salad"),
        (["pizza", "pasta"], "Pizza & Pasta"),
        (["asian", "basil", "bamboo", "wok"], "Asian Station"),
        (["deli", "sandwich"], "Deli"),
        (["bakery", "bread", "bakeshop"], "Bakery"),
        (["dessert", "cobbler", "ice cream"], "Desserts"),
        (["beverage", "drink"], "Beverages"),
        (["breakfast"], "Breakfast"),
        (["vegan", "leaf"], "Vegan"),
        (["salad", "fresh"], "Salad Bar"),
        (["performance", "protein"], "Performance"),
        (["side"], "Sides"),
    ]
    for keywords, category in mapping:
        if any(kw in lower for kw in keywords):
            return category
    return "Entrées"


def parse_dietary_tags(class_str: str) -> list[dict]:
    tags = []
    for css_class, tag_data in DIETARY_TAGS.items():
        if css_class in class_str:
            tags.append(tag_data)
    return tags


def scrape_menu_page(hall: dict, date_str: str) -> list[dict]:
    """Scrape a single hall's menu page and return parsed items."""
    url = f"{BASE_URL}/?locationID={hall['location_id']}&date={date_str}"
    logger.info(f"Scraping {hall['id']} → {url}")

    try:
        resp = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
    except requests.RequestException as e:
        logger.error(f"Failed to fetch {hall['id']}: {e}")
        return []

    html = resp.text
    items = []
    seen_ids = set()

    # Build tab → meal period mapping
    tab_map = {}
    tab_pattern = re.compile(
        r'href="#([A-Za-z0-9_-]+)"[^>]*data-toggle="tab"[^>]*>\s*([^<]+?)\s*<'
    )
    for match in tab_pattern.finditer(html):
        div_id = match.group(1)
        label = match.group(2).strip()
        period = parse_meal_period(label)
        if period:
            tab_map[div_id] = period
            logger.info(f"  Tab #{div_id} → {period}")

    # Split into tab panes
    pane_pattern = re.compile(
        r'<div[^>]+class="tab-pane[^"]*"[^>]+id="([^"]+)"'
    )
    pane_matches = list(pane_pattern.finditer(html))

    if not pane_matches or all(m.group(1) not in tab_map for m in pane_matches):
        logger.info(f"  No tab panes — full-page fallback for {hall['id']}")
        page_items = parse_panel_items(html, hall["id"], "Lunch")
        for item in page_items:
            if "Dinner" not in item["meal_periods"]:
                item["meal_periods"].append("Dinner")
            items.append(item)
        return items

    for i, pane_match in enumerate(pane_matches):
        div_id = pane_match.group(1)
        period = tab_map.get(div_id)
        if not period:
            continue
        start = pane_match.start()
        end = pane_matches[i + 1].start() if i + 1 < len(pane_matches) else len(html)
        pane_html = html[start:end]

        pane_items = parse_panel_items(pane_html, hall["id"], period)
        for item in pane_items:
            if item["id"] in seen_ids:
                for existing in items:
                    if existing["id"] == item["id"] and period not in existing["meal_periods"]:
                        existing["meal_periods"].append(period)
                continue
            seen_ids.add(item["id"])
            items.append(item)

    logger.info(f"  {hall['id']}: {len(items)} items parsed")
    return items


def parse_panel_items(html: str, hall_id: str, period: str) -> list[dict]:
    """Extract food items from panel blocks within an HTML fragment."""
    items = []
    item_pattern = re.compile(
        r'<li\s+id="(\d+)"\s+class="list-group-item\s+borderless\s+food-item([^"]*)"\s*>'
        r'([^<]+)</li>'
    )
    panel_splits = html.split('class="panel panel-default panel-menu"')

    for panel_chunk in panel_splits[1:]:
        heading_match = re.search(r'<p[^>]+>\s*(.*?)\s*</p>', panel_chunk, re.DOTALL)
        raw_heading = heading_match.group(1) if heading_match else ""
        station_name = re.sub(r'<[^>]+>', '', raw_heading).strip()
        category = map_category(station_name)

        for m in item_pattern.finditer(panel_chunk):
            recipe_id = m.group(1)
            tags_str = m.group(2)
            name = m.group(3).strip()
            if not name:
                continue

            item_id = f"{hall_id}-{recipe_id}"
            items.append({
                "id": item_id,
                "hall_id": hall_id,
                "recipe_id": recipe_id,
                "name": name,
                "description": "",
                "category": category,
                "station": station_name,
                "meal_periods": [period],
                "dietary_tags": parse_dietary_tags(tags_str),
            })

    return items

# ---------------------------------------------------------------------------
# HTML Parsing — Nutrition Label
# ---------------------------------------------------------------------------

def scrape_nutrition(recipe_id: str) -> dict | None:
    """Fetch and parse a nutrition label page."""
    url = f"{BASE_URL}/label.aspx?recipeNum={recipe_id}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
    except requests.RequestException as e:
        logger.warning(f"Nutrition fetch failed for {recipe_id}: {e}")
        return None

    html = resp.text

    def extract_value(label: str) -> float | None:
        pattern = re.escape(label) + r'[^<]*<div class="weight">([0-9.]+)'
        match = re.search(pattern, html, re.DOTALL)
        return float(match.group(1)) if match else None

    calories = extract_value("Calories")
    protein = extract_value("Protein")
    carbs = extract_value("Total Carbohydrates")
    fat = extract_value("Total Fat")

    if calories is None and protein is None:
        return None

    serving_match = re.search(
        r'<span class="highlighted">([^<]+)</span>\s*Serving Size', html
    )

    return {
        "recipe_id": recipe_id,
        "calories": calories or 0,
        "protein": protein or 0,
        "carbohydrates": carbs or 0,
        "fat": fat or 0,
        "fiber": extract_value("Dietary Fiber"),
        "sugar": extract_value("Sugars"),
        "sodium": extract_value("Sodium"),
        "serving_size": serving_match.group(1).strip() if serving_match else None,
    }

# ---------------------------------------------------------------------------
# Supabase Writers
# ---------------------------------------------------------------------------

def write_menu_items(sb: SupabaseREST, items: list[dict], menu_date: str):
    """Upsert menu items for today into Supabase."""
    if not items:
        return

    rows = []
    for item in items:
        rows.append({
            "id": item["id"],
            "hall_id": item["hall_id"],
            "recipe_id": item["recipe_id"],
            "name": item["name"],
            "description": item["description"],
            "category": item["category"],
            "station": item["station"],
            "meal_periods": item["meal_periods"],
            "dietary_tags": json.dumps(item["dietary_tags"]),
            "menu_date": menu_date,
        })

    for i in range(0, len(rows), 100):
        batch = rows[i:i + 100]
        sb.upsert("menu_items", batch)
        logger.info(f"  Upserted {len(batch)} menu items (batch {i // 100 + 1})")


def write_nutrition(sb: SupabaseREST, nutrition_data: list[dict]):
    """Upsert nutrition info into Supabase."""
    if not nutrition_data:
        return

    for i in range(0, len(nutrition_data), 50):
        batch = nutrition_data[i:i + 50]
        sb.upsert("nutrition_info", batch)
        logger.info(f"  Upserted {len(batch)} nutrition records (batch {i // 50 + 1})")


def log_scrape(sb: SupabaseREST, date_str: str, halls_count: int, items_count: int,
               nutrition_count: int, duration_ms: int, status: str, error: str = None):
    sb.upsert("scrape_log", [{
        "scrape_date": date_str,
        "halls_scraped": halls_count,
        "items_scraped": items_count,
        "nutrition_fetched": nutrition_count,
        "duration_ms": duration_ms,
        "status": status,
        "error_message": error,
    }])

# ---------------------------------------------------------------------------
# Lambda Handler
# ---------------------------------------------------------------------------

def lambda_handler(event, context):
    """
    Entry point for AWS Lambda.
    Triggered by CloudWatch cron: 0 11 * * ? * (5 AM CST daily)
    """
    start_time = time.time()
    logger.info("=== Eagle Eats Scraper Starting ===")

    cst = timezone(timedelta(hours=-6))
    today = datetime.now(cst)
    date_str_for_unt = today.strftime("%m/%d/%Y")
    date_str_iso = today.strftime("%Y-%m-%d")

    logger.info(f"Scraping menus for: {date_str_for_unt} (ISO: {date_str_iso})")

    sb = SupabaseREST()
    all_items = []
    halls_scraped = 0

    # 1. Scrape all 5 halls
    for hall in HALLS:
        try:
            items = scrape_menu_page(hall, date_str_for_unt)
            all_items.extend(items)
            halls_scraped += 1
        except Exception as e:
            logger.error(f"Error scraping {hall['id']}: {e}")

    logger.info(f"Total menu items scraped: {len(all_items)} from {halls_scraped} halls")

    # 2. Write menu items to Supabase
    write_menu_items(sb, all_items, date_str_iso)

    # 3. Collect unique recipe IDs that need nutrition data
    unique_recipe_ids = list({item["recipe_id"] for item in all_items})

    # Check which ones we already have cached in Supabase
    existing_ids = set()
    for i in range(0, len(unique_recipe_ids), 100):
        batch = unique_recipe_ids[i:i + 100]
        in_list = ",".join(batch)
        rows = sb.select("nutrition_info", f"recipe_id=in.({in_list})&select=recipe_id")
        existing_ids.update(row["recipe_id"] for row in rows)

    missing_ids = [rid for rid in unique_recipe_ids if rid not in existing_ids]

    logger.info(
        f"Nutrition: {len(unique_recipe_ids)} unique recipes, "
        f"{len(existing_ids)} cached, {len(missing_ids)} to fetch"
    )

    # 4. Fetch missing nutrition data (parallel, capped at 10 threads)
    nutrition_results = []
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {
            executor.submit(scrape_nutrition, rid): rid
            for rid in missing_ids
        }
        for future in as_completed(futures):
            rid = futures[future]
            try:
                result = future.result()
                if result:
                    nutrition_results.append(result)
            except Exception as e:
                logger.warning(f"Nutrition error for {rid}: {e}")

    logger.info(f"Fetched {len(nutrition_results)} new nutrition records")

    # 5. Write nutrition to Supabase
    write_nutrition(sb, nutrition_results)

    # 6. Cleanup old menu data
    try:
        sb.rpc("cleanup_old_menus")
        logger.info("Old menu data cleaned up")
    except Exception as e:
        logger.warning(f"Cleanup function error: {e}")

    # 7. Log the scrape
    duration_ms = int((time.time() - start_time) * 1000)
    status = "success" if halls_scraped == len(HALLS) else "partial"
    log_scrape(sb, date_str_iso, halls_scraped, len(all_items),
               len(nutrition_results), duration_ms, status)

    result = {
        "statusCode": 200,
        "body": {
            "date": date_str_iso,
            "halls_scraped": halls_scraped,
            "items_scraped": len(all_items),
            "nutrition_fetched": len(nutrition_results),
            "nutrition_cached": len(existing_ids),
            "duration_ms": duration_ms,
        }
    }
    logger.info(f"=== Scraper Complete: {json.dumps(result['body'])} ===")
    return result


# For local testing
if __name__ == "__main__":
    os.environ.setdefault("SUPABASE_URL", "")
    os.environ.setdefault("SUPABASE_SERVICE_KEY", "")
    result = lambda_handler({}, None)
    print(json.dumps(result, indent=2))
