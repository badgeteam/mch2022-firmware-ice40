
RISCVGNU?=riscv64-linux-gnu

all :
	$(RISCVGNU)-as bootloader.s -o bootloader.o -march=rv32im
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


