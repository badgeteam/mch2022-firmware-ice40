
RISCVGNU?=riscv64-unknown-elf

CFLAGS?=-Os -fno-strict-aliasing -ffreestanding -fno-pic -fomit-frame-pointer -march=rv32imc -mabi=ilp32 -fno-stack-protector -mno-relax -fdata-sections -ffunction-sections -nostartfiles -nostdlib

all :
	rm -f *.o
	$(RISCVGNU)-gcc $(CFLAGS) -c start.S  -o start.o
	$(RISCVGNU)-gcc $(CFLAGS) -c hello_gcc.c -o hello_gcc.o
	$(RISCVGNU)-gcc $(CFLAGS) -Wl,-T,memmap,--gc-sections *.o -o hello_gcc.elf -lgcc
	$(RISCVGNU)-objdump -Mnumeric -D hello_gcc.elf > hello_gcc.list
	$(RISCVGNU)-objcopy hello_gcc.elf hello_gcc.bin -O binary
	$(RISCVGNU)-objdump -Mnumeric -D -mriscv:rv32 --target binary hello_gcc.bin --adjust-vma=0x00000000 > hello_gcc.dis

clean:
	rm -f *.o
	rm -f *.elf
	rm -f *.list
	rm -f *.dis

