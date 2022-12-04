;;;
;;;  blitter + SDC09 JIM RAM driver read / write from JIM
;;;

;;; imported
	.globl blk_op		; blk operation arguments

;;; exported
	.globl _dev_jimram_write
	.globl _dev_jimram_read

        include "platform.def"

	section	.common

;;; Write 512 bytes to JIM
;;; the paging registers have already been set
;;; only handles the data transfer.
;;;
;;; entry: x=data source
;;; can corrupt: a, b, cc, x
;;; must preserve: y, u
_dev_jimram_write
	pshs	y,u
	ldy	#2		; number of 256 byte pages
        	tst     _blk_op+2       	; test user/kernel xfer
        	beq     WrBiz           	; if zero then stay in kernel space
        	jsr     map_process_always ; else flip to user space
WrBiz	clrb
	ldu	#JIM
WrBizLp	lda	,x+		; get byte from sector buffer
	sta	,u+
	decb
	bne	WrBizLp		; next
	inc	fred_JIM_PAGE_LO
	bne	WrBizSk
	inc	fred_JIM_PAGE_HI
WrBizSk	leay	-1,Y
	bne	WrBiz
        	puls    y,u
        	jmp     map_kernel      	; reset to kernel space (tail optimise)


;;; Read 512 bytes from JIM
;;; the paging registers have already been set
;;; only handles the data transfer.
;;;
;;; entry: x=data destination
;;; can corrupt: a, b, cc, x
;;; must preserve: y, u
_dev_jimram_read
	pshs	y,u
	ldy	#2		; number of 256 byte pages
        	tst     	_blk_op+2       ; test user/kernel xfer
        	beq     	RdBiz           ; if zero then stay in kernel space
        	jsr     	map_process_always ; else flip to user space
RdBiz	clrb
	ldu	#JIM
rdBizLp	lda	,U+		; get a byte of JIM
	sta	,x+		; store byte in sector buffer
	decb
	bne	rdBizLp
	inc	fred_JIM_PAGE_LO
	bne	rdBizSk
	inc	fred_JIM_PAGE_HI
rdBizSk	leay	-1,y
	bne	RdBiz		; next
        	puls    	Y,U
        	jmp    	map_kernel      ; reset to kernel space (tail optimise)
