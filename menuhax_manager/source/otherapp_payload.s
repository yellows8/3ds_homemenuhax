.text
.thumb

@ This is from the arm11code from here: https://github.com/yellows8/3ds_browserhax_common

@ This extracts info from the otherapp payload. Proper metadata/whatever for this stuff would be ideal, but it has to be done this way for now.
.type locatepayload_data, %function
.global locatepayload_data
locatepayload_data: @ r0 = payloadbuf, r1 = size, r2 = u32* output
push {r4, r5, r6, lr}
mov r4, r0
mov r5, r1
mov r6, r2

mov r0, #0 @ Locate the otherapp-payload main() .pool(the code which runs under the actual "otherapp") via the 0x6e4c5f4e value.
ldr r1, =0x6e4c5f4e
locatepayload_data_lp:
ldr r2, [r4, r0]
cmp r1, r2
beq locatepayload_data_lpend

locatepayload_data_lpnext:
add r0, r0, #4
cmp r0, r5
blt locatepayload_data_lp
mov r0, #0
mvn r0, r0
b locatepayload_data_end

locatepayload_data_lpend: @ Locate the "b ." instruction at the end of main(), which is also right before the .pool.
ldr r1, =0xeafffffe
sub r0, r0, #4

locatepayload_data_lp2:
ldr r2, [r4, r0]
cmp r1, r2
beq locatepayload_data_lp2end

locatepayload_data_lp2next:
sub r0, r0, #4
cmp r0, #0
bgt locatepayload_data_lp2
mov r0, #1
mvn r0, r0
b locatepayload_data_end

locatepayload_data_lp2end:
add r0, r0, #4 @ r0 = offset for main() .pool. The below code assumes that the required values are always located at the same relative-offset in the .pool.

mov r1, r5
mov r2, r6
mov r3, r0
add r3, r3, r4
add r3, r3, #8
mov r0, r4
bl locatepayload_writeoutput @ Load the menuropbin offset/size + verify them, and write to the output.
cmp r0, #0
bne locatepayload_data_end

