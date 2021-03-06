;;; Phase 2 of the final project.
;;; (c) 2014 Erik Kessler
	.requ	wpc,r15
	.requ	ins,r14
	.requ	cc,r13
	.requ	lreg,r11
	.requ	rreg1,r10
	.requ	rvalue,r9
	.requ	opcode,r8
	.requ	arthss,r7	; Arth second source
	.requ	shop,r7
	.requ	srcr2,r6
	.requ	shiftcount,r5
	.requ	ncc,r7
	.requ	expon,r7
	
	.equ	sp,13
	.equ	pc,15
	.equ	wr0,0
	.equ	wr1,1
	
	.equ	eqb,0x40000000
	.equ	ltb,0x90000000
	.equ	scc,0x10000000
	.equ	lregm,0x7800000
	.equ	rreg1m,0x780000
	.equ	opcodem,0x78000000
	
	.equ	ccalign,16
	.equ	shopalign,32
	.equ	opalign,16
	.equ	swialign,16
	jmp	start
	
	.origin 16		; Make room for registers
start:	mov	$0x00ffffff,sp 	; Set sp to the highest value
	mov	$0,wr0
	mov	$0,wr1
	lea	WARM,r0		
	trap	$SysOverlay	; Load warm code into memory
	
get:	mov	WARM(wpc),ins	; Get instruction
	mov	ins,cc		; Get the instructions conditions
	shr	$29,cc		; cc low 3 bits
	mul	$ccalign,cc	; cc * 16
	lea	always,r0
	add	cc,r0
	mov	r0,rip

	.align ccalign
always:	jmp	asb
	.align ccalign
never:	jmp	next
	.align ccalign
eq:	mov	pc,cc
	test	$eqb,cc
	je	next
	jmp	asb
	.align ccalign
ne:	mov	pc,cc
	test	$eqb,cc
	jne	next
	jmp	asb
	.align ccalign
lt:	mov	pc,cc
	and	$ltb,cc
	je	next
	cmp	$ltb,cc
	je	next
	jmp	asb
	.align	ccalign
le:	mov	pc,cc
	and	$ltb,cc
	je	next
	cmp	$ltb,cc
	je	next
	jmp	eq
	.align ccalign
ge:	mov	pc,cc
	and	$ltb,cc
	je	asb
	cmp	$ltb,cc
	je	asb
	jmp	next
	.align ccalign
gt:	mov	pc,cc
	and	$ltb,cc
	je	ne
	cmp	ltb,cc
	je	ne
	jmp	next
	
	

asb:	mov	ins,cc		; Store if need to set cc
	and	$scc,cc
	shl	$4,ins
	jl	sb		; It load/store or branch
	mov	ins,opcode	; Get opcode
	and	$opcodem,opcode
	shr	$27,opcode
	mov	ins,lreg	; Get left reg
	and	$lregm,lreg
	shr	$23,lreg
	mov	ins,rreg1	; Get right reg
	and	$rreg1m,rreg1
	shr	$19,rreg1
	shl	$13,ins
	jge	immed		; immediate
	mov	ins,arthss
	shr	$29,arthss
	mov	ins,srcr2
	shl	$5,srcr2
	shr	$28,srcr2	; src reg 2
	mov	ins,shiftcount
	shl	$9,shiftcount
	shr	$26,shiftcount	; shiftcount
	mov	(srcr2),rvalue
	cmp	$6,arthss	; reg product?
	jl	shift

	mul	(shiftcount),rvalue ; reg product
	jmp	op
	
	
shift:	cmp	$0b101,arthss
	cmove	(shiftcount),shiftcount 
	mov 	ins,shop 	; need shop
	shl	$3,shop
	shr	$30,shop
	mul	$shopalign,shop
	lea	lsl,r0
	add 	shop,r0
	mov	r0,rip

	.align shopalign
lsl:	shl	shiftcount,rvalue
	mov	pc,ncc
	jmp	setcc

	.align shopalign
	shr	shiftcount,rvalue
	mov	pc,ncc
	jmp	setcc

	.align shopalign
	sar	shiftcount,rvalue
	mov	pc,ncc
	jmp	setcc

	.align	shopalign
ror:	cmp	$0,shiftcount
	jle	setccr
	shr	$1,rvalue
	mov	ccr,ncc
	test	$2,ncc
	mov	$0x80000000,r0
	cmove	$0,r0
	add	r0,rvalue
	sub	$1,shiftcount
	jmp	ror

setccr:	test	$2,ncc
	mov	0b1000,r0
	cmove	0b0000,r0
	or	r0,ncc
setcc:	cmp	$0,cc
	je	op
	and	$0xFFFFFFF,pc
	shl	$28,ncc
	or	ncc,pc
	jmp	op

	
immed:	mov	ins,expon
	shr	$26,expon
	shl	$6,ins
	shr	$23,ins		; ins now has value
	mov	ins,rvalue
	shl	expon,rvalue
	jmp	op

