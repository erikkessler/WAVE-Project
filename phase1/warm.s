	swigt	#SysGetNum
	swi	#SysPutNum
	mov	r0,#10
	swi	#SysPutChar
	mov	r4, #19
	swi	#SysHalt