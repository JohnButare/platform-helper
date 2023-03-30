#!/usr/bin/env python3

import sys
import smbus2

DEVICE_BUS = 1
DEVICE_ADDR = 0x17

register1 = int(sys.argv[1])
register2 = int(sys.argv[2])
value = int(sys.argv[3])

with smbus2.SMBus(DEVICE_BUS) as bus:
    bus.write_byte_data(DEVICE_ADDR, register1, value & 0xFF)
    bus.write_byte_data(DEVICE_ADDR, register2, (value >> 8) & 0xFF)


print("register %d and %d set to %d" % (register1, register2, value))
