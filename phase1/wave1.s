;;; Phase 1 of the final project.
;;; (c) 2014 Erik Kessler
	.requ	wpc,r8
	lea	WARM, r0
	trap	$SysOverlay

	mov	$0, wpc
loop:	mov	WARM(wpc), r0
	cmp	$0x06800000, r0
	je	found
	add	$1, wpc
	jmp	loop
	
found:	mov	wpc, r0
	trap	$SysPutNum
	mov	$'\n, r0
	trap	$SysPutChar
	trap	$SysHalt
WARM:	