
all :
	mkdir -p build-tmp
	rm -f build-tmp/*

	echo "Synthesize design..."
	yosys  -q -p "synth_ice40 -top top -json build-tmp/hello_world.json -blif build-tmp/hello_world.blif -dsp -relut -abc2" rtl/hello_world.v

	echo "Place and Route..."
	nextpnr-ice40 --freq 12 --up5k --package sg48 --asc build-tmp/hello_world.txt --pcf rtl/mch2022-proto4.pcf --json build-tmp/hello_world.json --ignore-loops --pcf-allow-unconstrained

	echo "Create Bitstream..."
	icepack build-tmp/hello_world.txt hello_world.bin

	echo "Finished."

clean :
	rm -rf build-tmp
