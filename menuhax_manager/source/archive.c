#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <3ds.h>

#include <unzip.h>

#include "archive.h"
#include "log.h"

u32 extdata_archives_lowpathdata[TotalExtdataArchives][3];
FS_Archive extdata_archives[TotalExtdataArchives];
bool extdata_archives_available[TotalExtdataArchives];
u32 extdata_initialized = 0;

Result open_extdata()
{
	Result ret=0;
	u32 pos;
	u32 extdataID_homemenu = 0, extdataID_theme = 0;
	u8 region=0;

	FS_Path archpath;

	ret = cfguInit();
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to init cfg: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	ret = CFGU_SecureInfoGetRegion(&region);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "CFGU_SecureInfoGetRegion() failed: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	cfguExit();

	//Home Menu uses extdataID value 0x0 for the theme-extdata with non-<JPN/USA/EUR>.

	extdata_archives_available[HomeMenu_Extdata] = true;
	extdata_archives_available[Theme_Extdata] = true;

	if(region==CFG_REGION_JPN)
	{
		extdataID_homemenu = 0x00000082;
		extdataID_theme = 0x000002cc;
	}
	else if(region==CFG_REGION_USA)
	{
		extdataID_homemenu = 0x0000008f;
		extdataID_theme = 0x000002cd;
	}
	else if(region==CFG_REGION_EUR)
	{
		extdataID_homemenu = 0x00000098;
		extdataID_theme = 0x000002ce;
	}
	else if(region==CFG_REGION_CHN)
	{
		extdataID_homemenu = 0x000000a1;
		extdata_archives_available[Theme_Extdata] = false;
	}
	else if(region==CFG_REGION_KOR)
	{
		extdataID_homemenu = 0x000000a9;
		extdata_archives_available[Theme_Extdata] = false;
	}
	else if(region==CFG_REGION_TWN)
	{
		extdataID_homemenu = 0x000000b1;
		extdata_archives_available[Theme_Extdata] = false;
	}

	memset(&archpath, 0, sizeof(FS_Path));
	archpath.type = PATH_BINARY;
	archpath.size = 0xc;

	for(pos=0; pos<TotalExtdataArchives; pos++)
	{
		memset(extdata_archives_lowpathdata[pos], 0, 0xc);
		extdata_archives_lowpathdata[pos][0] = 1;//mediatype, 1=SD
	}

	extdata_archives_lowpathdata[HomeMenu_Extdata][1] = extdataID_homemenu;//extdataID-low
	extdata_archives_lowpathdata[Theme_Extdata][1] = extdataID_theme;//extdataID-low

	archpath.data = (u8*)extdata_archives_lowpathdata[HomeMenu_Extdata];

	ret = FSUSER_OpenArchive(&extdata_archives[HomeMenu_Extdata], ARCHIVE_EXTDATA, archpath);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to open homemenu extdata with extdataID=0x%08x, retval: 0x%08x\n", (unsigned int)extdataID_homemenu, (unsigned int)ret);
		return ret;
	}
	extdata_initialized |= 0x1;

	if(extdata_archives_available[Theme_Extdata])
	{
		archpath.data = (u8*)extdata_archives_lowpathdata[Theme_Extdata];

		ret = FSUSER_OpenArchive(&extdata_archives[Theme_Extdata], ARCHIVE_EXTDATA, archpath);
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to open theme extdata with extdataID=0x%08x, retval: 0x%08x\n", (unsigned int)extdataID_theme, (unsigned int)ret);
			log_printf(LOGTAR_ALL, "Exit this app, then goto Home Menu theme-settings so that Home Menu can create the theme extdata.\n");
			return ret;
		}
		extdata_initialized |= 0x2;
	}

	return 0;
}

void close_extdata()
{
	u32 pos;

	for(pos=0; pos<TotalExtdataArchives; pos++)
	{
		if(extdata_initialized & (1<<pos))FSUSER_CloseArchive(extdata_archives[pos]);
	}
}

bool archive_getavailable(Archive archive)
{
	return extdata_archives_available[archive];
}

Result archive_deletefile(Archive archive, char *path)
{
	if(archive==SDArchive)
	{
		if(unlink(path)==-1)return errno;

		return 0;
	}

	return FSUSER_DeleteFile(extdata_archives[archive], fsMakePath(PATH_ASCII, path));
}

//Opens a file contained in a .zip, where path is: "<path to .zip>@<filename in .zip>". The decompressed filesize is written to outsize if not NULL, and the filedata is also read if the input parameters for that are set.
int fszip_readzipfile(const char *path, u32 *outsize, u8 *buffer, u32 size)
{
	unzFile zipf;
	unz_file_info file_info;
	int ret=0;
	char *strptr = NULL;

	char tmp_path[1024];

	memset(tmp_path, 0, sizeof(tmp_path));
	strncpy(tmp_path, path, sizeof(tmp_path)-1);

	strptr = strchr(tmp_path, '@');
	if(strptr==NULL)return -1;

	*strptr = 0;
	strptr++;

	zipf = unzOpen(tmp_path);
	if(zipf==NULL)return -2;

	ret = unzLocateFile(zipf, strptr, 0);

	if(ret==UNZ_OK)ret = unzOpenCurrentFile(zipf);

	if(ret==UNZ_OK)
	{
		ret = unzGetCurrentFileInfo(zipf, &file_info, NULL, 0, NULL, 0, NULL, 0);

		if(ret==UNZ_OK && outsize!=NULL)*outsize = file_info.uncompressed_size;

		if(ret==UNZ_OK && buffer!=NULL && size!=0)
		{
			ret = unzReadCurrentFile(zipf, buffer, size);
			if((u32)ret < size)
			{
				ret = -3;
			}
			else
			{
				ret = UNZ_OK;
			}
		}

		unzCloseCurrentFile(zipf);
	}

	unzClose(zipf);

	return ret;
}

