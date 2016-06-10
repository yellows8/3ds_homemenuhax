.arm
.section .init
.global _start

_start:

@ End of the titleID array.
.fill (((_start + 0x8 + ((360-1)*8)) - .) / 4), 4, 0xffffffff
.word 0x11223344, 0x55667788

@ End of the s16 array.
.space ((_start + 0xcb0 + ((360-1)*2)) - .)
.hword 0x5848 @ Offset value, menuhax_manager detects this special value and uses the required value instead.

@ End of the s8 array.
.space ((_start + 0xf80 + (360-1)) - .)
.byte 0xff @ Normally this is 0xff anyway, but write this anyway since it's required for this hax.

.space ((_start + 0x2da0) - .)

