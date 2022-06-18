
all :
	cd fw && make clean all
	cp fw/bootloader.hex rtl
	# cp fw/bootloader.hex sim
	cd rtl && ./compile
	mv rtl/*.bin ./
clean :
	cd fw && make clean
	rm -f rtl/build/*
	rm -f sim/obj_dir/* sim/Vriscv_playground
