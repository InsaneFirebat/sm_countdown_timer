#!/bin/bash

cd tools
echo "Building SM Countdown Timer hack"
cp ..\build\sm_orig.sfc SM_Countdown_Timer.sfc

asar --no-title-check ..\src\main.asm ..\build\SM_Countdown_Timer.sfc
cd ..
