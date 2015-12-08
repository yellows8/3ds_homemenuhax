#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <3ds.h>

#include "archive.h"

#include "modules_common.h"

Result shufflehax_install(char *menuhax_basefn);
Result shufflehax_delete();

void register_module_shufflehax()
{
	register_module(MODULE_MAKE_CVER(0, 0, 0), shufflehax_install, shufflehax_delete);
}

Result shufflehax_install(char *menuhax_basefn)
{
	Result ret=0;

	char payload_filepath[256];

	memset(payload_filepath, 0, sizeof(payload_filepath));

	snprintf(payload_filepath, sizeof(payload_filepath)-1, "sdmc:/3ds/menuhax_manager/finaloutput/shufflepayload/%s.lz", menuhax_basefn);

	printf("Installing shufflehax...\n");

	printf("Enabling shuffle themecache...\n");
	ret = enablethemecache(3, 1, 1);
	if(ret!=0)return ret;

	printf("Installing to the SD theme-cache...\n");
	ret = sd2themecache(payload_filepath, "sdmc:/3ds/menuhax_manager/bgm_bundledmenuhax.bcstm", 0);
	if(ret!=0)return ret;

	printf("Initializing the seperate menuhax theme-data files...\n");
	ret = sd2themecache("sdmc:/3ds/menuhax_manager/blanktheme.lz", NULL, 1);
	if(ret!=0)return ret;

	return 0;
}

Result shufflehax_delete()
{
	Result ret=0;
	unsigned int i;
	u8 *tmpbuf;

	char str[256];

	printf("Deleting shufflehax...\n");

	printf("Disabling theme-usage via SaveData.dat...\n");
	ret = disablethemecache();
	if(ret!=0)return ret;

	memset(filebuffer, 0, filebuffer_maxsize);

	tmpbuf = malloc(0xd20000);
	if(tmpbuf==NULL)
	{
		printf("Failed to allocate memory for the shuffle-BodyCache clearing buffer.");
		return 1;
	}
	memset(tmpbuf, 0, 0xd20000);

	printf("Clearing the theme-cache extdata now...\n");

	printf("Clearing the ThemeManage...\n");
	ret = archive_writefile(Theme_Extdata, "/ThemeManage.bin", filebuffer, 0x800, 0x800);
	if(ret!=0)
	{
		printf("Failed to clear the ThemeManage: 0x%08x.\n", (unsigned int)ret);
		free(tmpbuf);
		return ret;
	}

	printf("Clearing the shuffle BodyCache...\n");
	ret = archive_writefile(Theme_Extdata, "/BodyCache_rd.bin", tmpbuf, 0xd20000, 0xd20000);
	free(tmpbuf);
	if(ret!=0)
	{
		printf("Failed to clear the shuffle BodyCache: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	for(i=0; i<10; i++)
	{
		memset(str, 0, sizeof(str));
		snprintf(str, sizeof(str)-1, "/BgmCache_%02d.bin", i);

		printf("Clearing shuffle BgmCache_%02d...\n", i);
		ret = archive_writefile(Theme_Extdata, str, filebuffer, 0x337000, 0x337000);
		if(ret!=0)
		{
			printf("Failed to clear shuffle BgmCache_%02d: 0x%08x.\n", i, (unsigned int)ret);
			return ret;
		}
	}

	return 0;
}

