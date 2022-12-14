
	.module devsdspi_sec

	; exported symbols
	.globl _sd_spi_receive_sector_int
	.globl _sd_spi_transmit_sector_int
	.globl _xmit_recv

        include "kernel.def"
        include "../kernel09.def"
	include "platform.def"


; =============================================================================
; defines for offsets into kernel structures - great care must be taken to keep
; this in sync with the kernel! (see dev/blkdev.h)


BLKPARAM_ADDR_OFFSET	equ 0
BLKPARAM_IS_USER_OFFSET equ 2


; -----------------------------------------------------------------------------
; COMMON MEMORY BANK
; -----------------------------------------------------------------------------
	.area .common


; static uint8_t xmit_recv(uint8_t b)
_xmit_recv
	pshs 	A,Y

	ldy 	#8
@lpa    clra
	rolb	
	rola
	sta 	sheila_USRVIA_orb
	ora 	#2
	sta 	sheila_USRVIA_orb
	leay 	-1,Y
	bne 	@lpa

	ldb 	sheila_USRVIA_sr

	clr 	sheila_USRVIA_orb

	puls 	A,Y,PC



_sd_spi_receive_sector_int
	pshs 	A,U,Y
	ldu 	_blk_op+BLKPARAM_ADDR_OFFSET
	tst 	_blk_op+BLKPARAM_IS_USER_OFFSET
	;TODO - check for SWAP?
	beq 	rd_kernel
	jsr 	map_process_always
rd_kernel	
	ldy 	#512
srlp	ldb 	#0xFF
	jsr 	_xmit_recv
	stb 	,U+
	leay 	-1,Y	
	bne 	srlp
	jsr 	map_kernel
	clrb 
	puls 	A,U,Y,PC


_sd_spi_transmit_sector_int
	pshs 	A,U,Y
	ldu 	_blk_op+BLKPARAM_ADDR_OFFSET
	tst 	_blk_op+BLKPARAM_IS_USER_OFFSET
	;TODO - check for SWAP?
	beq 	wr_kernel
	jsr 	map_process_always
wr_kernel	
	ldy 	#512
swlp	ldb 	,U+
	jsr 	_xmit_recv
	leay 	-1,Y	
	bne 	swlp
	jsr 	map_kernel
	clrb 
	puls 	A,U,Y,PC

