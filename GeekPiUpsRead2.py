#!/usr/bin/env python3

import sys
import smbus2

DEVICE_BUS = 1
DEVICE_ADDR = 0x17

register1 = int(sys.argv[1])
register2 = int(sys.argv[2])

with smbus2.SMBus(DEVICE_BUS) as bus:
    value = bus.read_byte_data(DEVICE_ADDR, register2) << 8
    value = bus.read_byte_data(DEVICE_ADDR, register1) | value

print("register %d %d=%d" % (register1, register2, value))
