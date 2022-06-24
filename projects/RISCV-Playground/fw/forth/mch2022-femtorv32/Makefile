
RISCVGNU?=riscv64-linux-gnu

AOPS = --warn --fatal-warnings

all : mecrisp-quintus-mch2022.bin

mecrisp-quintus-mch2022.o : mecrisp-quintus-mch2022.s
	$(RISCVGNU)-as mecrisp-quintus-mch2022.s -o mecrisp-quintus-mch2022.o -march=rv32im

mecrisp-quintus-mch2022.bin : memmap mecrisp-quintus-mch2022.o
	$(RISCVGNU)-ld -o mecrisp-quintus-mch2022.elf -T memmap mecrisp-quintus-mch2022.o -m elf32lriscv
	$(RISCVGNU)-objdump -Mnumeric -D mecrisp-quintus-mch2022.elf > mecrisp-quintus-mch2022.list
	$(RISCVGNU)-objcopy mecrisp-quintus-mch2022.elf mecrisp-quintus-mch2022.bin -O binary

clean:
	# rm -f *.bin
	rm -f *.o
	rm -f *.elf
	rm -f *.list
