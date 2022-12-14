
	.module devsdspi_sec

	; exported symbols
	.globl _sd_spi_receive_sector_int
	.globl _sd_spi_transmit_sector_int
	.globl _xmit_recv
	.globl _sd_spi_recv_byte

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


_sd_spi_recv_byte
	pshs 	A

	; note: I tried being clever here and making the I/O accesses use DP references i.e. <sheila_USRVIA_orb
	; but that failed - not sure if that is a 6522 thing or too fast for my SD CARD?

	lda 	#1
	ldb     #3

	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb

	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb

	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb
	
	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb

	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb

	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb

	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb

	sta 	sheila_USRVIA_orb
	stb 	sheila_USRVIA_orb

	ldb 	sheila_USRVIA_sr

	puls 	A,PC


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

	puls 	A,Y,PC



_sd_spi_receive_sector_int
	pshs 	A,U,Y
	ldu 	_blk_op+BLKPARAM_ADDR_OFFSET
	tst 	_blk_op+BLKPARAM_IS_USER_OFFSET
	;TODO - check for SWAP?
	beq 	rd_kernel
	jsr 	map_process_always
rd_kernel	

	; enter shift reg mode 2

	lda 	#%000000001		; make clock pin an input
	sta 	sheila_USRVIA_ddrb

	lda 	sheila_USRVIA_acr
	anda 	#0xE3
	ora 	#0x08
	sta 	sheila_USRVIA_acr
	lda 	sheila_USRVIA_sr	; initiate first read


	ldy 	#511			; note the last bit is special!
	lda 	#4			; bit in IER for SR full
srlp	

srwt	bita 	sheila_USRVIA_ifr
	beq 	srwt
	ldb 	sheila_USRVIA_sr
	stb 	,U+
	leay 	-1,Y	
	bne 	srlp


srwt2	bita 	sheila_USRVIA_ifr	; wait for final bit
	beq 	srwt2

	; back to mode 0

	lda 	#%000000011		; make clock pin an output again
	sta 	sheila_USRVIA_ddrb
	clr 	sheila_USRVIA_orb

	lda 	sheila_USRVIA_acr
	anda 	#0xE3
	sta 	sheila_USRVIA_acr

	ldb 	sheila_USRVIA_sr
	stb	,U+


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

