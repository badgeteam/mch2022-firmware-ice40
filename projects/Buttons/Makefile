
all :
	mkdir -p build-tmp
	rm -f build-tmp/*

	echo "Synthesize design..."
	yosys  -q -p "synth_ice40 -top top -json build-tmp/buttons.json -blif build-tmp/buttons.blif -dsp -relut -abc2" rtl/buttons.v rtl/spi_dev_core.v

	echo "Place and Route..."
	nextpnr-ice40 --freq 12 --up5k --package sg48 --asc build-tmp/buttons.txt --pcf rtl/mch2022-proto4.pcf --json build-tmp/buttons.json --ignore-loops --pcf-allow-unconstrained

	echo "Create Bitstream..."
	icepack build-tmp/buttons.txt buttons.bin

	echo "Finished."

clean :
	rm -rf build-tmp
