#!/usr/bin/env python3

import sys
from ina219 import INA219,DeviceRangeError

DEVICE_BUS = 1

ina_batt = INA219(0.005, busnum=DEVICE_BUS, address=0x45)
ina_batt.configure()
print("%.0f" % (ina_batt.voltage() * 1000))
