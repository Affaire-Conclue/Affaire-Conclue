@echo off
ECHO ===============================================
ECHO  STEP 1: Switching to 'prod' branch
ECHO ===============================================
git checkout prod
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: Failed to switch to 'prod' branch. Halting script.
    goto:eof
)

ECHO.
ECHO ===============================================
ECHO  STEP 2: Merging 'main' into 'prod'
ECHO ===============================================
git merge main
IF %ERRORLEVEL% NEQ 0 (
    ECHO ******************************************************
    ECHO * WARNING: Merge failed! This is likely due to a     *
    ECHO * merge conflict. Please resolve the conflicts in    *
    ECHO * your code editor, then commit the changes manually.*
    ECHO * The script cannot continue.                        *
    ECHO ******************************************************
    goto:eof
)

ECHO.
ECHO ===============================================
ECHO  STEP 3: Pushing 'prod' to origin
ECHO ===============================================
git push origin prod
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: Failed to push to 'origin/prod'. Halting script.
    goto:eof
)


ECHO.
ECHO ===============================================
ECHO  STEP 4: Switching back to 'main' branch
ECHO ===============================================
git checkout main
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: Failed to switch back to 'main' branch.
    goto:eof
)

ECHO.
ECHO ===============================================
ECHO  Script finished successfully!
ECHO ===============================================

:eof
pause