@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
echo CHECKING_CL_PATH
where cl
echo CHECKING_INCLUDE_PATH
echo %INCLUDE%
