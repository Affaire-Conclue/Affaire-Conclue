# This script updates all Hugo theme submodules, commits the changes, and pushes to the remote repository.

# Use Write-Host to show progress
Write-Host "Step 1: Updating theme submodules..." -ForegroundColor Green
git submodule update --remote --merge

# Check if the last command was successful before continuing
if (-not $?) {
    Write-Host "Error updating submodules. Aborting script." -ForegroundColor Red
    exit 1 # Exit the script with an error code
}

Write-Host "Step 2: Staging and committing changes..." -ForegroundColor Green
git add .

# You can change the commit message here if you like
git commit -m "chore: Update Hugo themes"

if (-not $?) {
    Write-Host "Nothing to commit or commit failed. Aborting script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Step 3: Pushing changes to remote..." -ForegroundColor Green
git push

Write-Host "✅ All tasks completed successfully." -ForegroundColor Green