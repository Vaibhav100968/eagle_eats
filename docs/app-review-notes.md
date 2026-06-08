# App Store Review Notes — Mean Eats

Copy into **App Store Connect → App Review Information → Notes**.

---

Mean Eats is an **independent student project** for UNT dining. It is **not affiliated with or endorsed by the University of North Texas**.

## How to test without a UNT account

Tap **Continue as Guest** on the welcome screen. Without login, reviewers can:

- Browse all dining halls and live menus
- Search/filter menus and view nutrition
- Build a plate and track macros locally
- View campus map, retail “Where to Spend” locations
- Use settings, privacy policy, and health disclaimer

## How to test with UNT login (optional)

Tap **Sign In with UNT** → opens UNT’s official meal plan portal (`mealplans.unt.edu`) in a secure web view. We **do not store UNT passwords**.

After login, the **Meal Plan** tab shows swipes/flex balance (requires a valid UNT account).

If you do not have a UNT test account, guest mode is sufficient to review core functionality.

## Authentication note

Login uses **UNT’s institutional meal plan portal**, not third-party social login. Sign in with Apple is not required for this flow.

## Data & privacy

- First-party usage analytics only (no IDFA / no cross-app ad tracking)
- Privacy: https://vaibhav100968.github.io/eagle_eats/privacy/
- Support: https://vaibhav100968.github.io/eagle_eats/support/
- Terms: https://vaibhav100968.github.io/eagle_eats/terms/

## Menu data

Menus are aggregated from **public UNT dining web pages** via our backend (AWS Lambda + Supabase). Data is informational, not an official UNT communication.

## User-generated content

Public hall check-ins are **disabled in v1.0**. Photo reviews and feedback include report/block flows in-app.

## Contact

va12345bhavg@gmail.com

---

## App Privacy questionnaire (guide)

Declare in App Store Connect to match the privacy policy:

| Data type | Collected | Linked to user | Tracking | Purpose |
|-----------|-----------|----------------|----------|---------|
| Product interaction | Yes | No (guest) | No | Analytics |
| User ID | Yes | No (guest ID) | No | Analytics |
| Name | Yes (if signed in) | Yes | No | App functionality |
| Coarse location | Optional | No | No | App functionality |
| Photos | Optional | No | No | App functionality |
| Other user content | Optional | No | No | App functionality |

**Tracking:** No  
**Third-party advertising:** No
