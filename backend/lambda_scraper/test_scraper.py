"""
Unit tests for Mean Eats Lambda scraper helpers.

Run from repo root:
  python3 -m unittest backend.lambda_scraper.test_scraper -v

Or from this directory:
  python3 -m unittest test_scraper.py -v
"""

from __future__ import annotations

import os
import sys
import unittest

# Allow `import scraper` when running from this folder or via unittest discovery.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scraper import (  # noqa: E402
    JUNK_ITEM_NAMES,
    map_category,
    parse_dietary_tags,
    parse_meal_period,
)


class MealPeriodParsingTests(unittest.TestCase):
    def test_breakfast_aliases(self):
        self.assertEqual(parse_meal_period("Breakfast"), "Breakfast")
        self.assertEqual(parse_meal_period("BKFST"), "Breakfast")

    def test_standard_periods(self):
        self.assertEqual(parse_meal_period("Lunch"), "Lunch")
        self.assertEqual(parse_meal_period("Dinner"), "Dinner")
        self.assertEqual(parse_meal_period("Late Night"), "Late Night")

    def test_unknown_returns_none(self):
        self.assertIsNone(parse_meal_period("Brunch Special"))


class StationCategoryTests(unittest.TestCase):
    def test_known_stations(self):
        self.assertEqual(map_category("The Grill"), "Grill")
        self.assertEqual(map_category("Soup of the Day"), "Soup & Salad")
        self.assertEqual(map_category("Pizza Corner"), "Pizza & Pasta")
        self.assertEqual(map_category("Bamboo Wok"), "Asian Station")
        self.assertEqual(map_category("Deli Sandwiches"), "Deli")

    def test_fallback_entrees(self):
        self.assertEqual(map_category("Chef's Table"), "Entrées")


class DietaryTagTests(unittest.TestCase):
    def test_extracts_known_css_classes(self):
        tags = parse_dietary_tags("item Vegan Vegetarian other")
        ids = {t["id"] for t in tags}
        self.assertIn("vegan", ids)
        self.assertIn("vegetarian", ids)

    def test_empty_when_no_match(self):
        self.assertEqual(parse_dietary_tags("plain-item"), [])


class JunkFilterTests(unittest.TestCase):
    def test_placeholder_names_are_blocked(self):
        self.assertIn("menu item #1", JUNK_ITEM_NAMES)
        self.assertIn("line not available", JUNK_ITEM_NAMES)


if __name__ == "__main__":
    unittest.main()
