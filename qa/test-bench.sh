#!/bin/sh
# tools:
#   iverilog: Icarus Verilog version 12.0 (stable)
#        vvp: Icarus Verilog runtime version 12.0 (stable)
set -e
cd $(dirname "$0")

SRCPTH=../../src

cd $1
pwd

# switch for system verilog
# -g2005-sv

iverilog -g2012 -s TestBench -Winfloop -pfileline=1 -o iverilog.vvp TestBench.v \
    ~/.wine/drive_c/Gowin/Gowin_V1.9.9.03_x64/IDE/simlib/gw1n/prim_sim.v \
    $SRCPTH/psram_memory_interface_hs_v2/psram_memory_interface_hs_v2.vo \
    $SRCPTH/gowin_rpll/gowin_rpll.v \
    $SRCPTH/BESDPB.v \
    $SRCPTH/Cache.v \
    $SRCPTH/BurstRAM.v

vvp iverilog.vvp
rm iverilog.vvp
