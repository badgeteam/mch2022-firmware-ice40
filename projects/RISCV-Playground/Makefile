
all :
	cd fw/mecrisp-quintus-source/mch2022-femtorv32 && make clean all
	cp fw/mecrisp-quintus-source/mch2022-femtorv32/mecrisp-quintus-mch2022.bin fw/decompressor
	cd fw/decompressor && ./compile
	cp fw/decompressor/*.hex rtl
	cd rtl && ./compile
	mv rtl/*.bin ./
clean :
	cd fw/mecrisp-quintus-source/mch2022-femtorv32 && make clean
	cd fw/decompressor && ./tidyup
	rm -f rtl/build/*
	rm -f sim/obj_dir/* sim/Vriscv_playground
