SPI Slave IP core
=================

Overview
--------

This contains a couple of core that help control logic on the FPGA
from a controller connected through SPI (for instance using the same
FTDI/other chip that's used for the configuration of the FPGA itself).

Communication is highly optimized for the host -> fpga direction and
the backchannel is limited.


License
-------

These cores are licensed under the BSD 3-clause licence (see LICENSE.bsd)
