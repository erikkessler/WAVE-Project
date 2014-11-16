
	cmp	r0,#0
	eorne	r0,r15,r2, lsl #40
	swigt	#SysGetNum
	swi	#SysPutNum
	mov	r0,#10
	swi	#SysPutChar
	mov	r4, #19
	swi	#SysHalt