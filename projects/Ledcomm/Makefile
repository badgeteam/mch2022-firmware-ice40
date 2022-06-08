
all :
	mkdir -p build-tmp
	rm -f build-tmp/*

	echo "Synthesize design..."
	yosys  -q -p "synth_ice40 -top top -json build-tmp/ledcomm.json -blif build-tmp/ledcomm.blif -dsp -relut -abc2" rtl/ledcomm.v

	echo "Place and Route..."
	nextpnr-ice40 --freq 12 --up5k --package sg48 --asc build-tmp/ledcomm.txt --pcf rtl/mch2022-proto4.pcf --json build-tmp/ledcomm.json --ignore-loops --pcf-allow-unconstrained

	echo "Create Bitstream..."
	icepack build-tmp/ledcomm.txt ledcomm.bin

	echo "Finished."

clean :
	rm -rf build-tmp
