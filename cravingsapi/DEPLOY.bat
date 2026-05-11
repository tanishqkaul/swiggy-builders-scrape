@echo off
REM CravingsAPI — Quick Deployment Script (Windows)
REM Usage: DEPLOY.bat

echo.
echo 🚀 CravingsAPI Deployment Helper
echo ==================================
echo.

REM Check git
git status >nul 2>&1
if errorlevel 1 (
    echo ❌ Not in a git repository. Run from cravingsapi\ root.
    exit /b 1
)

REM List files
echo 📦 Files to deploy:
dir /B index.html README.md SUBMISSION.md STATUS.md
echo.

echo 🌐 Deployment Options:
echo.
echo Option 1: GitHub Pages (Recommended)
echo   - Pushes to origin/main and uses GitHub Pages
echo   - Live at: https://yourusername.github.io/swiggy-builders-scrape/cravingsapi/
echo.
echo Option 2: Local Preview (Instant)
echo   - Python: python -m http.server 8000
echo   - Visit: http://localhost:8000
echo.
echo Option 3: Vercel
echo   - Deploy with 'vercel' command
echo   - Requires: npm install -g vercel
echo.

set /p choice="Choose option (1/2/3): "

if "%choice%"=="1" (
    echo.
    echo 📡 Deploying to GitHub Pages...
    echo.
    echo Step 1: Commit changes
    git add -A
    git commit -m "Deploy CravingsAPI website to GitHub Pages" 2>nul
    echo.
    echo Step 2: Push to origin/main
    git push origin main
    echo.
    echo ✅ Pushed! Now configure GitHub Pages:
    echo    1. Go to: https://github.com/yourusername/swiggy-builders-scrape
    echo    2. Settings ^> Pages
    echo    3. Source: main branch, / (root)
    echo    4. Wait 1-2 minutes for build
    echo.
    echo 🌐 Website will be live at:
    echo    https://yourusername.github.io/swiggy-builders-scrape/cravingsapi/
    echo.
) else if "%choice%"=="2" (
    echo.
    echo 🖥️  Starting local preview server...
    echo.
    echo 🌐 Visit: http://localhost:8000
    echo    (Press Ctrl+C to stop)
    echo.
    python -m http.server 8000
) else if "%choice%"=="3" (
    echo.
    echo 📡 Deploying to Vercel...
    echo.
    where vercel >nul 2>&1
    if errorlevel 1 (
        echo ❌ Vercel CLI not found. Install with:
        echo    npm install -g vercel
        exit /b 1
    )
    echo.
    vercel --name cravingsapi --confirm
) else (
    echo ❌ Invalid option
    exit /b 1
)
