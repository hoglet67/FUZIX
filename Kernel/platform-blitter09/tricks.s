;;;
;;; CoCo3 ghoulish tricks (boo!) ported to multicomp09
;;;
        .module tricks

	;; imported
        .globl _makeproc
        .globl _chksigs
        .globl _getproc
	.globl _udata
        .globl _plt_monitor
        .globl _krn_mmu_map
        .globl _usr_mmu_map
	.globl curr_tr

	;; exported
        .globl _plt_switchout
        .globl _switchin
        .globl _dofork
	.globl _ramtop

        include "kernel.def"
        include "../kernel09.def"
        include "platform.def"

	.area .data
;;; _ramtop cannot be in common, as this memory becomes per-process
;;; when we add better udata handling.
_ramtop:
	.dw 0

_swapstack
	.dw 	0
	.dw 	0

fork_proc_ptr:
	.dw 0 ; (C type is struct p_tab *) -- address of child process p_tab entry

	.area .common

;;; Switchout switches out the current process, finds another that is READY,
;;; possibly the same process, and switches it in.  When a process is
;;; restarted after calling switchout, it thinks it has just returned
;;; from switchout().
_plt_switchout:
	orcc 	#0x10		; irq off

        ;; save machine state
        ldd 	#0		; return zero
	;; return code set here is ignored, but _switchin can
        ;; return from either _switchout OR _dofork, so they must both write
        ;; U_DATA__U_SP with the following on the stack:
	pshs 	d,y,u
	sts 	U_DATA__U_SP	; save SP

        jsr 	_getproc	; X = next process ptr
        jsr 	_switchin	; and switch it in
        ; we should never get here
        jsr 	_plt_monitor


badswitchmsg:
	.ascii 	"_switchin: FAIL"
        .db 	13
	.db 	10
	.db 	0

;;; Switch in a process
;;;   takes: X = process
;;;   returns: shouldn't
_switchin:
        orcc 	#0x10		; irq off

	stx 	_swapstack	; save passed page table *

	; swap in new tasks common area
	lda	P_TAB__P_PAGE_OFFSET+3,X
	sta	MMU_MAP+MMU_16_C
	sta 	_krn_mmu_map+3
	sta	_usr_mmu_map+3

        ; check u_data->u_ptab matches what we wanted
	ldx 	_swapstack
	cmpx 	U_DATA__U_PTAB
        bne 	switchinfail

	lda 	#P_RUNNING
	sta 	P_TAB__P_STATUS_OFFSET,x

	;; clear the 16 bit tick counter
	ldx 	#0
	stx 	_runticks

        ;; restore machine state -- note we may be returning from either
        ;; _switchout or _dofork
        lds 	U_DATA__U_SP
        puls 	x,y,u ; return code and saved U and Y

        ;; enable interrupts, if the ISR isn't already running
	lda	U_DATA__U_ININTERRUPT
	bne 	swtchdone
	andcc 	#0xef
swtchdone:
        rts

switchinfail:
	jsr 	outx
        ldx 	#badswitchmsg
        jsr 	outstring
	;; something went wrong and we didn't switch in what we asked for
        jmp 	_plt_monitor


;;;
;;;	Called from _fork. We are in a syscall, the uarea is live as the
;;;	parent uarea. The kernel is the mapped object.
;;;
_dofork:
        ;; always disconnect the vehicle battery before performing maintenance
        orcc 	#0x10	 ; should already be the case ... belt and braces.

	;; new process in X, get parent pid into y
	stx 	fork_proc_ptr
	ldx 	P_TAB__P_PID_OFFSET,x

        ;; Save the stack pointer and critical registers.
        ;; When this process (the parent) is switched back in, it will be as if
        ;; it returns with the value of the child's pid.
	;; Y has p->p_pid from above, the return value in the parent
        pshs 	x,y,u

        ;; save kernel stack pointer -- when it comes back in the
	;; parent we'll be in
	;; _switchin which will immediately return (appearing to be _dofork()
	;; returning) and with HL (ie return code) containing the child PID.
        ;; Hurray.
        sts 	U_DATA__U_SP

        ;; now we're in a safe state for _switchin to return in the parent
	;; process.

	;; --------- we switch stack copies in this call -----------
	jsr 	fork_copy	; copy 0x000 to udata.u_top and the
				; uarea and return on the childs
				; common
	;; We are now in the kernel child context

        ;; now the copy operation is complete we can get rid of the stuff
        ;; _switchin will be expecting from our copy of the stack.
	puls 	x

	ldx	#_udata
	pshs	x
        ldx 	fork_proc_ptr	; get forked process
        jsr 	_makeproc	; and set it up
	puls	x

	;; any calls to map process will now map the childs memory

	ldx 	#0		; zero out process's tick counter
	stx 	_runticks
        ;; in the child process, fork() returns zero.
	;;
	;; And we exit, with the kernel mapped, the child now being deemed
	;; to be the live uarea. The parent is frozen in time and space as
	;; if it had done a switchout().
        puls y,u,pc


