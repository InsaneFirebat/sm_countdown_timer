@echo off

echo Building SM 30m Timer hack

cd tools
echo Building and pre-patching 30m Timer version
cp ..\build\sm_orig.sfc ..\build\SM_30m_Timer.sfc && asar --no-title-check ..\src\main.asm ..\build\SM_30m_Timer.sfc && cd ..

PAUSE
