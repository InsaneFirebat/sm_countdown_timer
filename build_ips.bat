@echo off

cd tools
python create_dummies.py 00.sfc ff.sfc

echo Building SM Countdown Timer Hack
copy *.sfc ..\build
asar --no-title-check ..\src\main.asm ..\build\00.sfc
echo Building again
asar --no-title-check ..\src\main.asm ..\build\ff.sfc
python create_ips.py ..\build\00.sfc ..\build\ff.sfc ..\build\SM_Countdown_Timer.ips

del 00.sfc ff.sfc ..\build\00.sfc ..\build\ff.sfc
cd ..
PAUSE