;;; copy the process memory to the new process
;;; and stash parent uarea to old bank
fork_copy:
	;; calculate how many regular pages we need to copy
	ldd	U_DATA__U_TOP	       ; get size of process
	tfr	d,y		       ; make copy of progtop
	anda	#$3f		       ; mask off remainder
	pshs	cc		       ; push onto stack ( remcc )
	tfr	y,d		       ; get copy of progtop
	rola			       ; make low bits = whole pages
	rola			       ;
	rola			       ;
	anda	#$3		       ; bottom two bits are now whole pages
	puls	cc		       ; get remainder's cc (  )
	beq	skip@		       ; skip round-up if zero
	inca			       ; round up
	pshs	a		       ; and put on stack as counter
	;; copy parent's whole pages to child's
skip@	ldx	fork_proc_ptr
	leax	P_TAB__P_PAGE_OFFSET,x ; X = * new process page tables (dest)
	ldu	#U_DATA__U_PAGE	       ; parent process page tables (src)
loop@	ldb	,x+		       ; B = child's next page
	lda	,u+		       ; A = parent's next page
	jsr	copybank	       ; copy bank
	dec	,S		       ; bump counter
	bne	loop@

	leas	1,S			; unstack counter 

	;; copy UDATA + common
	ldx	fork_proc_ptr	       ; X = new process ptr
	ldb	P_TAB__P_PAGE_OFFSET+3,x ;  B = child's UDATA/common page
	lda	U_DATA__U_PAGE+3	 ;  A = parent's UDATA/common page
	jsr	copybank		 ; copy it
	;; remap common page in MMU to new process
	stb	MMU_MAP+MMU_16_C
	stb	_krn_mmu_map+3		; keep the mirror in sync.
	stb	_usr_mmu_map+3		; keep the mirror in sync.
	;;
	; --- we are now on the stack copy, parent stack is locked away ---
	rts	; this stack is copied so safe to return on

;;; Copy data from one bank to another
;;;   takes: B = dest bank, A = src bank
;;; uses low 32Kbyte of kernel address space as the "window" for this
;;; use map 8,9 (0x0000-0x3fff) for dest, map 10,11 (0x4000-0x7fff) for source
copybank
	pshs	d,x,u,y		; changing this will affect "ldb 0,s" below
	;; map in dest
;;DB;;	ldx	#MMUADR		; for storing
;;DB;;	lda     curr_tr		; Select MMU register associated with
;;DB;;	ora	#8		; mapsel=8, for dest, in B
;;DB;;	std	,x		; mapsel=8, page in B
;;DB;;	inca			; mapsel=9
;;DB;;	incb			; adjacent page
;;DB;;	std	,x

	stb	MMU_MAP+MMU_16_0

;;DB;;	;; map in src
;;DB;;	inca			; mapsel=a
;;DB;;	ldb	0,s		; stacked value of A into B
;;DB;;	std	,x
;;DB;;	inca			; mapsel=b
;;DB;;	incb			; adjacent page
;;DB;;	std	,x

	sta	MMU_MAP+MMU_16_4

	;; loop setup
	ldx	#0		; dest address
	ldu	#0x4000		; src address
	;; unrolled: 16 bytes at a time
a@	ldd	,u++
	std	,x++
	ldd	,u++
	std	,x++
	ldd	,u++
	std	,x++
	ldd	,u++
	std	,x++
	ldd	,u++
	std	,x++
	ldd	,u++
	std	,x++
	ldd	,u++
	std	,x++
	ldd	,u++
	std	,x++
	cmpx	#0x4000		; end of copy?
	bne	a@		; no repeat

	;; restore mmu
	ldy	#_krn_mmu_map	; kernel's mmu ptr.. for reading
	ldb	,y+		; page from krn_mmu_map
	stb	MMU_MAP+MMU_16_0
	ldb	,y+		; page from krn_mmu_map
	stb	MMU_MAP+MMU_16_4

	;; return
	puls	d,x,u,y,pc	; return
