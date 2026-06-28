@echo off
echo Starting build fix...
if not exist .pub_cache mkdir .pub_cache
set PUB_CACHE=%CD%\.pub_cache
echo PUB_CACHE set to %PUB_CACHE%
echo Running flutter pub get...
call flutter pub get
echo Running flutter build apk...
call flutter build apk --debug
echo Done.
