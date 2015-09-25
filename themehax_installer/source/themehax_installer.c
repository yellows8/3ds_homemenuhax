#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <3ds.h>

#include "archive.h"

u8 *filebuffer;
u32 filebuffer_maxsize = 0x400000;

char regionids_table[7][4] = {//http://3dbrew.org/wiki/Nandrw/sys/SecureInfo_A
"JPN",
"USA",
"EUR",
"JPN", //"AUS"
"CHN",
"KOR",
"TWN"
};

u32 NVer_tidlow_regionarray[7] = {
0x00016202, //JPN
0x00016302, //USA
0x00016102, //EUR
0x00016202, //"AUS"
0x00016402, //CHN
0x00016502, //KOR
0x00016602, //TWN
};

u32 CVer_tidlow_regionarray[7] = {
0x00017202, //JPN
0x00017302, //USA
0x00017102, //EUR
0x00017202, //"AUS"
0x00017402, //CHN
0x00017502, //KOR
0x00017602 //TWN
};

s32 locatepayload_data(u32 *payloadbuf, u32 payloadbufsize, u32 *out);
s32 patchPayload(u32 *menuropbin, u32 targetProcessIndex, u32 new3ds_flag);

Result enablethemecache(u32 type)
{	
	Result ret=0;
	u32 filesize = 0;

	printf("Reading SaveData.dat...\n");

	ret = archive_getfilesize(HomeMenu_Extdata, "/SaveData.dat", &filesize);
	if(ret!=0)
	{
		printf("Failed to get filesize for extdata SaveData.dat: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(filesize > filebuffer_maxsize)
	{
		printf("Extdata SaveData.dat filesize is too large: 0x%08x\n", (unsigned int)filesize);
		return ret;
	}

	ret = archive_readfile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize);
	if(ret!=0)
	{
		printf("Failed to read file: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(ret==0)
	{
		if(filebuffer[0x141b]==0 && filebuffer[0x13b8]!=0 && filebuffer[0x13bc]==0 && filebuffer[0x13bd]==type)
		{
			ret = 0;
			printf("SaveData.dat is already set for using the theme cache with a regular theme.\n");
			return ret;
		}
	}

	if(ret==0)
	{
		filebuffer[0x141b]=0;//Disable theme shuffle.
		memset(&filebuffer[0x13b8], 0, 8);//Clear the regular-theme structure.
		filebuffer[0x13bd]=type;//theme-type
		filebuffer[0x13b8] = 0xff;//theme-index

		printf("Writing updated SaveData.dat...\n");

		ret = archive_writefile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize);
		if(ret!=0)
		{
			printf("Failed to write file: 0x%08x\n", (unsigned int)ret);
		}
	}

	return ret;
}

Result menu_enablethemecache_persistent()
{
	return enablethemecache(3);
}

int sd2themecache(char *body_filepath)
{
	Result ret=0;
	u32 body_size=0, bgm_size=0;
	u32 thememanage[0x20>>2];
	char filepath[256];
	char bgm_filepath[256];

	memset(thememanage, 0, 0x20);

	ret = archive_getfilesize(SDArchive, body_filepath, &body_size);
	if(ret!=0)
	{
		printf("Failed to stat the body-filepath: %s\n", body_filepath);
		printf("Note that only USA/EUR/JPN builds are included with the release archive. If that's not an issue for your system, verify that you have a themehax build for your system on SD card: make sure that the release archive you're using actually includes builds for your system-version.\n");
		return ret;
	}
	else
	{
		printf("Using body-filepath: %s\n", body_filepath);
	}

	memset(bgm_filepath, 0, 256);
	strncpy(bgm_filepath, "BgmCache.bin", 255);

	ret = archive_getfilesize(SDArchive, bgm_filepath, &bgm_size);
	if(ret!=0)
	{
		memset(bgm_filepath, 0, 256);
		strncpy(bgm_filepath, "bgm.bcstm", 255);

		ret = archive_getfilesize(SDArchive, bgm_filepath, &bgm_size);
		if(ret!=0)
		{
			printf("Failed to stat BgmCache.bin and bgm.bcstm on SD, copying for the bgm-data will be skipped.\n");

			memset(bgm_filepath, 0, 256);
		}
		else
		{
			printf("Using bgm-filepath bgm.bcstm.\n");
		}
	}
	else
	{
		printf("Using bgm-filepath BgmCache.bin.\n");
	}

	memset(filepath, 0, 256);
	strncpy(filepath, "ThemeManage.bin", 255);

	ret = archive_copyfile(SDArchive, Theme_Extdata, filepath, "/ThemeManage.bin", filebuffer, 0x800, filebuffer_maxsize, "ThemeManage.bin");

	if(ret==0)
	{
		printf("Successfully finished copying ThemeManage.bin.\n");

		memcpy(thememanage, filebuffer, 0x20);
	}
	else
	{
		printf("Failed to copy ThemeManage.bin, generating one then trying again...\n");

		memset(thememanage, 0, 0x20);
		thememanage[0x0>>2] = 1;
		thememanage[0x8>>2] = body_size;
		thememanage[0xC>>2] = bgm_size;
		thememanage[0x10>>2] = 0xff;
		thememanage[0x14>>2] = 1;
		thememanage[0x18>>2] = 0xff;
		thememanage[0x1c>>2] = 0x200;

		memset(filebuffer, 0, 0x800);
		memcpy(filebuffer, thememanage, 0x20);
		ret = archive_writefile(Theme_Extdata, "/ThemeManage.bin", filebuffer, 0x800);

		if(ret!=0)
		{
			printf("Failed to write ThemeManage.bin to extdata, aborting.\n");
			return 0;
		}
	}

	if(body_filepath[0])
	{
		if(thememanage[0x8>>2] == 0)
		{
			printf("Skipping copying of body-data since the size field is zero.\n");
		}
		else
		{
			ret = archive_copyfile(SDArchive, Theme_Extdata, body_filepath, "/BodyCache.bin", filebuffer, thememanage[0x8>>2], 0x150000, "body-data");

			if(ret==0)
			{
				printf("Successfully finished copying body-data.\n");
			}
			else
			{
				return ret;
			}
		}
	}

	if(bgm_filepath[0])
	{
		if(thememanage[0xC>>2] == 0)
		{
			printf("Skipping copying of bgm-data since the size field is zero.\n");
		}
		else
		{
			ret = archive_copyfile(SDArchive, Theme_Extdata, bgm_filepath, "/BgmCache.bin", filebuffer, thememanage[0xC>>2], 0x337000, "bgm-data");

			if(ret==0)
			{
				printf("Successfully finished copying bgm-data.\n");
			}
			else
			{
				return ret;
			}
		}
	}

	return 0;
}

Result http_getactual_payloadurl(char *requrl, char *outurl, u32 outurl_maxsize)
{
	Result ret=0;
	httpcContext context;

	ret = httpcOpenContext(&context, requrl, 0);
	if(ret!=0)return ret;

	ret = httpcAddRequestHeaderField(&context, "User-Agent", "themehax_installer/v1.1");
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcBeginRequest(&context);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcGetResponseHeader(&context, "Location", outurl, outurl_maxsize);

	httpcCloseContext(&context);

	return 0;
}

Result http_download_payload(char *url)
{
	Result ret=0;
	u32 statuscode=0;
	u32 contentsize=0;
	httpcContext context;

	ret = httpcOpenContext(&context, url, 0);
	if(ret!=0)return ret;

	ret = httpcAddRequestHeaderField(&context, "User-Agent", "themehax_installer/v1.0");
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcBeginRequest(&context);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcGetResponseStatusCode(&context, &statuscode, 0);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	if(statuscode!=200)
	{
		printf("Error: server returned HTTP statuscode %u.\n", (unsigned int)statuscode);
		httpcCloseContext(&context);
		return -2;
	}

	ret=httpcGetDownloadSizeState(&context, NULL, &contentsize);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	if(contentsize==0 || contentsize>0xa000)
	{
		printf("Invalid HTTP content-size: 0x%08x.\n", (unsigned int)contentsize);
		ret = -3;
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcDownloadData(&context, filebuffer, contentsize, NULL);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	httpcCloseContext(&context);

	return 0;
}

Result read_versionbin(FS_archive archive, FS_path fileLowPath, u8 *versionbin)
{
	Result ret = 0;
	Handle filehandle = 0;

	ret = FSUSER_OpenFileDirectly(NULL, &filehandle, archive, fileLowPath, FS_OPEN_READ, 0x0);
	if(ret!=0)
	{
		printf("Failed to open the RomFS image for *Ver: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = romfsInitFromFile(filehandle, 0x0);
	if(ret!=0)
	{
		printf("Failed to mount the RomFS image for *Ver: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = archive_readfile(SDArchive, "romfs:/version.bin", versionbin, 0x8);
	romfsExit();

	if(ret!=0)
	{
		printf("Failed to read the *Ver version.bin: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	return 0;
}

Result install_themehax()
{
	Result ret = 0;
	u8 region=0;
	u8 new3dsflag = 0;
	u16 menuversion = 0;
	u32 payloadinfo[4];
	char body_filepath[256];
	u32 archive_lowpath_data[0x10>>2];//+0 = programID-low, +4 = programID-high, +8 = u8 mediatype.
	u32 file_lowpath_data[0x14>>2];

	FS_archive archive;
	FS_path fileLowPath;

	u8 nver_versionbin[0x8];
	u8 cver_versionbin[0x8];

	char payloadurl[0x80];

	memset(body_filepath, 0, sizeof(body_filepath));
	memset(payloadinfo, 0, sizeof(payloadinfo));

	memset(archive_lowpath_data, 0, sizeof(file_lowpath_data));
	memset(file_lowpath_data, 0, sizeof(file_lowpath_data));

	memset(nver_versionbin, 0, sizeof(nver_versionbin));
	memset(cver_versionbin, 0, sizeof(cver_versionbin));

	memset(payloadurl, 0, sizeof(payloadurl));

	archive.id = 0x2345678a;
	archive.lowPath.type = PATH_BINARY;
	archive.lowPath.size = 0x10;
	archive.lowPath.data = (u8*)archive_lowpath_data;

	fileLowPath.type = PATH_BINARY;
	fileLowPath.size = 0x14;
	fileLowPath.data = (u8*)file_lowpath_data;

	archive_lowpath_data[1] = 0x000400DB;

	printf("Getting system-version/system-info etc...\n");

	ret = initCfgu();
	if(ret!=0)
	{
		printf("Failed to init cfgu: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}
	ret = CFGU_SecureInfoGetRegion(&region);
	if(ret!=0)
	{
		printf("Failed to get region from cfgu: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}
	if(region>=7)
	{
		printf("Region value from cfgu is invalid: 0x%02x.\n", (unsigned int)region);
		ret = -9;
		return ret;
	}
	exitCfgu();

	APT_CheckNew3DS(NULL, &new3dsflag);

	aptOpenSession();
	ret = APT_GetAppletProgramInfo(NULL, APPID_HOMEMENU, 0x11, &menuversion);
	aptCloseSession();

	if(ret!=0)
	{
		printf("Failed to get Home Menu title-version: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	snprintf(body_filepath, sizeof(body_filepath)-1, "themepayload/menuhax_%s%u_%s.lz", regionids_table[region], menuversion, new3dsflag?"new3ds":"old3ds");

	archive_lowpath_data[0] = NVer_tidlow_regionarray[region];
	ret = read_versionbin(archive, fileLowPath, nver_versionbin);

	if(ret!=0)
	{
		printf("Failed to read the NVer version.bin: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	archive_lowpath_data[0] = CVer_tidlow_regionarray[region];
	ret = read_versionbin(archive, fileLowPath, cver_versionbin);

	if(ret!=0)
	{
		printf("Failed to read the CVer version.bin: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = chdir("sdmc:/3ds/themehax_installer/");//Without this, the curdir would be left at "romfs:/"(this is also needed when the curdir wasn't the one needed here to begin with).
	if(ret!=0)
	{
		printf("Failed to switch the current-working directory to 'sdmc:/3ds/themehax_installer/', that directory probably doesn't exist.\n");
		return ret;
	}

	snprintf(payloadurl, sizeof(payloadurl)-1, "http://smea.mtheall.com/get_payload.php?version=%s-%d-%d-%d-%d-%s", new3dsflag?"NEW":"OLD", cver_versionbin[2], cver_versionbin[1], cver_versionbin[0], nver_versionbin[2], regionids_table[region]);

	printf("Detected system-version: %s %d.%d.%d-%d %s\n", new3dsflag?"New3DS":"Old3DS", cver_versionbin[2], cver_versionbin[1], cver_versionbin[0], nver_versionbin[2], regionids_table[region]);

	printf("Requesting the actual payload URL with HTTP...\n");
	ret = http_getactual_payloadurl(payloadurl, payloadurl, sizeof(payloadurl));
	if(ret!=0)
	{
		printf("Failed to request the actual payload URL: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	memset(filebuffer, 0, 0xa000);
	printf("Downloading the actual payload with HTTP...\n");
	ret = http_download_payload(payloadurl);
	if(ret!=0)
	{
		printf("Failed to download the actual payload with HTTP: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	printf("Loading info from the hblauncher otherapp payload...\n");
	ret = locatepayload_data((u32*)filebuffer, 0xa000, payloadinfo);
	if(ret!=0)
	{
		printf("Failed to parse the payload: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	printf("Patching the menuropbin...\n");
	ret = patchPayload((u32*)&filebuffer[payloadinfo[0]], 0x1, (u32)new3dsflag);
	if(ret!=0)
	{
		printf("Patching failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	printf("Writing the menuropbin to SD...\n");
	unlink("sdmc:/menuhax_ropbinpayload.bin");
	ret = archive_writefile(SDArchive, "/menuhax_ropbinpayload.bin", &filebuffer[payloadinfo[0]], payloadinfo[1]);
	if(ret!=0)
	{
		printf("Failed to write the menurop to the SD file: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	memset(filebuffer, 0, 0xa000);

	printf("Enabling persistent themecache...\n");
	ret = menu_enablethemecache_persistent();
	if(ret!=0)return ret;

	printf("Installing to the SD theme-cache...\n");
	ret = sd2themecache(body_filepath);
	if(ret!=0)return ret;

	return 0;
}

int main(int argc, char **argv)
{
	Result ret = 0;

	// Initialize services
	gfxInitDefault();

	consoleInit(GFX_BOTTOM, NULL);

	printf("themehax_installer\n");

	ret = httpcInit();
	if(ret!=0)
	{
		printf("Failed to initialize HTTPC: 0x%08x.\n", (unsigned int)ret);
	}

	if(ret==0)
	{
		filebuffer = (u8*)malloc(0x400000);
		if(filebuffer==NULL)
		{
			printf("Failed to allocate memory.\n");
			ret = -1;
		}
		else
		{
			memset(filebuffer, 0, filebuffer_maxsize);
		}
	}

	if(ret>=0)
	{
		printf("Opening extdata archives...\n");

		ret = open_extdata();
		if(ret==0)
		{
			printf("Finished opening extdata.\n");

			consoleClear();

			printf("This will install Home Menu themehax to the SD card, for booting hblauncher. Are you sure you want to continue? A = yes, B = no.\n");
			while(1)
			{
				gspWaitForVBlank();
				hidScanInput();

				u32 kDown = hidKeysDown();
				if(kDown & KEY_A)
				{
					ret = 1;
					break;
				}
				if(kDown & KEY_B)
				{
					ret = 2;
					break;
				}
			}

			if(ret==1)
			{
				ret = install_themehax();
				close_extdata();

				if(ret==0)
				{
					printf("Install finished successfully.\n");
				}
				else
				{
					printf("Install failed: 0x%08x.\n", (unsigned int)ret);
				}
			}
		}
	}

	free(filebuffer);

	httpcExit();

	printf("Press the START button to exit.\n");
	// Main loop
	while (aptMainLoop())
	{
		gspWaitForVBlank();
		hidScanInput();

		u32 kDown = hidKeysDown();
		if (kDown & KEY_START)
			break; // break in order to return to hbmenu
	}

	// Exit services
	gfxExit();
	return 0;
}

