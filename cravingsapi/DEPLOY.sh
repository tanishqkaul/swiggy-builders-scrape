#!/bin/bash
# CravingsAPI — Quick Deployment Script
# Usage: bash DEPLOY.sh

set -e

echo "🚀 CravingsAPI Deployment Helper"
echo "=================================="
echo ""

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "❌ Not in a git repository. Run this from cravingsapi/ root."
    exit 1
fi

# Check what we're deploying
echo "📦 Files to deploy:"
ls -lh index.html README.md SUBMISSION.md STATUS.md
echo ""

echo "🌐 Deployment Options:"
echo ""
echo "Option 1: GitHub Pages (Recommended)"
echo "  - Pushes to origin/main and uses GitHub Pages"
echo "  - Live at: https://yourusername.github.io/swiggy-builders-scrape/cravingsapi/"
echo ""
echo "Option 2: Vercel"
echo "  - Deploy with 'vercel' command"
echo "  - Requires: npm install -g vercel"
echo ""
echo "Option 3: Local Preview (Instant)"
echo "  - Python: python3 -m http.server 8000"
echo "  - Visit: http://localhost:8000"
echo ""

read -p "Choose option (1/2/3) or press Ctrl+C to exit: " choice

case $choice in
    1)
        echo ""
        echo "📡 Deploying to GitHub Pages..."
        echo ""
        echo "Step 1: Commit changes"
        git add -A
        git commit -m "Deploy CravingsAPI website to GitHub Pages" 2>/dev/null || echo "✅ Already committed"
        echo ""
        echo "Step 2: Push to origin/main"
        git push origin main
        echo ""
        echo "✅ Pushed! Now configure GitHub Pages:"
        echo "   1. Go to: https://github.com/yourusername/swiggy-builders-scrape"
        echo "   2. Settings → Pages"
        echo "   3. Source: main branch, / (root)"
        echo "   4. Wait 1-2 minutes for build"
        echo ""
        echo "🌐 Website will be live at:"
        echo "   https://yourusername.github.io/swiggy-builders-scrape/cravingsapi/"
        ;;
    2)
        echo ""
        echo "📡 Deploying to Vercel..."
        echo ""
        which vercel > /dev/null 2>&1 || {
            echo "❌ Vercel CLI not found. Install with:"
            echo "   npm install -g vercel"
            exit 1
        }
        echo ""
        vercel --name cravingsapi --confirm
        ;;
    3)
        echo ""
        echo "🖥️  Starting local preview server..."
        echo ""
        echo "🌐 Visit: http://localhost:8000"
        echo "   (Press Ctrl+C to stop)"
        echo ""
        python3 -m http.server 8000
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac
