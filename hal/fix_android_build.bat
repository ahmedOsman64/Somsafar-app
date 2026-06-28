@echo off
echo Cleaning Flutter project...
flutter clean

echo Getting Flutter dependencies...
flutter pub get

echo Cleaning Android build...
cd android
gradlew clean

echo Building Android project...
gradlew build

echo Done!
pause
