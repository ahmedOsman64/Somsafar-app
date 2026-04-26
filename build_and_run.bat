@echo off
echo Building and installing Somsafar App...
echo.

echo Cleaning previous build...
call flutter clean

echo Getting dependencies...
call flutter pub get

echo Building APK...
cd android
call gradlew.bat assembleDebug
cd ..

echo Installing APK...
"C:\Users\ahmed\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s R8YTC047CAH install "android\app\build\outputs\apk\debug\app-debug.apk"

echo Launching app...
"C:\Users\ahmed\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s R8YTC047CAH shell am start -n com.somsafar.app/.MainActivity

echo.
echo App successfully built and launched!
pause
