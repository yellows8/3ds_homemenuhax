#include <string.h>
#include <stdio.h>

//Note that the actual Home Menu decompression function doesn't have an outsize parameter.
int lz11Decompress(unsigned char *src, unsigned char *dst, int insize, int outsize) { //Based on the code from here, modified to mostly match the Home Menu code: https://github.com/mtheall/decompress/blob/master/source/lz11.c
  unsigned int i;
  unsigned char flags;
  int pos=0, pos2, srcpos=0;
  unsigned char *original_dstval = dst;
  unsigned char *original_dst = dst;
  int corruption_detected = 0;
  int dumpeddata = 0;
  FILE *f;

  while(outsize > 0) {
    // read in the flags data
    // from bit 7 to bit 0, following blocks:
    //     0: raw byte
    //     1: compressed block
    if(insize==0)
    {
        printf("input end reached early, outsize=0x%x\n", outsize);
        return -2;
    }
    flags = *src++;
    srcpos++;
    //if(corruption_detected)flags = 0;
    insize--;
    for(i = 0; i < 8 && outsize > 0; i++, flags <<= 1) {
      if(flags&0x80) { // compressed block
        int len;  // length
        int disp; // displacement
        switch((*src)>>4) {
          case 0: // extended block
            if(insize==0)
            {
                 printf("input end reached early, outsize=0x%x\n", outsize);
                 return -2;
            }
            len   = (*src++)<<4;
            len  |= ((*src)>>4);
            len  += 0x11;
            insize--;
            srcpos++;
            break;
          case 1: // extra extended block
            if(insize<=1)
            {
                 printf("input end reached early, outsize=0x%x\n", outsize);
                 return -2;
            }
            len   = ((*src++)&0x0F)<<12;
            len  |= (*src++)<<4;
            len  |= ((*src)>>4);
            len  += 0x111;
            insize-=2;
            srcpos+=2;
            break;
          default: // normal block
            len   = ((*src)>>4)+1;
        }

        if(insize<=1)
        {
                 printf("input end reached early, outsize=0x%x\n", outsize);
                 return -2;
        }
        disp  = ((*src++)&0x0F)<<8;
        disp |= *src++;
        disp++;
        insize-=2;
        srcpos+=2;

        if(len > outsize || pos-disp < 0)
        {
             printf("Invalid compressed block. len=0x%x outsize=0x%x pos=0x%x disp=0x%x i=0x%x flags=0x%x srcpos=0x%x\n", len, outsize, pos, disp, i, flags, srcpos);
             return -4;
        }

        outsize -= len;

        // for len, copy data from the displacement
        // to the current buffer position
        for(pos2=0; pos2<len; pos2++)
        {
             if(&original_dst[pos2+pos] == src)
             {
                   printf("compressed block copy output addr overwrites the data at src: pos2=0x%x pos=0x%x disp=0x%x actualoffset=0x%x len=0x%x len-pos2=0x%x i=0x%x flags=0x%x srcpos=0x%x\n", pos2, pos, disp, pos2+pos, len, len-pos2, i, flags, srcpos);
                   corruption_detected |= 0x2;
             }
             if(&original_dst[pos2+pos-disp] == src)
             {
                  printf("compressed block copy input addr matches the data at src: pos2=0x%x pos=0x%x disp=0x%x actualoffset=0x%x len=0x%x len-pos2=0x%x i=0x%x flags=0x%x srcpos=0x%x\n", pos2, pos, disp, pos2+pos-disp, len, len-pos2, i, flags, srcpos);
                  corruption_detected |= 0x4;
             }

             if(!dumpeddata && corruption_detected)
             {
                  dumpeddata = 1;
                  printf("Writing decompressed data pre-corruption to file, with size 0x%x...\n", pos2+pos);
                  f = fopen("decompressed_data_precorruption.bin", "wb");
                  if(f)
                  {
                         fwrite(original_dst, 1, pos2+pos, f);
                         fclose(f);
                  }
             }

             original_dst[pos2+pos] = original_dst[pos2+pos-disp];
        }
        dst += len;
        pos += len;
      }

      else { // uncompressed block
        // copy a raw byte from the input to the output
        if(dst == src)
        {
             printf("current output ptr == current input ptr, dst pos = 0x%x (raw byte copy)\n", pos);
             corruption_detected |= 0x1;
        }
        *dst++ = *src++;
        pos++;
        insize--;
        outsize--;
        srcpos++;
      }

      if(outsize==0)
      {
          if(insize >= 32)return -3;
          return 0;
      }
    }
  }

  return 0;
}

int decompress_lz11(unsigned char *compressed_datain, unsigned char *decompressed_dataout, int insize, int maxoutsize)
{
	int decom_size = 0;

	if(compressed_datain[0] != 0x11)return -1;

	decom_size = compressed_datain[1] | (compressed_datain[2]<<8) | (compressed_datain[3]<<16);

	if(decom_size==0)
	{
		if(insize < 4)return -2;
		insize-=4;
		compressed_datain+=4;

		decom_size = compressed_datain[1] | (compressed_datain[2]<<8) | (compressed_datain[3]<<16);
		if(decom_size==0)
		{
			if(insize >= 32)return -3;
			return 0;
		}
	}

	if(decom_size > maxoutsize)return -9;//Not a Home Menu error.

	insize-=4;
	compressed_datain+=4;

	return lz11Decompress(compressed_datain, decompressed_dataout, insize, decom_size);
}