Result archive_getfilesize(Archive archive, char *path, u32 *outsize)
{
	Result ret=0;
	struct stat filestats;
	u64 tmp64=0;
	Handle filehandle=0;
	FILE *f = NULL;
	int fd=0;

	if(archive==SDArchive)
	{
		if(strchr(path, '@'))return fszip_readzipfile(path, outsize, NULL, 0);

		f = fopen(path, "r");
		if(f==NULL)return errno;

		fd = fileno(f);
		if(fd==-1)
		{
			fclose(f);
			return errno;
		}

		if(fstat(fd, &filestats)==-1)return errno;
		fclose(f);

		*outsize = filestats.st_size;

		return 0;
	}

	ret = FSUSER_OpenFile(&filehandle, extdata_archives[archive], fsMakePath(PATH_ASCII, path), 1, 0);
	if(ret!=0)return ret;

	ret = FSFILE_GetSize(filehandle, &tmp64);
	if(ret==0)*outsize = (u32)tmp64;

	FSFILE_Close(filehandle);

	return ret;
}

Result archive_readfile(Archive archive, char *path, u8 *buffer, u32 size)
{
	Result ret=0;
	Handle filehandle=0;
	u32 tmpval=0;
	FILE *f;

	char filepath[256];

	if(archive==SDArchive)
	{
		if(strchr(path, '@'))return fszip_readzipfile(path, NULL, buffer, size);

		memset(filepath, 0, 256);
		strncpy(filepath, path, 255);

		f = fopen(filepath, "r");
		if(f==NULL)return errno;

		tmpval = fread(buffer, 1, size, f);

		fclose(f);

		if(tmpval!=size)return -2;

		return 0;
	}

	ret = FSUSER_OpenFile(&filehandle, extdata_archives[archive], fsMakePath(PATH_ASCII, path), FS_OPEN_READ, 0);
	if(ret!=0)return ret;

	ret = FSFILE_Read(filehandle, &tmpval, 0, buffer, size);

	FSFILE_Close(filehandle);

	if(ret==0 && tmpval!=size)ret=-2;

	return ret;
}

Result archive_writefile(Archive archive, char *path, u8 *buffer, u32 size, u32 createsize)
{
	Result ret=0;
	Handle filehandle=0;
	u32 tmpval=0;
	FILE *f;
	u8 *tmpbuf;

	char filepath[256];

	if(archive==SDArchive)
	{
		memset(filepath, 0, 256);
		strncpy(filepath, path, 255);

		f = fopen(filepath, "w+");
		if(f==NULL)return errno;

		tmpval = fwrite(buffer, 1, size, f);

		fclose(f);

		if(tmpval!=size)return -2;

		return 0;
	}

	ret = FSUSER_OpenFile(&filehandle, extdata_archives[archive], fsMakePath(PATH_ASCII, path), FS_OPEN_WRITE, 0);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to open the file: 0x%08x\n", (unsigned int)ret);

		if(createsize && ret!=0xC92044E6)
		{
			ret = FSUSER_CreateFile(extdata_archives[archive], fsMakePath(PATH_ASCII, path), 0, createsize);
			if(ret)
			{
				log_printf(LOGTAR_ALL, "Failed to create the file: 0x%08x.\n", (unsigned int)ret);
				return ret;
			}

			ret = FSUSER_OpenFile(&filehandle, extdata_archives[archive], fsMakePath(PATH_ASCII, path), FS_OPEN_WRITE, 0);
			if(ret)
			{
				log_printf(LOGTAR_ALL, "Failed to open the file after creation: 0x%08x.\n", (unsigned int)ret);
			}

			if(ret==0 && size!=createsize)
			{
				tmpbuf = malloc(createsize);
				if(tmpbuf==NULL)
				{
					FSFILE_Close(filehandle);
					return -1;
				}
				memset(tmpbuf, 0, createsize);

				ret = FSFILE_Write(filehandle, &tmpval, 0, tmpbuf, createsize, FS_WRITE_FLUSH);
				free(tmpbuf);
				if(ret)FSFILE_Close(filehandle);
			}
		}

		if(ret)return ret;
	}

	ret = FSFILE_Write(filehandle, &tmpval, 0, buffer, size, FS_WRITE_FLUSH);

	FSFILE_Close(filehandle);

	if(ret==0 && tmpval!=size)ret=-2;

	return ret;
}

Result archive_copyfile(Archive inarchive, Archive outarchive, char *inpath, char *outpath, u8* buffer, u32 size, u32 maxbufsize, u32 createsize, char *display_filepath)
{
	Result ret=0;
	u32 filesize=0;

	ret = archive_getfilesize(inarchive, inpath, &filesize);
	if(ret!=0)return ret;

	if(size==0 || size>filesize)
	{
		size = filesize;
	}

	if(size>maxbufsize)
	{
		log_printf(LOGTAR_ALL, "Size is too large.\n");
		ret = -1;
		return ret;
	}

	log_printf(LOGTAR_ALL, "Reading %s...\n", display_filepath);

	ret = archive_readfile(inarchive, inpath, buffer, size);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to read file: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	log_printf(LOGTAR_ALL, "Writing %s...\n", display_filepath);

	ret = archive_writefile(outarchive, outpath, buffer, size, createsize);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to write file: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	return ret;
}

