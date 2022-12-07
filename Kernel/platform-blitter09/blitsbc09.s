;;;
;;; Multicomp 6809 FPGA-based computer
;;;
;;;    low level routines, but not the tricky ones.
;;;    see tricks.s for those.

;;; coco3:
;;; $ff91 writeonly
;;; $ffa0
;;; $ff90
;;; $ffd9   high-speed poke
;;; $ff9c   scroll register
;;; $ffae   super basic in MMU
;;; $c033   BASIC mirror of video reg
;;; $ff98   video row setup
;;; $ff99   video col setup
;;; $ff9d   video map setup
;;; $ffb0   video colour
;;; $ffb0   video colour
;;; $ffb8   video colour
;;; $ffb0   video colour
;;; $ffb0   video colour

;;; coco3 MMU
;;; accessed through registers $ff91 and $ffa0-$ffaf
;;; 2 possible memory maps: map0, map1 selected by $ff91[0]
;;; map0 is used for User mode, map1 is used for Kernel mode.
;;; map1 is selected at boot (ie, now).
;;; when 0, select map0 using pages stored in $ffa0-$ffa7
;;; when 1, select map1 using pages stored in $ffa8-$ffaf
;;; a 512K system has 64 blocks, numbered $00 to $3f
;;; write the block number to the paging register. On readback,
;;; only bits 5:0 are valid; the other bits can contain junk.

;;; multicomp09 MMU
;;; accessed through two WRITE-ONLY registers MMUADR, MMUDAT
;;; 2 possible memory maps: map0, map1 selected by MMUADR[6]
;;; map0 is used for User mode, map1 is used for Kernel mode.
;;; map0 is selected at boot (ie, now)
;;; .. to avoid pointless divergence from coco3, the first
;;; hardware setup step will be to flip to map1.
;;; [NAC HACK 2016Apr23] in the future, may handle this in
;;; forth or in the bootstrap
;;; when 0, select map0 using MAPSEL values 0-7
;;; when 1, select map1 using MAPSEL values 8-15
;;; MAPSEL is MMUADR[3:0]
;;; a  512K system has  64 blocks, numbered $00 to $3f
;;; a 1024K system has 128 blocks, numbered $00 to $7f
;;; Write the block number to MMUDAT[6:0]
;;; MMUDAT[7]=1 write-protects the selected block - NOT USED HERE!

;;; coco3: at the time the boot loader passes control this the code here,
;;; map1 is selected (Kernel space) and the map1 mapping
;;; registers are selecting blocks 0-7.
;;; map0 is selecting blocks $38-$3f.

;;; multicomp09: at the time the boot loader passes control this the code here,
;;; map0 is selected (user space) and the map0 mapping
;;; registers are selecting blocks 0-7.
;;; map1 mapping registers are uninitialised.

	.module blitsbc09

	; exported symbols
	.globl init_early
	.globl init_hardware
	.globl interrupt_handler
        .globl _program_vectors
	.globl map_kernel
	.globl map_process
	.globl map_process_always
	.globl map_save
	.globl map_restore
	.globl _need_resched
	.globl _bufpool
	.globl _discard_size
        .globl _krn_mmu_map
        .globl _usr_mmu_map
	.globl curr_tr

	; exported debugging tools
        .globl _plt_monitor
	.globl _plt_reboot
        .globl outchar
	.globl ___hard_di
	.globl ___hard_ei
	.globl ___hard_irqrestore

	; imported symbols
        .globl _ramsize
        .globl _procmem
        .globl unix_syscall_entry
	.globl nmi_handler
	.globl null_handler

        include "kernel.def"
        include "../kernel09.def"
	include "platform.def"

	.area	.buffers

_bufpool:
	.ds	BUFSIZE*NBUFS

	.area	.discard
_discard_size:
	.db	__sectionlen_.discard__/BUFSIZE

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK
; -----------------------------------------------------------------------------
	.area .common


saved_tr
	.db 0		; the saved state of mapping
curr_tr
	.db 0		; the current state of mapping 0 = kernel map in force, 1 = user
_need_resched
	.db 0		; scheduler flag

;;; SBC09 16K*4 memory maps 0 (kernel), 1 (user) 
_krn_mmu_map
	.db	$84,$85,$86,$87 ; mmu registers 0-14 (mod 2)
_usr_mmu_map
	.db	$84,$85,$86,$87 ; mmu registers 16-30 (mod 2)


_plt_monitor:
	orcc	#0x10
	bra	_plt_monitor

_plt_reboot:
	orcc 	#0x10		; turn off interrupts
        bra     _plt_reboot    ; [NAC HACK 2016May07] endless loop


