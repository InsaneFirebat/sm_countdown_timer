#!/bin/bash

cd tools
echo "Building SM 30m Timer hack"
cp ..\build\sm_orig.sfc SM_30m_Timer.sfc

asar --no-title-check ..\src\main.asm ..\build\SM_30m_Timer.sfc
cd ..
