@echo off
REM Analyze + test RakshaPay. Absolute paths: cannot be run from the wrong
REM directory, which is what produced the phantom "66 issues found".
cd /d D:\RakshaPay\app
echo Running from: %CD%
echo.
echo === flutter analyze ===
"C:\src\flutter\bin\flutter.bat" analyze --no-pub
echo.
echo === flutter test ===
"C:\src\flutter\bin\flutter.bat" test --no-pub
echo.
pause
