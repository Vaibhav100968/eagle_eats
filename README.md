# Mean Eats

**UNT Dining, Beautifully Simplified**

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/me/app/mean-eats/id6778164060)

Mean Eats is a native iOS dining companion built for University of North Texas students. Browse live menus across all five dining halls, build plates with macro tracking, check what's open right now, and keep your meal plan balances close at hand — all in one place.

> **Disclaimer:** Mean Eats is an independent student project and is not affiliated with or endorsed by the University of North Texas.

---

## About

Eating on campus shouldn't mean juggling five different websites, guessing what's open, or doing mental math on your swipes and Flex balance. Mean Eats brings UNT dining into a single, thoughtfully designed app.

Whether you're a freshman figuring out Kerr Hall for the first time or a senior optimizing every swipe before the semester ends, Mean Eats helps you make better dining decisions without the friction.

**Sign in** with your UNT account through the official meal plan portal to see Dining Swipes and Flex balances with auto-refresh. **Continue as Guest** to explore menus, nutrition info, hall hours, and maps — no account required.

Mean Eats never stores your UNT password. Credentials are entered directly on UNT's secure portal.

---

## Features

| | |
|---|---|
| **Live Menus** | Daily menus for all five UNT dining halls, updated automatically |
| **Smart Recommendations** | Personalized picks based on time of day, dietary preferences, and habits |
| **Plate Builder** | Build a virtual plate and track calories, protein, carbs, and fat |
| **Meal Plan Dashboard** | Dining Swipes and Flex balance at a glance, with spending insights |
| **Hall Hours & Maps** | See what's open now, find the nearest hall, and get directions |
| **Dietary Filters** | Quickly spot vegetarian, vegan, and allergen-friendly options |
| **Offline Mode** | Cached menus keep working when connectivity is spotty |
| **Guest Mode** | Full menu browsing without signing in |

---

## Download

**[Get Mean Eats on the App Store →](https://apps.apple.com/me/app/mean-eats/id6778164060)**

Requires iOS 17 or later. Built for iPhone.

---

## Quick start (developers)

```bash
git clone https://github.com/Vaibhav100968/MeanEats.git
cd MeanEats
brew install xcodegen          # once
cp Secrets.plist.example Secrets.plist   # add your Supabase URL + anon key
xcodegen generate
open eaglesEats2.xcodeproj     # Run on an iPhone simulator (iOS 17+)
```

Full walkthrough (signing, guest mode, backend, troubleshooting): **[docs/SETUP.md](docs/SETUP.md)**

### Tests & QA

```bash
./scripts/run-tests.sh
```

| Suite | Location |
|-------|----------|
| Swift unit tests | `Tests/MeanEatsTests/` (meal periods, portal parsing, content filter) |
| Python scraper tests | `backend/lambda_scraper/test_scraper.py` |
| Runner script | `scripts/run-tests.sh` |

---

## Documentation

| Doc | What it covers |
|-----|----------------|
| [Setup guide](docs/SETUP.md) | Clone, secrets, XcodeGen, run, test, optional Lambda |
| [Architecture](docs/ARCHITECTURE.md) | System diagram, client layers, auth, scrape pipeline, design decisions |
| [App Store review notes](docs/app-review-notes.md) | Reviewer context for Guideline compliance |
| [GitHub Pages](docs/README.md) | Privacy / terms / support hosting |

---

## Support & Legal

- [Privacy Policy](https://vaibhav100968.github.io/MeanEats/privacy/)
- [Terms of Service](https://vaibhav100968.github.io/MeanEats/terms/)
- [Support](https://vaibhav100968.github.io/MeanEats/support/)

**Contact:** [va12345bhavg@gmail.com](mailto:va12345bhavg@gmail.com)

---

## Built With

Swift · SwiftUI · Supabase · AWS Lambda · XcodeGen

Made with care for the UNT community.
