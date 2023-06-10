#!/bin/bash

cd tools
python3 create_dummies.py 00.sfc ff.sfc

echo "Patching SM Countdown Timer Hack"
cp *.sfc ../build
asar --no-title-check ../src/main.asm ../build/00.sfc
echo "Patching again"
asar --no-title-check ../src/main.asm ../build/ff.sfc
python3 create_ips.py ../build/00.sfc ../build/ff.sfc ../build/SM_Countdown_Timer.ips

rm 00.sfc ff.sfc ../build/00.sfc ../build/ff.sfc
cd ..
