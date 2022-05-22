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

The cores in this repository are licensed under the
"CERN Open Hardware Licence Version 2 - Permissive" license.

See LICENSE file for full text.
