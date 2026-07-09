# Developer Setup

Step-by-step guide to clone Mean Eats and run it locally on a Mac.

## Prerequisites

| Tool | Version | Notes |
|------|---------|--------|
| macOS | 14+ recommended | Required for Xcode |
| Xcode | 16.0+ | App Store or [developer.apple.com](https://developer.apple.com/xcode/) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | latest | Generates `.xcodeproj` from `project.yml` |
| Python | 3.11+ | Only needed for scraper unit tests / Lambda packaging |
| Git | any | Clone the repo |

Optional for backend work:

- AWS account (Lambda deploy)
- Supabase project (menus + analytics)

## 1. Clone the repository

```bash
git clone https://github.com/Vaibhav100968/MeanEats.git
cd MeanEats
```

## 2. Install XcodeGen

```bash
brew install xcodegen
# or: mint install yonaskolb/XcodeGen
```

Confirm:

```bash
xcodegen --version
```

## 3. Configure secrets

The app loads Supabase credentials from `Secrets.plist` (gitignored).

```bash
cp Secrets.plist.example Secrets.plist
```

Edit `Secrets.plist` and replace the placeholders:

| Key | Value |
|-----|--------|
| `SUPABASE_URL` | `https://YOUR_PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase **anon** (public) key |

Without a valid `Secrets.plist`, the app will crash on launch when `SupabaseConfig` loads.

> Never commit real keys. `Secrets.plist` is listed in `.gitignore`.

## 4. Generate the Xcode project

```bash
xcodegen generate
```

This creates `eaglesEats2.xcodeproj` from `project.yml` (app + widget + unit tests).

## 5. Open and run

```bash
open eaglesEats2.xcodeproj
```

In Xcode:

1. Select the **eaglesEats2** scheme.
2. Choose an **iPhone** simulator (iOS 17+).
3. Press **Run** (⌘R).

### Signing

`project.yml` sets `DEVELOPMENT_TEAM` and Automatic signing. If build fails on signing:

1. Select the **eaglesEats2** target → **Signing & Capabilities**.
2. Choose your personal team, or clear the team for Simulator-only Debug builds.

The widget extension (`EagleEatsWidget`) must use the same team / matching bundle ID prefix.

## 6. Guest vs signed-in mode

| Mode | How | What you get |
|------|-----|----------------|
| **Guest** | Tap **Continue as Guest** | Menus, nutrition, maps, plate builder |
| **UNT sign-in** | Tap **Sign In with UNT** | Same as guest + Swipes / Flex from the official portal |

Sign-in opens `mealplans.unt.edu` in a WebView. Mean Eats never stores your UNT password.

## 7. Run tests

### One-command (recommended)

```bash
./scripts/run-tests.sh
```

This runs:

1. Python scraper unit tests (`backend/lambda_scraper/test_scraper.py`)
2. Swift XCTest suite via `xcodebuild` (if Xcode is available)

### Swift only

```bash
xcodegen generate
xcodebuild test \
  -project eaglesEats2.xcodeproj \
  -scheme eaglesEats2 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet
```

### Python scraper only

```bash
cd backend/lambda_scraper
python3 -m unittest test_scraper.py -v
```

## 8. Backend (optional)

Menu scraping is **not** required to run the iOS UI if your Supabase project already has menu rows. To work on the scraper:

```bash
cd backend/lambda_scraper
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Package for AWS Lambda:

```bash
cd backend
./deploy.sh
```

Apply SQL schemas in the Supabase SQL editor (order matters for RLS):

1. `backend/supabase_schema.sql`
2. `backend/supabase_rls_fix.sql`
3. `backend/supabase_app_events.sql` (guest / analytics events)

Set Lambda env vars: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (service role — never ship this in the iOS app).

## Project layout (quick map)

```
MeanEats/
├── Views/              SwiftUI screens
├── ViewModels/         AppState, plate/history VMs
├── Services/           Networking, auth, persistence, engines
├── Models/             DiningHall, MenuItem, MealPlanInfo, …
├── DesignSystem/       Colors, fonts, shared UI
├── EagleEatsWidget/    WidgetKit extension
├── Tests/              XCTest unit tests
├── backend/            Lambda scraper + SQL
├── docs/               Architecture, setup, legal pages
├── scripts/            Local QA helpers
├── project.yml         XcodeGen definition
└── Secrets.plist.example
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Missing SUPABASE_URL` crash | Create `Secrets.plist` from the example |
| No `.xcodeproj` | Run `xcodegen generate` |
| Empty menus | Confirm Supabase has today's `menu_items`, or run the scraper |
| Signing errors | Set your Development Team on app + widget targets |
| Tests can't find module | Regenerate project; scheme must include `MeanEatsTests` |

## More docs

- [Architecture & design notes](ARCHITECTURE.md)
- [App Store review notes](app-review-notes.md)
- [GitHub Pages / legal URLs](README.md)
