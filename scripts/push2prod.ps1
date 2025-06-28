# push2prod.ps1
Write-Host "===============================================" -ForegroundColor Green
Write-Host " STEP 1: Switching to 'prod' branch" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

git checkout prod
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to switch to 'prod' branch. Halting script." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " STEP 2: Merging 'main' into 'prod'" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

git merge main
if ($LASTEXITCODE -ne 0) {
    Write-Host "******************************************************" -ForegroundColor Yellow
    Write-Host "* WARNING: Merge failed! This is likely due to a     *" -ForegroundColor Yellow
    Write-Host "* merge conflict. Please resolve the conflicts in    *" -ForegroundColor Yellow
    Write-Host "* your code editor, then commit the changes manually.*" -ForegroundColor Yellow
    Write-Host "* The script cannot continue.                        *" -ForegroundColor Yellow
    Write-Host "******************************************************" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " STEP 3: Pushing 'prod' to origin" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

git push origin prod
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to push to 'origin/prod'. Halting script." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " STEP 4: Switching back to 'main' branch" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

git checkout main
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to switch back to 'main' branch." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " Script finished successfully!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Read-Host "Press Enter to continue..."