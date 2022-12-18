
        .module devsdspi

        ; exported symbols
        .globl _sd_spi_rawinit
        .globl _sd_spi_clock
        .globl _sd_spi_raise_cs
        .globl _sd_spi_lower_cs
        .globl _sd_spi_transmit_byte
        .globl _sd_spi_receive_byte
        .globl _sd_spi_transmit_sector
        .globl _sd_spi_receive_sector

        include "kernel.def"
        include "../kernel09.def"
        include "platform.def"


; =============================================================================
; defines for offsets into kernel structures - great care must be taken to keep
; this in sync with the kernel! (see dev/blkdev.h)


BLKPARAM_ADDR_OFFSET    equ 0
BLKPARAM_IS_USER_OFFSET equ 2


; -----------------------------------------------------------------------------
; COMMON MEMORY BANK
; -----------------------------------------------------------------------------
        .area .common

; SD Card use SPI Mode 0, see https://elm-chan.org/docs/spi_e.html
; receive
;   latch MISO value
;   take CLK high
;   take CLK low (slave shifts on this edge)
; xmit:
;   set MOSI value
;   take CLK high (slave latches on this edge)
;   take CLK low

READ_BIT macro
        aslb                    ; shift B ready for next bit
        bita  UART_IPR          ; test the MISO bit in IFR which is the same as the CLK bit in the OPR
        beq   *+3               ; skip the next instruction
        incb                    ;
        sta   UART_OPRCLR       ; take CLK high
        sta   UART_OPRSET       ; take CLK low (slave shifts on this edge)
        endm

WRITE_BIT macro
        lda   #SDMOSI_MASK      ; set MOSI value
        rolb
        bcs   *+7               ; to (X)
        sta   UART_OPRSET
        bcc   *+5               ; to (Y)
        sta   UART_OPRCLR       ; (X)
        lda   #SDCLK_MASK       ; (Y)
        sta   UART_OPRCLR       ; take CLK high
        sta   UART_OPRSET       ; take CLK low (slave shifts on this edge)
        endm

_sd_spi_rawinit
        rts

;;; Ignore the speed parameter (in b) as we are going pretty slowly!
_sd_spi_clock
        pshs  A
        lda   #SDCLK_MASK
        sta   UART_OPRCLR  ; take CLK high
        sta   UART_OPRSET  ; take CLK low (slave shifts on this edge)
        puls  A, PC
        rts

_sd_spi_raise_cs
        pshs  A
        lda   #SDCS_MASK
        sta   UART_OPRCLR
        puls  A, PC

_sd_spi_lower_cs
        pshs  A
        lda   #SDCS_MASK
        sta   UART_OPRSET
        puls  A, PC

_sd_spi_receive_byte
        pshs    A
        lda   #SDCLK_MASK
        READ_BIT
        READ_BIT
        READ_BIT
        READ_BIT
        READ_BIT
        READ_BIT
        READ_BIT
        READ_BIT
        puls    A,PC


_sd_spi_transmit_byte
        pshs    A
        WRITE_BIT
        WRITE_BIT
        WRITE_BIT
        WRITE_BIT
        WRITE_BIT
        WRITE_BIT
        WRITE_BIT
        WRITE_BIT
        puls    A,PC


_sd_spi_receive_sector
        pshs    A,U,Y
        ldu     _blk_op+BLKPARAM_ADDR_OFFSET
        tst     _blk_op+BLKPARAM_IS_USER_OFFSET
        ;TODO - check for SWAP?
        beq     rd_kernel
        jsr     map_process_always
rd_kernel
        ldy     #512                    ; note the last bit is special!
srlp
        jsr     _sd_spi_receive_byte
        stb     ,U+
        leay    -1,Y
        bne     srlp

        jsr     map_kernel
        clrb
        puls    A,U,Y,PC


_sd_spi_transmit_sector
        pshs    A,U,Y
        ldu     _blk_op+BLKPARAM_ADDR_OFFSET
        tst     _blk_op+BLKPARAM_IS_USER_OFFSET
        ;TODO - check for SWAP?
        beq     wr_kernel
        jsr     map_process_always
wr_kernel
        ldy     #512
swlp    ldb     ,U+
        jsr     _sd_spi_transmit_byte
        leay    -1,Y
        bne     swlp
        jsr     map_kernel
        clrb
        puls    A,U,Y,PC
