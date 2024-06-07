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

iverilog -Winfloop -pfileline=1 -o iverilog.vvp TestBench.v \
    $SRCPTH/BESDPB.v \
    $SRCPTH/Cache.v \
    $SRCPTH/BurstRAM.v

vvp iverilog.vvp
rm iverilog.vvp
