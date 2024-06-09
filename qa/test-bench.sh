#!/bin/sh
# tools:
#   iverilog: Icarus Verilog version 12.0 (stable)
#        vvp: Icarus Verilog runtime version 12.0 (stable)
set -e
cd $(dirname "$0")

IDEPTH=~/.wine/drive_c/Gowin/Gowin_V1.9.9.03_x64/IDE/
SRCPTH=../../src

cd $1
pwd

# switch for system verilog
# -g2012 

iverilog -g2005-sv -Winfloop -pfileline=1 -o iverilog.vvp -s TestBench TestBench.sv \
    $IDEPTH/simlib/gw1n/prim_tsim.v \
    $SRCPTH/psram_memory_interface_hs_v2/psram_memory_interface_hs_v2.vo \
    $SRCPTH/gowin_rpll/gowin_rpll.v \
    $SRCPTH/BESDPB.sv \
    $SRCPTH/Cache.sv \
    $SRCPTH/BurstRAM.sv \
    $SRCPTH/Flash.sv \
    $SRCPTH/Top.sv

vvp iverilog.vvp
rm iverilog.vvp
