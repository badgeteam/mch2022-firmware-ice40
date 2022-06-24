MCH2022 badge iCE40 gateware
============================

Collection of ip cores / demos for the [MCH2022 badge](https://github.com/badgeteam/mch2022-badge-hardware)


Note about submodules
---------------------

Make sure to clone this repository with all its submodules by using
the `--recursive` option when cloning or running `git submodule init` and
`git submodule update` after checkout.

Also make sure to update submodules when pulling from upstream.

Welcome
---------------------

The MCH2022 badge also is a FPGA dev board.

Try loading your first bitstream!

Besides your badge and an USB cable to connect it to your computer on which it will appear as `ttyACM0` and `ttyACM1` get these two files:

[Bitstream loader tool](https://github.com/badgeteam/mch2022-firmware-esp32/blob/master/tools/uart_fpga.py)
and an bitstream for the FPGA, [hello_world.bin](https://github.com/badgeteam/mch2022-firmware-ice40/blob/master/projects/Hello-World/hello_world.bin).

On the badge, navigate to "Development tools" --> "FPGA download mode" and transmit the bitstream using your computer `uart_fpga.py /dev/ttyACM0 hello_world.bin`

But as this May Contain Hackers, we hope to introduce many into creating their own designs.

Toolchain "installation"
---------------------

Get the latest package for your computers architecture: [https://github.com/YosysHQ/oss-cad-suite-build/releases](https://github.com/YosysHQ/oss-cad-suite-build/releases)

Unpack the toolchain to a suitable place, and - assuming you use Linux - include the toolchain temporarily to your path with the command `source ~/path/to/oss-cad-suite/environment`. This allows to have multiple versions installed on your computer, but just go for the lastest. One note: Do not try to install packaged Yosys/NextPNR/Icestorm tools that might come with your distro -- the toolchain is advancing very, very quick, and if your distro packaged it three months ago, it is already heavily outdated. The ones in Debian Stable -- Ouch!

Clone this repo `git clone --recursive https://github.com/badgeteam/mch2022-firmware-ice40/`

Then try to hit `make` on the [Hello World](https://github.com/badgeteam/mch2022-firmware-ice40/blob/master/projects/Hello-World/) example.

If it succeeded, the freshly synthesised bitstream appears in build-tmp subdir. You can now upload it as described, then try to change the blink pattern a little.

Side note: All of this also works under MinGW, simply using 'mingw32-make', including the python upload script

FPGA-visible hardware on the badge
---------------------

The FPGA, a Lattice ice40 UP5K, receives its bitstream by the ESP32 on the badge and is equipped with

* a dedicated USB<->UART bridge channel
* an RGB LED
* a parallel mode interface to the LCD for fast graphics
* an external serial QSPI RAM chip
* a PMOD connector that carries 8 FPGA IO lines (or 4 differential pairs), VCC and GND.

Also, using the same wires that are necessary for booting the bitstream, the ESP32 notified the FPGA of the current state of the [buttons](https://github.com/badgeteam/mch2022-firmware-ice40/tree/master/projects/Buttons) and provides a mechanism to access data files.

If you want to think of the badge solely as FPGA dev board, you can ignore most of its other functionality, just keep in mind these handy hints:

- The two UART lines are routed to `/dev/ttyACM1`, your terminal program selects the baud rate.

- The FPGA should control the RGB LED using the SB_RGBA_DRV hard macro with constant current capabilities instead of a simple Verilog outputs, as that would overdrive at least the red LED.

- The FPGA shall wait for then `lcd_mode` pin that switches between SPI/parallel mode of the LCD to go high before starting to talk to the LCD, as it is driven by the ESP32.

- Check twice before connecting external voltages to the PMOD :-)

Look at the pin constraints file [mch2022-proto4.pcf](https://github.com/badgeteam/mch2022-firmware-ice40/blob/master/projects/_common/data/mch2022-proto4.pcf).

Guide for complete newbies to FPGAs
---------------------

Let's try for short:

For a bunch of TTL logic chip to do something useful, you need to wire them up - and the way you wire these determines the function of the completed circuit.

A "Field Programmambe Gate Array" contains a grid of "universal gates" calles lookup-tables with -in our case- 4 binary inputs and 1 output, and every of these is accompanied by 1 flipflop bit. Nothing special so far. The special sauce of an FPGA is their connection - that there is a dense mesh of wires in different lengths that crisscross the entire chip, with switchbox points that allow to choose how to connect the individual logic elements to the mesh of wires. By selecting which switchboxes to activate, one builds an actual digital circuit on the FPGA.

For your curiosity, here is a DIY FPGA: [http://blog.notdot.net/2012/10/Build-your-own-FPGA](http://blog.notdot.net/2012/10/Build-your-own-FPGA)

You should have an idea by now! You are going to build logic circuits. And you'll probably fall into a rabbit hole :-)

We would love to give you a complete intro, but for time-is-not-infinite reasons, recommend you intros from others instead.

For the ones that prefer reading and want to know everything to design their own RISC-V CPU at the end of the course:

[https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV](https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV)

For the ones that prefer videos and a calm pace, Shawn Hymel has done a series in 12 parts that really starts at the beginning and explains the scenery you encounter:

[https://github.com/ShawnHymel/introduction-to-fpga](https://github.com/ShawnHymel/introduction-to-fpga)
[https://www.digikey.de/en/maker/projects/introduction-to-fpga-part-1-what-is-an-fpga/3ee5f6c8fa594161a655a9f960060893](https://github.com/ShawnHymel/introduction-to-fpga)
