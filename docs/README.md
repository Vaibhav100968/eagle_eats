# GitHub Pages setup (privacy & support only)

Menu scraping runs on **AWS Lambda** — not GitHub Actions.

## One-time setup

1. Open **https://github.com/Vaibhav100968/eagle_eats/settings/pages**
2. Under **Build and deployment** → **Source**, choose **Deploy from a branch**
3. **Branch:** `main` → **Folder:** `/docs`
4. Click **Save**

After ~1 minute, these URLs should work:

- https://vaibhav100968.github.io/eagle_eats/
- https://vaibhav100968.github.io/eagle_eats/privacy/
- https://vaibhav100968.github.io/eagle_eats/support/

Use the privacy and support URLs in **App Store Connect**.

## Updating

Edit the HTML files in `docs/` and push to `main`. GitHub Pages redeploys automatically.