;;; Turn off interrupts
;;;    takes: nothing
;;;    returns: B = original irq (cc) state
___hard_di:
	tfr	cc,b		; return the old irq state
	orcc	#0x10
	rts

;;; Turn on interrupts
;;;   takes: nothing
;;;   returns: nothing
___hard_ei:
	andcc	#0xef
	rts

;;; Restore interrupts to saved setting
;;;   takes: B = saved state (as returned from _di )
;;;   returns: nothing
___hard_irqrestore:		; B holds the data
	tfr	b,cc
	rts

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK
; -----------------------------------------------------------------------------

        .area .discard

;;;  Stuff to initialize *before* hardware
;;;    takes: nothing
;;;    returns: nothing
init_early:
	ldx	#null_handler	; [NAC HACK 2016Apr23] what's this for??
	stx	1
	lda	#0x7E
	sta	0
        rts



;;; Initialize Hardware !
;;;    takes: nothing
;;;    returns: nothing
init_hardware:
	;; [NAC HACK 2016Apr23] todo: size the memory. For now, assume 512K like coco3
	;; set system RAM size
	ldd 	#512
	std 	_ramsize
	ldd 	#512-64
	std 	_procmem

;;; Enable timer interrupt


	; Reset hardware is done in boot rom
	; set SYSVIA timer 1 to do 100cs count like MOS and cause interrupts
	lda	#$C0		
	sta	sheila_SYSVIA_ier		; enable T1 interrupt
	lda	#$60				; set system VIA ACR
	sta	sheila_SYSVIA_acr			; 
						; disable latching
						; disable shift register
						; T1 counter continuous interrupts
						; T2 counter timed interrupt
	lda	#$0e				; set system VIA T1 counter (Low)
	sta	sheila_SYSVIA_t1ll			; 
						; this becomes effective when T1 hi set
	lda	#$27				; set T1 (hi) to &27 this sets T1 to &270E (9998 uS)
	sta	sheila_SYSVIA_t1lh		; or 10msec, interrupts occur every 10msec therefore
	sta	sheila_SYSVIA_t1ch		; 



	; the boot rom/restart should have set tasks 0 and 1 as $80-83

;;	lda	#(MMU_MAP0|8)	; stay in map0, select 1st mapping register for map1
;;	ldx	#MMUADR
;;
;;	ldy	#_krn_mmu_map
;;	ldb	,y+   		; page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=8, then write B to MMUDAT
;;	inca			; next mapsel
;;	ldb     ,y+     	; next page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=9, then write B to MMUDAT
;;	inca			; next mapsel
;;	ldb     ,y+     	; next page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=a, then write B to MMUDAT
;;	inca			; next mapsel
;;	ldb     ,y+     	; next page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=b, then write B to MMUDAT
;;	inca			; next mapsel
;;	ldb     ,y+     	; next page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=c, then write B to MMUDAT
;;	inca			; next mapsel
;;	ldb     ,y+     	; next page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=d, then write B to MMUDAT
;;	inca			; next mapsel
;;	ldb     ,y+     	; next page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=e, then write B to MMUDAT
;;	inca			; next mapsel
;;	ldb     ,y+     	; next page from krn_mmu_map
;;	std	,x		; Write A to MMUADR to set MAPSEL=f, then write B to MMUDAT
;;
	;; swap to kernel (0)
	;; the two labels generate entries in the map file that are useful
	;; when debugging: did we get past this step successfully.

	clr	curr_tr		; indicate kernel mapping is in force

	;; SBC09 has RAM at the hardware vector positions but they are offset 
	;; to appear at F7Fx
	;; so we can write the addresses directly; 2 bytes per vector:
	ldx	#0xf7f2		; address of SWI3 vector
	ldy	#badswi_handler
	sty	,x++		; SWI3 handler
	sty	,x++		; SWI2 handler
	ldy	#firq_handler
	sty	,x++		; FIRQ handler
	ldy	#interrupt_handler
	sty	,x++		; IRQ  handler
	ldy	#unix_syscall_entry
	sty	,x++		; SWI  handler
	ldy	#nmi_handler
	sty	,x++		; NMI  handler

	jsr	_devtty_init
xinihw:	rts


;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

	.area .common

;;; Platform specific userspace setup
;;;   We're going to borrow this to copy the common bank
;;;   into the userspace too.
;;;   takes: X = page table pointer
;;;   returns: nothing
_program_vectors:
	;; copy the common section into user-space

	lda	,x
	sta	MMU_MAP+MMU_16_0

	lda	#0x7E
	sta	0

	;; restore the MMU mapping that we trampled on
	;; MMUADR still has block 8 selected so no need to re-write it.

	;; retrieve value that used to be in block 0
	lda	_krn_mmu_map
	;; and restore it
	sta	MMU_MAP+MMU_16_0

	rts    	; restore reg and return



