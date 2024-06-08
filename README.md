# Tang Nano 9K

step-wise development towards a RISC-V rv32i implementation supporting cache of PSRAM

## todo
```
[ ] cache: read and 'data_out_ready' can be done while command interval delay active
[ ] cache: wait_before_read, wait_after_read, wait_before_write, wait_after_write signals 
    instead of generic 'busy' and optimizing access to cached data when writing
```