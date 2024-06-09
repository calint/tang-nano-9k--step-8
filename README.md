# Tang Nano 9K

step-wise development towards a RISC-V rv32i implementation supporting cache of PSRAM

## todo
```
[ ] test: cache read and write in 1 cycle; led if ok else hang
[ ] test: cache: write, write with evict, read with evict, read with evict the byte written
[ ] cache: read and 'data_out_ready' can be done while command interval delay active
[ ] cache: wait_before_read, wait_after_read, wait_before_write, wait_after_write signals
    instead of generic 'busy' and optimizing access to cached data when writing
[ ] step 9: read from flash and assert with led
[ ] step 10: read from flash, write to cache
[ ] step 11: implement ram interface
[ ] step 12: adapt riscv core
```