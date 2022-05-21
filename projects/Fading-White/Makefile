
all :
	mkdir -p build-tmp
	rm -f build-tmp/*

	echo "Synthesize design..."
	yosys  -q -p "synth_ice40 -top top -json build-tmp/fading_white.json -blif build-tmp/fading_white.blif -dsp -relut -abc2" rtl/fading_white.v

	echo "Place and Route..."
	nextpnr-ice40 --freq 12 --up5k --package sg48 --asc build-tmp/fading_white.txt --pcf rtl/mch2022-proto4.pcf --json build-tmp/fading_white.json --ignore-loops --pcf-allow-unconstrained

	echo "Create Bitstream..."
	icepack build-tmp/fading_white.txt fading_white.bin

	echo "Finished."

clean :
	rm -rf build-tmp
