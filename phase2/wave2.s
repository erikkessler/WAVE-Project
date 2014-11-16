;;; Phase 2 of the final project.
;;; (c) 2014 Erik Kessler
	.requ	wpc,r15		; Program counter for the Warm
	.requ	ins,r14		; Holds current Warm instruction
	.requ	cc,r13		; Deals with Condition Codes
	.requ	destreg,r11	; Destination Register
	.requ	lsrcreg,r10	; Left Source Register
	.requ	rvalue,r9	; Rigth operand
	.requ	opcode,r8	; Operation Code
	.requ	form,r7		; Format Alignment
	.requ	shop,r7		; Shift Operation Code
	.requ	srcr2,r6
	.requ	shiftcount,r5
	.requ	ncc,r7		; New condition code bits
	.requ	expon,r7
	
	.equ	sp,13		; Stack pointer of the Warm
	.equ	pc,15		; Program counter of Warm
	.equ	wr0,0		; r0 of Warm
	.equ	wr1,1		; r1 of Warm
	
	.equ	zmask,0x40000000 ; Checks if Z bit is set
	.equ	nvmask,0x90000000 ; Checks if N,V bits are set
	.equ	sccmask,0x10000000 ; Checks if Set Cond Code bit is set
	.equ	bmask,0xC0000000 ; Checks if it is a branch (27,28 = 1)
	
	jmp	start
	
	.origin 16		; Make room for registers
start:	mov	$0x00ffffff,sp 	; Set sp to the highest value
	mov	$0,wr0
	mov	$0,wr1
	lea	WARM,r0		
	trap	$SysOverlay	; Load warm code into memory
	jmp	get		; Get the first instruction
	
next:	add	$1,wpc
	add	$1,pc	
get:	mov	WARM(wpc),ins	; Get instruction

;;; The first thing we do is look at the condion codes to
;;; see if we need to execute the instruction.
;;; Note: pc holds the cc bits (NZCV) in the high 4 bits.
	mov	ins,cc		; Get the instructions conditions
	shr	$29,cc		; cc low 3 bits
	lea	ccops,r0
	add	cc,r0
	mov	(r0),rip

always:	jmp	decode		; Always execute

nv:	jmp	next		; Don't execute go to next instruction

eq:	test	$zmask,pc	; Check the Z bit
	je	next		; If Z = 0, go to next instruction
	jmp	decode

ne:	test	$zmask,pc	; Check the Z bit
	jne	next		; If Z = 1, go to next instruction
	jmp	decode

lt:	mov	pc,cc		; Check for N != V
	and	$nvmask,cc
	je	next		; If both 0, go to next
	cmp	$nvmask,cc
	je	next		; If both 1, to to next
	jmp	decode

le:	mov	pc,cc		; Z = 1 and N != V
	and	$nvmask,cc
	je	next
	cmp	$nvmask,cc
	je	next
	jmp	eq		; N != V now check Z using eq

ge:	mov	pc,cc		; Check if N = V
	and	$nvmask,cc
	je	decode		; If both 0 then good to go
	cmp	$nvmask,cc
	je	decode		; If both 1 then good to go
	jmp	next

gt:	mov	pc,cc		; Check if Z = 0 and N = V
	and	$nvmask,cc
	je	ne		; Check Z using ne
	cmp	nvmask,cc
	je	ne
	jmp	next
	
	
;;; We have determined the we should execute the insruction, so now to
;;; decode. Our goal is to get the Operation Code in the register
;;; opcode, the destination register in the register destreg, the
;;; lefthand source register in the register lsrcreg, and the
;;; right operand in the register rvalue. Note: branching is immediatly
;;; detected and handled on its own. Also note if cc is true (not 0)
;;; we need to set the condition codes.
decode:
	shl	$4,ins		; Now bit 27 is in 32nd bit of register
	mov	ins,r0		; Check if it a branch
	xor	$bmask,r0
	je	branch		; It a branch, handle branch instruction

	mov	ins,cc		; Store if need to set cc
	and	$sccmask,cc

	mov	ins,opcode	; Get opcode
	shr	$27,opcode
	shl	$5,ins
	mov	ins,destreg	; Get destination register
	shr	$28,destreg
	shl	$4,ins
	mov	ins,lsrcreg	; Get source register
	shr	$28,lsrcreg
	shl	$4,ins		; Now bit 14 is in 32nd bit of register
	jge	immed		; Immediate or signed offset
	shl	$1,ins		; Bit 13 now in 32
	mov	ins,shop
	shl	$2,shop		; Get the shift operation
	shr	$30,shop
	mov	ins,srcr2	; Get the src reg 2/index reg
	shl	$4,srcr2
	shr	$28,srcr2
	mov	ins,shiftcount	; Get the shiftcount/sh reg/src reg 3
	shl	$8,shiftcount
	shr	$26,shiftcount
	mov	(srcr2),rvalue	; Setup rvalue
	mov	ins,form	; Get the format
	shr	$30,form
	lea	formals,r0
	add	form,r0
	mov	(r0),rip

rsi:				; Register Shifted by Immediate Mode
	lea	shops,r0
	add	shop,r0
	mov	(r0),rip

lsl:				; Logical shift right
	shl	shiftcount,rvalue
	mov	ccr,ncc		; Store condition codes
	jmp	execute
lsr:				; Logical shift right
	shr	shiftcount,rvalue
	mov	ccr,ncc
	jmp	execute
asr:				; Arithmetic shift right
	sar	shiftcount,rvalue
	mov	ccr,ncc
	jmp	execute
