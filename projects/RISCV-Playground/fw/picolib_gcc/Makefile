
RISCVGNU?=riscv64-unknown-elf

CFLAGS?=--specs=/usr/lib/picolibc/riscv64-unknown-elf/picolibc.specs -T picolibc.ld -Os -fno-strict-aliasing -fno-pic -fomit-frame-pointer -march=rv32imc -mabi=ilp32 -fno-stack-protector -mno-relax -fdata-sections -ffunction-sections -fno-math-errno

all :
	rm -f *.o
	$(RISCVGNU)-gcc $(CFLAGS) -c picolib_gcc.c -o picolib_gcc.o
	$(RISCVGNU)-gcc $(CFLAGS) -Wl,--gc-sections -o picolib_gcc.elf picolib_gcc.o -lm -lgcc
	$(RISCVGNU)-objdump -Mnumeric -D picolib_gcc.elf > picolib_gcc.list
	$(RISCVGNU)-objcopy picolib_gcc.elf picolib_gcc.bin -O binary
	$(RISCVGNU)-objdump -Mnumeric -D -mriscv:rv32 --target binary picolib_gcc.bin --adjust-vma=0x00000000 > picolib_gcc.dis
	ls -l picolib_gcc.bin && md5sum picolib_gcc.bin

clean:
	rm -f *.o
	rm -f *.elf
	rm -f *.list
	rm -f *.dis
