
all :
	cd fw/bootloader && make clean all
	cp fw/bootloader/bootloader.hex rtl
	cd rtl && ./compile
	mv rtl/*.bin ./
clean :
	cd fw/bootloader && make clean
	rm -f rtl/build/*

