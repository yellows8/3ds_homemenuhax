#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

//Build with: gcc -o homemenu_themelz_tool lz11.c homemenu_themelz_tool.c

//This code simulates how Home Menu handles theme data decompression.

int decompress_lz11(unsigned char *compressed_datain, unsigned char *decompressed_dataout, int insize, int maxoutsize);

int main(int argc, char **argv)
{
	FILE *f;
	unsigned char *buffer;
	int insize = 0;
	int ret;
	struct stat filestats;

	if(argc<3)return 0;

	if(stat(argv[1], &filestats)==-1)
	{
		printf("Failed to stat input.\n");
		return 1;
	}

	insize = filestats.st_size;
	if(insize > 0x150000)
	{
		printf("Input file is too large.\n");
		return 3;
	}

	f = fopen(argv[1], "rb");
	if(f==NULL)
	{
		printf("Failed to open input file for reading.\n");
		return 2;
	}

	buffer = (unsigned char*)malloc(0x400000);
	if(buffer==NULL)
	{
		printf("Failed to alloc mem.\n");
		fclose(f);
		return 4;
	}
	memset(buffer, 0, 0x400000);

	fread(&buffer[0x150000], 1, insize, f);

	fclose(f);

	ret = decompress_lz11(&buffer[0x150000], buffer, insize, 0x400000);
	printf("decompress_lz11() retval: %d\n", ret);

	f = fopen(argv[2], "wb");
	if(f==NULL)
	{
		printf("Failed to open output file for writing.\n");
		free(buffer);
		return 2;
	}

	fwrite(buffer, 1, 0x400000, f);

	fclose(f);

	return 0;
}

