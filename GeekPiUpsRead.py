#!/usr/bin/env python3

import sys
import smbus2

DEVICE_BUS = 1
DEVICE_ADDR = 0x17

register = int(sys.argv[1])

with smbus2.SMBus(DEVICE_BUS) as bus:
    value = bus.read_byte_data(DEVICE_ADDR, register)

print("register %d=%d" % (register, value))