mov r0, #0 @ Locate the inject_payload() function .pool in the otherapp-payload(which actually runs under the "otherapp").
ldr r1, =0x00989680
ldr r3, =0xdeadcafe
locatepayload_data_lp3:
ldr r2, [r4, r0]
cmp r1, r2
bne locatepayload_data_lp3next
mov r2, r0
add r2, r2, r4
ldr r2, [r2, #0x10]
cmp r3, r2
beq locatepayload_data_lp3end

locatepayload_data_lp3next:
add r0, r0, #4
cmp r0, r5
blt locatepayload_data_lp3
mov r0, #7
mvn r0, r0
b locatepayload_data_end

locatepayload_data_lp3end:
add r0, r0, #4

mov r1, r5
mov r2, r6
add r2, r2, #8
mov r3, r0
add r3, r3, r4
mov r0, r4
bl locatepayload_writeoutput @ Load the loadropbin blob offset/size + verify them, and write to the output+8.
cmp r0, #0
bne locatepayload_data_end

mov r0, #0

locatepayload_data_end:
pop {r4, r5, r6, pc}
.pool

locatepayload_writeoutput: @ r0 = payloadbuf, r1 = payloadbufsize, r2 = u32* out. r3 = ptr to two words: +0 = <ptr to size in payload>, +4 = address of the binary.
push {r4, r5, r6, lr}
mov r4, r0
mov r5, r1
mov r6, r2

mov r1, r3
mov r2, r3
ldr r1, [r1, #0] @ ptr to size.
ldr r2, [r2, #4] @ address of the binary.

mov r0, #2
mvn r0, r0
ldr r3, =0x00101000
sub r2, r2, r3 @ r2 = offset of binary, which is written to *(inr2+0).
cmp r2, r5
bcs locatepayload_writeoutput_end @ The binary offset must be within the payloadbuf.
str r2, [r6, #0]

@ Write the size of the binary to *(inr2+4).
mov r0, #3
mvn r0, r0
sub r1, r1, r3
cmp r1, r5
bcs locatepayload_writeoutput_end @ The calculated offset in the payload must be within the input size.
mov r0, #4
mvn r0, r0
ldr r1, [r4, r1]
cmp r1, r5
bcs locatepayload_writeoutput_end @ The binary size must be within the payloadbuf.
str r1, [r6, #4]

mov r0, #5
mvn r0, r0
mov r3, r2
add r3, r3, r1
cmp r3, r5
bcs locatepayload_writeoutput_end @ binary_offset + binary_size must be within the payloadbuf.
mov r0, #6
mvn r0, r0
cmp r3, r2
bcc locatepayload_writeoutput_end @ Check for integer-overflow with the above add.

mov r0, #0

locatepayload_writeoutput_end:
pop {r4, r5, r6, pc}
.pool

.type patchPayload, %function
.global patchPayload
patchPayload: @ r0 = menuropbin*, r1 = targetProcessIndex, r2 = new3ds_flag. This is somewhat based on code from hblauncher with the same function name(minus the code for locating the dlplay memorymap structure).
push {r4, r5, r6, r7, lr}
sub sp, sp, #8

cmp r2, #0
bne patchPayload_new3dsinit

ldr r4, =(0x30000000+0x04000000)//Old3DS
b patchPayload_init

patchPayload_new3dsinit:
ldr r4, =(0x30000000+0x07c00000)

patchPayload_init:
str r4, [sp, #4]

ldr r2, =(0x8000-4)
mov r3, #0

patchPayload_lp: @ Locate the memorymap structure for the dlplay app.
ldr r4, [r0, r3]
add r3, r3, #4
ldr r5, [r0, r3]

cmp r4, #4
bne patchPayload_lpnext
ldr r6, =0x193000
cmp r5, r6
bne patchPayload_lpnext

sub r3, r3, #4
b patchPayload_lpend

patchPayload_lpnext:
cmp r3, r2
blt patchPayload_lp

patchPayload_lpend:
cmp r2, r3
beq patchPayload_enderror

add r4, r0, r3

ldr r2, =(0x8000-0x40)
mov r3, #0

patchPayload_patchlp:
ldr r5, [r0, r3]

lsr r6, r5, #4 @ The loaded word value must be 0xBABE0001..0xBABE0007.
ldr r7, =0xBABE000
cmp r6, r7
bne patchPayload_patchlpnext
mov r6, #0xf
and r6, r6, r5
cmp r6, #0
beq patchPayload_patchlpnext
cmp r6, #7
bgt patchPayload_patchlpnext

cmp r6, #1
bne patchPayload_patchlp_l2
str r1, [r0, r3] @ targetProcessIndex
b patchPayload_patchlpnext

patchPayload_patchlp_l2:
cmp r6, #2
bne patchPayload_patchlp_l3
ldr r6, [sp, #4]
ldr r7, [r4, #0x10]
sub r6, r6, r7
str r6, [r0, r3] @ APP_START_LINEAR
b patchPayload_patchlpnext

patchPayload_patchlp_l3:
cmp r6, #3
bne patchPayload_patchlp_l4
ldr r7, [r4, #0x14]
str r7, [r0, r3] @ processHookAddress
b patchPayload_patchlpnext

patchPayload_patchlp_l4:
cmp r6, #4
bne patchPayload_patchlp_l5
ldr r7, [r4, #0x1c]
str r7, [r0, r3] @ TID-low
b patchPayload_patchlpnext

patchPayload_patchlp_l5:
cmp r6, #5
bne patchPayload_patchlp_l7
ldr r7, [r4, #0x20]
str r7, [r0, r3] @ TID-high
b patchPayload_patchlpnext

patchPayload_patchlp_l7:
cmp r6, #7
bne patchPayload_patchlp_l6
ldr r7, [r4, #0x18]
str r7, [r0, r3] @ processAppCodeAddress
b patchPayload_patchlpnext

patchPayload_patchlp_l6:
cmp r6, #6 @ memorymap
bne patchPayload_patchlpnext

ldr r6, [r4, #0] @ Calculate the memorymap structure size, and restrict the size if needed.
mov r5, #0xc
mul r6, r6, r5
add r6, r6, #0x30
ldr r5, =0x8000
cmp r6, r5
bcc patchPayload_memorymap_cpy_init
mov r6, r5

patchPayload_memorymap_cpy_init:
mov r5, #0
str r6, [sp, #0]

patchPayload_memorymap_cpy: @ Copy the memorymap structure to the current ropbin location.
ldr r7, [r4, r5]
mov r6, r3
add r6, r6, r5
str r7, [r0, r6]
add r5, r5, #4
ldr r6, [sp, #0]
cmp r5, r6
blt patchPayload_memorymap_cpy

patchPayload_patchlpnext:
add r3, r3, #4
cmp r3, r2
blt patchPayload_patchlp

b patchPayload_endsuccess

patchPayload_enderror:
mov r0, #0
mvn r0, r0
b patchPayload_end

patchPayload_endsuccess:
mov r0, #0

patchPayload_end:
add sp, sp, #8
pop {r4, r5, r6, r7, pc}
.pool

