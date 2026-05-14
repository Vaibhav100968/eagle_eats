#!/bin/bash
# ============================================================
# Package Lambda scraper for deployment to AWS
# Run from: backend/
# Output: lambda_package.zip (upload to AWS Lambda console)
# ============================================================

set -e

echo "📦 Packaging Eagle Eats Lambda scraper..."

cd lambda_scraper

# Clean old package
rm -rf package lambda_package.zip

# Install dependencies into package/
pip install -r requirements.txt -t package/ --quiet

# Copy scraper into package
cp scraper.py package/

# Zip it up
cd package
zip -r9 ../lambda_package.zip . -x "*.pyc" "__pycache__/*"
cd ..

# Cleanup
rm -rf package

echo "✅ Created lambda_package.zip ($(du -h lambda_package.zip | cut -f1))"
echo ""
echo "Next steps:"
echo "  1. Go to AWS Lambda Console → Create Function"
echo "  2. Runtime: Python 3.12"
echo "  3. Handler: scraper.lambda_handler"
echo "  4. Upload lambda_package.zip"
echo "  5. Set environment variables:"
echo "     SUPABASE_URL = https://your-project.supabase.co"
echo "     SUPABASE_SERVICE_KEY = your-service-role-key"
echo "  6. Set timeout to 5 minutes (300 seconds)"
echo "  7. Set memory to 512 MB"
echo "  8. Add CloudWatch trigger: cron(0 11 * * ? *)"
echo "     (= 5 AM CST / 6 AM CDT daily)"
