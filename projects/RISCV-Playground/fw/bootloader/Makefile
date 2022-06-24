
RISCVGNU?=riscv64-linux-gnu

AOPS = --warn --fatal-warnings

all : bootloader.bin

bootloader.o : bootloader.s
	$(RISCVGNU)-as bootloader.s -o bootloader.o -march=rv32im

bootloader.bin : memmap bootloader.o
	$(RISCVGNU)-ld -o bootloader.elf -T memmap bootloader.o -m elf32lriscv
	$(RISCVGNU)-objdump -Mnumeric -D bootloader.elf > bootloader.list
	$(RISCVGNU)-objcopy bootloader.elf bootloader.bin -O binary
	hexdump -ve '1/4 "%08X\n"' bootloader.bin > bootloader.hex
	cp bootloader.hex ../../rtl

clean:
	rm -f *.bin
	rm -f *.o
	rm -f *.elf
	rm -f *.list


