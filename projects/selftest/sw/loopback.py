#!/usr/bin/env python3

import binascii
from pyftdi.spi import SpiController


def main():
	spi_addr = 'ftdi://ftdi:2232h/1'
	spi_frequency = 60e6
	spi_cs = 2

	spi = SpiController(cs_count=3)
	spi.configure(spi_addr)
	slave = spi.get_port(cs=spi_cs, freq=spi_frequency, mode=0)

	data0 = bytearray([0x01, 0x23, 0x45, 0x67, 0x01, 0x23, 0x45, 0x67])
	data1 = bytearray([0x89, 0xab, 0xcd, 0xef, 0x89, 0xab, 0xcd, 0xef])

	r0 = slave.exchange(data0, duplex=True)
	r1 = slave.exchange(data1, duplex=True)
	r2 = slave.exchange(bytearray(8), duplex=True)

	print(binascii.b2a_hex(r0))
	print(binascii.b2a_hex(r1))
	print(binascii.b2a_hex(r2))



if __name__ == '__main__':
	main()
