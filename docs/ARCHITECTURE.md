# Architecture & Design Notes

Mean Eats is a native iOS app for UNT dining. This document explains how the pieces fit together and why key decisions were made.

## High-level system

```
┌─────────────────────┐     REST (anon key)      ┌──────────────────┐
│  Mean Eats (iOS)    │ ◄──────────────────────► │     Supabase     │
│  SwiftUI + Widget   │                          │  Postgres + RLS  │
└─────────────────────┘                          └────────▲─────────┘
                                                          │ upsert
                                                          │ (service key)
                                                 ┌────────┴─────────┐
                                                 │  AWS Lambda      │
                                                 │  menu scraper    │
                                                 │  (daily 5 AM CST)│
                                                 └────────▲─────────┘
                                                          │ scrape
                                                 ┌────────┴─────────┐
                                                 │ diningmenus.unt  │
                                                 └──────────────────┘
```

**Design goal:** keep the phone app thin on scraping. Menus are collected server-side once per day; the client reads structured rows and caches them for offline use.

## Client architecture

### Layers

| Layer | Responsibility |
|-------|----------------|
| **Views** | SwiftUI screens (`Home`, `Plate`, `Meal Plan`, `Settings`) |
| **ViewModels / AppState** | Auth gate, plate/history state, settings |
| **Services** | Networking, persistence, portal parsing, analytics |
| **Engines** | Recommendations, budget, habits, context (“what’s good right now”) |
| **Models** | `DiningHall`, `MenuItem`, `MealPlanInfo`, etc. |
| **DesignSystem** | UNT green palette, typography, shared controls |

### Auth & meal plan

1. User chooses **Guest** or **Sign In with UNT**.
2. Sign-in presents UNT’s official portal in a `WKWebView` (`mealplans.unt.edu`).
3. After login, `BalanceScraper` parses visible portal text for swipes / Flex — **passwords are never stored** (`KeychainService` only tracks session validity flags / non-password secrets).
4. Guest identity is a local UUID used for optional event tracking (`GuestIdentityService` + `EventTrackingService`).

### Menu data path

1. Lambda scrapes each hall (`location_id`) from `diningmenus.unt.edu`.
2. Rows land in Supabase tables: `dining_halls`, `menu_items`, `nutrition_info` (+ scrape logs / app events).
3. `DiningService` fetches today’s `menu_items` via PostgREST, joins nutrition, groups by hall, and writes a local cache (`UserDefaults`) for offline mode.
4. Widget reads shared widget models / timeline from the same ecosystem.

### Intelligence engines (on-device)

These are pure client-side heuristics over local history and current context — not a remote ML service:

- **RecommendationEngine** — ranks items from time of day, diet prefs, and habits
- **BudgetEngine** — Flex burn rate / spending insights
- **HabitEngine / ContextEngine** — “right now” suggestions
- **ValueEngine / OutcomeAnalysis** — post-meal learning signals

Keeping this on-device avoids shipping meal history to a custom backend beyond optional analytics events.

## Backend design decisions

| Decision | Rationale |
|----------|-----------|
| **Scrape in Lambda, not on device** | Stable schedule, one IP/policy surface, smaller app binary, no HTML parsing on every launch |
| **Supabase as source of truth** | Simple REST + RLS; SQL schema lives in `backend/*.sql` |
| **Anon key in the app** | Read-only client access under RLS; writes use service role only in Lambda |
| **`requests` + BeautifulSoup** | Lightweight Lambda package; no heavy SDKs |
| **Junk item filter** | UNT closed-hall placeholder rows are dropped before upsert |

## Security & privacy notes

- UNT credentials stay inside the portal WebView.
- `Secrets.plist` is gitignored; only `Secrets.plist.example` is committed.
- Privacy Manifest (`PrivacyInfo.xcprivacy`) declares analytics / data collection for App Store review.
- Content moderation helpers (`ContentFilter`, `ContentModerationService`) support App Store Guideline 1.2 for user-generated text/photos.

## Testing strategy

| Suite | What it covers |
|-------|----------------|
| `Tests/MeanEatsTests` | Pure Swift logic: meal-period windows, portal balance parsing, content filter, meal-plan display helpers |
| `backend/lambda_scraper/test_scraper.py` | Meal-period labels, station category mapping, dietary tag parsing |
| `scripts/run-tests.sh` | One-command local QA entrypoint |

UI / end-to-end portal flows are exercised manually (portal HTML changes frequently and is a poor fit for brittle snapshot tests).

## Key files

| Path | Role |
|------|------|
| `project.yml` | XcodeGen definition (app + widget + tests) |
| `Services/DiningService.swift` | Supabase menu fetch + offline cache |
| `Services/MealPlanService.swift` | Cache + `BalanceScraper` |
| `Services/SupabaseConfig.swift` | Loads `Secrets.plist` |
| `backend/lambda_scraper/scraper.py` | Daily scrape pipeline |
| `backend/supabase_schema.sql` | Core tables |

## Future directions (non-binding)

- Expand XCTest coverage around recommendation scoring with fixture menus
- CI workflow running `scripts/run-tests.sh` on PRs
- Stronger typed API client layer if Supabase surface grows