;;;  FIXME:  these interrupt handlers should prolly do something
;;;  in the future.
firq_handler:
badswi_handler:
	rti


;;; Userspace mapping pages 7+  kernel mapping pages 3-5, first common 6
;;;   takes: nothing
;;;   returns: nothing
;;;   modifies: nothing - all registers preserved
map_process_always:
	pshs	x
	ldx	#U_DATA__U_PAGE
	jsr	map_process_2
	puls	x,pc

;;; Maps a page table into cpu space
;;;   takes: X - pointer page table ( ptptr )
;;;   returns: nothing
;;;   modifies: nothing - all registers preserved
map_process:
	cmpx	#0		; is zero?
	bne	map_process_2	; no then map process; else: map the kernel
	;; !!! fall-through to below

;;; Maps the Kernel into CPU space
;;;   takes: nothing
;;;   returns: nothing
;;;   modifies: nothing - all registers preserved
;;;	Map in the kernel below the current common, all registers preserved
map_kernel:
	pshs	a,cc
	orcc	#$10			; mask IRQ so MMU update atomic

	lda	_krn_mmu_map
	sta	MMU_MAP+MMU_16_0
	lda	_krn_mmu_map+1
	sta	MMU_MAP+MMU_16_4
	lda	_krn_mmu_map+2
	sta	MMU_MAP+MMU_16_8
	lda	_krn_mmu_map+3
	sta	MMU_MAP+MMU_16_C

	clr	curr_tr			; indicate kernel mode

	puls 	a,cc,pc

;;; User is in MAP0 with the top 8K as common
;;; As the core code currently does 16K happily but not 8 we just pair
;;; up pages

;; DB: for now just do the bottom 3!

;;; Maps a page table into the MMU
;;;   takes: X = pointer to page table
;;;   returns: nothing
;;;   modifies: nothing - all registers preserved
map_process_2:
	pshs	x,y,a,b,cc
	orcc	#$10			; mask IRQ so MMU update atomic

	;; first, copy entries from page table to usr_mmu_map
	ldy	#_usr_mmu_map

	lda	,X+
	sta	,Y+
	sta	MMU_MAP+MMU_16_0
	lda	,X+
	sta	,Y+
	sta	MMU_MAP+MMU_16_4
	lda	,X+
	sta	,Y+
	sta	MMU_MAP+MMU_16_8
	lda	,X+
	sta	,Y+
	sta	MMU_MAP+MMU_16_C

	lda 	#1
	sta	curr_tr			; indicate user mode

	puls	x,y,a,b,cc,pc	; so had better include common!

;;;
;;;	Restore a saved mapping. We are guaranteed that we won't switch
;;;	common copy between save and restore. Preserve all registers
;;;
;;;	We cheat somewhat. We have two mapping sets, so just remember
;;;	which space we were in. Note: we could be in kernel in either
;;;	space while doing user copies
;;;
map_restore:
	tst	saved_tr
	beq	map_kernel

	pshs	A,Y,CC
	orcc	#$10			; mask IRQ so MMU update atomic

	; restore user mao
	ldy	#_usr_mmu_map

	lda	,Y+
	sta	MMU_MAP+MMU_16_0
	lda	,Y+
	sta	MMU_MAP+MMU_16_4
	lda	,Y+
	sta	MMU_MAP+MMU_16_8
	lda	,Y+
	sta	MMU_MAP+MMU_16_C

	lda	#1
	sta	curr_tr

	puls	A,Y,CC,PC



;;; Save current mapping
;;;   takes: nothing
;;;   returns: nothing
map_save:
	pshs	a
	lda	curr_tr
	sta	saved_tr
	puls	a,pc

;;; Maps the memory for swap transfers
;;;   takes: A = swap token ( a page no. )
;;;   returns: nothing
;;; [NAC HACK 2016May01] maps 16K into kernel space
;;; [NAC HACK 2016May15] coco3 has this in .text instead of .common - is that correct?
map_for_swap
	ldb	curr_tr

	SWI3				; cause a crash for now!


	rts

;;;  Print a character to debugging
;;;   takes: A = character
;;;   returns: nothing
outchar
		pshs	B,CC
		ldb 	#ACIA_TDRE
outchar_lp	bitb	sheila_ACIA_CTL
		beq	outchar_lp
		sta	sheila_ACIA_DATA
		puls	B,CC,PC