ror:				; Rotate right
	cmp	$0,shiftcount
	jle	execute
	shr	$1,rvalue	; Shift right 1
	mov	ccr,ncc
	test	$2,ncc		; See if there was carry
	mov	$0x80000000,r0	; If so add it on the left
	cmove	$0,r0
	add	r0,rvalue
	mov	ccr,ncc
	sub	$1,shiftcount
	jmp	ror		; Rotate until done

	
rsr:				; Register Shifted by Register Mode
	mov	(shiftcount),shiftcount
	jmp	rsi
rpm:				; Register Product Mode
	mul	(shiftcount),rvalue
	jmp	execute
	
immed:	cmp	$0,opcode	; Test if opcode starts with 1
	jl	offsetbr	; If it does, use signed offset from base
	mov	ins,expon	; Get the exponent
	shr	$26,expon
	shl	$6,ins
	shr	$23,ins		; ins now has value
	mov	ins,rvalue
	shl	expon,rvalue	; Shift value by exponent
	jmp	execute

offsetbr:
	mov	ins,rvalue
	shr	$18,rvalue

;;; Now we have the Operation Code in opcode, the destination register
;;; in destreg, the source register in lsrcreg, and the right
;;; operand in rvalue.
;;; Now we need to carry out the instructions. Note branching is handled
;;; on its own.
execute:
	lea	ops,r0
	add	opcode,r0
	mov	(r0),rip

add:	mov	(srcreg),r0
	add	rvalue,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc

adc:	mov	(srcreg),r0
	add	rvalue,r0
	test	$0x20000000,pc
	mov	$1,r1
	cmove	$0,r1
	add	r1,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc
	
sub:	mov	(srcreg),r0
	sub	rvalue,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc

cmp:	cmp	rvalue,(srcreg)
	mov	ccr,ncc
	mov	$1,cc
	jmp	setcc

eor:	mov	(srcreg),r0
	xor	rvalue,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc1
	
orr:	mov	(srcreg),r0
	or	rvalue,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc1
	
and:	mov	(srcreg),r0
	and	rvalue,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc1

tst:	mov	(srcreg),r0
	and	rvalue,r0
	mov	ccr,ncc
	jmp	setcc1

mul:	mov	(srcreg),r0
	mul	rvalue,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc1

div:	mov	(srcreg),r0
	div	rvalue,r0
	mov	ccr,ncc
	mov	r0,(destreg)
	jmp	setcc1

mov:	mov	rvalue,(destreg)
	or	$0,(destreg)
	mov	ccr,ncc
	jmp	setcc1

mvn:	mov	rvalue,(destreg)
	xor	$-1,(destreg)
	mov	ccr,ncc
	jmp	setcc1

swi:	lea	swiops,r0
	add	rvalue,r0
	mov	(r0),rip

halt:	trap	$SysHalt	; Just halt
	
getc:	trap	$SysGetChar	; Get the char, now in r0
	mov	r0,wr0		; Move it to wr0
	jmp	swisetcc

getn:	trap	$SysGetNum	; Get the num, now in r0
	mov	r0,wr0		; Move it to wr0
	jmp	swisetcc

putc:	mov	wr0,r0		; Put wr0 into r0
	trap	$SysPutChar	; Put the char
	jmp	swisetcc

putn:	mov	wr0,r0		; Put wr0 into r0
	trap	$SysPutNum	; Put the num
	jmp	swisetcc

entropy:
	trap	$SysEntropy	; Get the random number
	mov	r0,wr0		; Move it to wr0
	jmp	swisetcc

overlay:
	lea	WARM,r0		; Make sure use WARM memory space
	add	wr0,r0
	trap	$SysOverlay
	jmp	swisetcc
	
pla:	mov	wr0,r0		
	trap	$SysPLA
	mov	r0,wr0
	jmp	swisetcc

;;; Back to more instructions
ldm:	mov	$1,r1
	mov	$-1,r0
_loop:	add	$1,r0
	cmp	$15,r0
	je	_ldpc
	test	r1,rvalue
	shl	$1,r1
	je	_loop
	mov	WARM(destreg),(r0)
	add	$1,destreg
	jmp	_loop

_ldpc:	test	$0x8000,rvalue
	je	next
	mov	WARM(destreg),pc
	add	$1,destreg
	test	$-1,pc
	mov	ccr,ncc
	jmp	setcc1


stm:	mov	$0x8000,r1
	mov	$16,r0
_loop:	sub	$1,r0
	cmp	$-1,r0
	je	next
	test	r1,rvalue
	je	_loop
	mov	(r0),WARM(destreg)
	sub	$1,destreg
	jmp	_loop

ldr:

str:

ldu:

stu:

adr:
	
		
;;; Now we need to set the condition codes if requested
swisetcc:
	cmp	$0,r0
	mov	ccr,ncc
setcc:	cmp	$0,cc
	je	next
	and	$0xFFFFFFF,pc
	shl	$28,ncc
	or	ncc,pc
	jmp	next

;;; Here we handle branching. Bit 27 is the high bit.
branch:	


;;; These are arrays that will allow us to jump to a specific spots
;;; in the program based on the bits.
ccops:				; Condition Code Ops
	.data	always, nv, eq, ne, lt, le, ge, gt 


formaln:			; Format Alignments
	.data	rsi, rsr, rpm

shops:				; Shift Operations
	.data	lsl, lsr, asr, ror

ops:				; Operation Codes
	.data	add, adc, sub, cmp, eor, orr, and, tst, mul, add, div, mov, mvn, swi, ldm, stm, ldr, str, ldu, stu, adr
	;; Note: mla is just add because we handled the multiplication
	;; when we decoded the instruction.

swiops:				; Software Interrupts
	.data	halt, getc, getn, putc, putn, entropy, overlay, pla

;;; Here is where our WARM program's memory starts
WARM:	
























