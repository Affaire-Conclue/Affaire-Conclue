@echo off
echo ===============================================
echo  Switching to 'prod' branch and merging 'main'
echo ===============================================
git checkout prod
git merge main

echo.
echo ===============================================
echo  Pushing 'prod' to origin
echo ===============================================
git push origin prod

echo.
echo ===============================================
echo  Switching back to 'main' branch
echo ===============================================
git checkout main

echo.
echo  Process complete!
pause