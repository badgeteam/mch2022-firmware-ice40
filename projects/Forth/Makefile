
all :
	cd fw/mch2022 && ./compilenucleus
	mv fw/mch2022/build/iceimage.hex rtl
	cd rtl && ./compile
	mv rtl/mch2022.bin ./
clean :
	rm -f fw/mch2022/build/*
	rm -f fw/common-crosscompiler/icecreammachine-16kb.o fw/common-crosscompiler/icecreammachine-16kb
	rm -f rtl/build/*

