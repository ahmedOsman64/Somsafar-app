@echo off
echo Starting cleanup...
git rm -r --cached .
git add .
git commit -m "Fix: Add gitignore and remove dependency tracking"
echo Cleanup DONE