op:	mul	$opalign,opcode
	lea	add,r0
	add	opcode,r0
	mov	r0,rip

	.align opalign
add:	mov	(rreg1),r0
	add	rvalue,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1
	
	.align opalign
addc:	mov	(rreg1),r0
	add	rvalue,r0
	test	$0x20000000,pc
	mov	$1,r1
	cmove	$0,r1
	add	r1,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1
	
	.align opalign
sub:	mov	(rreg1),r0
	sub	rvalue,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1

	.align opalign
cmp:	cmp	rvalue,(rreg1)
	mov	ccr,ncc
	mov	$1,cc
	jmp	setcc1

	.align opalign
eor:	mov	(rreg1),r0
	xor	rvalue,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1
	
	.align opalign
or:	mov	(rreg1),r0
	or	rvalue,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1
	
	.align opalign
nand:	mov	(rreg1),r0
	and	rvalue,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1

	.align opalign
test:	mov	(rreg1),r0
	and	rvalue,r0
	mov	ccr,ncc
	jmp	setcc1

	.align opalign
mul:	mov	(rreg1),r0
	mul	rvalue,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1

	.align opalign
mla:	jmp 	add

	.align opalign
div:	mov	(rreg1),r0
	div	rvalue,r0
	mov	ccr,ncc
	mov	r0,(lreg)
	jmp	setcc1

	.align opalign
mov:	mov	rvalue,(lreg)
	or	$0,(lreg)
	mov	ccr,ncc
	jmp	setcc1

	.align opalign
mvn:	mov	rvalue,(lreg)
	xor	$-1,(lreg)
	mov	ccr,ncc
	jmp	setcc1

	.align opalign
swi:	jmp	swii

	.align opalign
ldm:	jmp	ldmm
	
	.align opalign
stm:	jmp	stmm
		

swii:	mul	$swialign,rvalue
	lea	halt,r0
	add	rvalue,r0
	mov	r0,rip

	.align swialign
halt:	trap	$SysHalt
	
	.align	swialign
getc:	trap	$SysGetChar
	mov	r0,wr0
	test	$-1,wr0
	mov	ccr,ncc
	jmp	setcc1

	.align swialign
getn:	trap	$SysGetNum
	mov	r0,wr0
	test	$-1,wr0
	mov	ccr,ncc
	jmp	setcc1

	.align swialign
putc:	mov	wr0,r0
	trap	$SysPutChar
	test	$-1,r0
	mov	ccr,ncc
	jmp	setcc1

	.align swialign
putn:	mov	wr0,r0
	trap	$SysPutNum
	test	$-1,r0
	mov	ccr,ncc
	jmp	setcc1

	.align swialign
entrop:	trap	$SysEntropy
	mov	r0,wr0
	test	$-1,r0
	mov	ccr,ncc
	jmp	setcc1

	.align swialign
overl:	lea	WARM,r0
	add	wr0,r0
	trap	$SysOverlay
	test	$-1,r0
	mov	ccr,ncc
	jmp	setcc1
	
	.align swialign
pla:	mov	wr0,r0
	trap	$SysPLA
	mov	r0,wr0
	test	$-1,r0
	mov	ccr,ncc
	jmp	setcc1

ldmm:	mov	$1,r1
	mov	$-1,r0
_loop:	add	$1,r0
	cmp	$15,r0
	je	ldpc
	test	r1,rvalue
	shl	$1,r1
	je	_loop
	mov	WARM(lreg),(r0)
	add	$1,lreg
	jmp	_loop

ldpc:	test	$0x8000,rvalue
	je	next
	mov	WARM(lreg),pc
	add	$1,lreg
	test	$-1,pc
	mov	ccr,ncc
	jmp	setcc1

stmm:	mov	$0x8000,r1
	mov	$16,r0
_loop:	sub	$1,r0
	cmp	$-1,r0
	je	next
	test	r1,rvalue
	je	_loop
	mov	(r0),WARM(lreg)
	sub	$1,lreg
	jmp	_loop
	
sb:	shl	$1,ins
	jl	br
	mov	ins,opcode	; Get opcode
	shr	$28,opcode
	mov	ins,lreg	; Get left reg
	shl	$4,lreg
	shr	$28,lreg
	mov	ins,rreg1	; Get right reg
	shl	$8,rreg1
	shr	$28,rreg1
	shl	$12,ins
	jl	indexing
	mov	ins,rvalue
	shl	$1,rvalue
	sar	$18,rvalue
	jmp	slop
	
indexing:
	


	
br:


setcc1:	cmp	$0,cc
	je	next
	and	$0xFFFFFFF,pc
	shl	$28,ncc
	or	ncc,pc

next:	add	$1,wpc
	add	$1,pc
	jmp	get
	


WARM:	
























