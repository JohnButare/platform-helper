#!/usr/bin/env python3

import sys
import smbus2

DEVICE_BUS = 1
DEVICE_ADDR = 0x17

register = int(sys.argv[1])
value = int(sys.argv[2])

with smbus2.SMBus(DEVICE_BUS) as bus:
    bus.write_byte_data(DEVICE_ADDR, register, value)

print("register %d set to %d" % (register, value))
