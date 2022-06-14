/*
 * boot.S
 *
 * Boot code
 *
 * Copyright (C) 2020-2022 Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: MIT
 */

#define BOOT_DEBUG

#ifndef APP_ADDR
#define APP_ADDR 0x40000000
#endif

	.equ    UART_BASE, 0x82000000

	.section .text.start
	.global _start
_start:

#ifdef BOOT_DEBUG
	// Set UART divisor
	li	a0, UART_BASE
	li	a1, 23
	sw	a1, 4(a0)
#endif

	// Delay boot
	li	t0, 0x00100000
1:
	addi	t0, t0, -1
	bne	t0, zero, 1b

	// SPI init
	jal	qpi_init

	// Load app from ESP32
	li	a0, APP_ADDR
	li	a1, 0x00080000
	li	a2, 0x355beaa3
	li	a3, 0x00000000
	jal	lnk_read

	// Jump to main code in RAM
	li	ra, APP_ADDR
	ret


// ---------------------------------------------------------------------------
// ESP Link code
// ---------------------------------------------------------------------------

	.equ	LNK_BASE, 0x84000000

	.equ    LNK_CSR,  0
	.equ	LNK_FID,  4
	.equ	LNK_OFS,  8
	.equ	LNK_LEN, 12

// Reads a block of memory from a file on ESP32
//
// Params:
//  a0 - destination pointer
//  a1 - length (bytes)
//  a2 - file ID
//  a3 - file offset
// Clobbers t0-6, a0, a1

lnk_read:
	// Constants
	li	t6, LNK_BASE		// Base CSR

	li	t4, 0xc0000000		// Done mask
	li	t5, 0x80000000		// Done value

	// Load File ID
	sw	a2, LNK_FID(t6)

	// Offset
	sw	a3, LNK_OFS(t6)

2:
	// Length (and req start)
		// block_len = min(0x200, len) 
	li	t3, 0x200
//	bge	a1, t3, 1f
//	mv	t3, a1
//1:
		// len -= block_len
	sub	a1, a1, t3

		// Send length
	addi	t0, t3, -1
	sw	t0, LNK_LEN(t6)

	// Wait for request done
1:
	lw	t0, LNK_CSR(t6)
	and	t0, t0, t4
	bne	t0, t5, 1b

	// Copy data
	li	t1, 0x800
	add	t1, t1, t6	// t1 = src

1:
	lw	t0, 0(t1)
	sb	t0, 0(a0)
	addi	t1, t1, 4
	addi	a0, a0, 1
	addi	t3, t3, -1
	bne	t3, zero, 1b

	// Next block (if any)
	bne	a1, zero, 2b

	ret


// ---------------------------------------------------------------------------
// QPI code
// ---------------------------------------------------------------------------

	.equ    QPI_BASE, 0x80000000
	.equ    QPI_CSR,  4 * 0x00
	.equ	QPI_RF,   4 * 0x03

qpi_init:

	// Constants
	li	t6, QPI_BASE

	// Request external control
	li	t0, 0x00000004
	sw	t0, QPI_CSR(t6)

	li	t0, 0x00000002
	sw	t0, QPI_CSR(t6)

	// Enable QSPI (0x35)
	li	t0, 0x35000000
	sw	t0, 0x40(t6)

	// Read and discard response
	lw	t0, QPI_RF(t6)

	// Release external control
	li	t0, 0x00000004
	sw	t0, QPI_CSR(t6)

	// Return
	ret


// ---------------------------------------------------------------------------
// Debug helpers
// ---------------------------------------------------------------------------

#ifdef BOOT_DEBUG
// Agument in a0
// Clobbers a0, t0-t3
print_hex:
	li	t0, UART_BASE
	li	t1, 8
	la	t2, hexchar

1:
	srli	t3, a0, 28
	add	t3, t3, t2
	lb	t3, 0(t3)
	sw	t3, 0(t0)

	slli	a0, a0, 4

	addi	t1, t1, -1
	bne	zero, t1, 1b

print_nl:
	li	t0, UART_BASE
	li	a0, '\r'
	sw	a0, 0(t0)
	li	a0, '\n'
	sw	a0, 0(t0)

	ret

hexchar:
	.ascii	"0123456789abcdef"
#endif
