#!/bin/bash
# Run the menu scraper locally and push results to Supabase.
# Requires lambda_scraper/.env with SUPABASE_URL + SUPABASE_SERVICE_KEY (service_role, not anon).

set -euo pipefail
cd "$(dirname "$0")/lambda_scraper"

if [[ ! -f .env ]]; then
  echo "❌ Missing lambda_scraper/.env — copy .env.example and add your Supabase service_role key."
  exit 1
fi

if ! grep -qE '^SUPABASE_URL=.+$' .env || ! grep -qE '^SUPABASE_SERVICE_KEY=.+$' .env; then
  echo "❌ .env must set non-empty SUPABASE_URL and SUPABASE_SERVICE_KEY (service_role from Supabase → Settings → API)."
  exit 1
fi

pip3 install -q -r requirements.txt
python3 scraper.py
