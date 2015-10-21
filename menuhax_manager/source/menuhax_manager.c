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

int sd2themecache(char *body_filepath, char *bgm_filepath, u32 install_type)
{
	Result ret=0;
	u32 body_size=0, bgm_size=0;
	u32 thememanage[0x20>>2];

	memset(thememanage, 0, sizeof(thememanage));

	ret = archive_getfilesize(SDArchive, body_filepath, &body_size);
	if(ret!=0)
	{
		printf("Failed to stat the body-filepath: %s\n", body_filepath);
		if(install_type==0)
		{
			printf("Verify that you have a menuhax build for your system on SD card: make sure that the release archive you're using actually includes builds for your system-version.\n");
			printf("Also verify that the following directory containing .lz files actually exists on your SD card: '/3ds/menuhax_manager/themepayload/'.\n");
		}
		return ret;
	}
	else
	{
		printf("Using body-filepath: %s\n", body_filepath);
	}

	ret = archive_getfilesize(SDArchive, bgm_filepath, &bgm_size);
	if(ret!=0)
	{
		ret = archive_getfilesize(SDArchive, bgm_filepath, &bgm_size);
		printf("Skipping BGM copying since stat() failed for it.\n");

		bgm_size = 0;
	}
	else
	{
		printf("Using bgm-filepath: %s\n", bgm_filepath);
	}

	printf("Generating a ThemeManage.bin + writing it to extdata...\n");

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
	ret = archive_writefile(Theme_Extdata, install_type==0 ? "/ThemeManage.bin" : "/yhemeManage.bin", filebuffer, 0x800);

	if(ret!=0)
	{
		printf("Failed to write ThemeManage.bin to extdata, aborting.\n");
		return ret;
	}

	if(body_size==0)
	{
		printf("Skipping copying of body-data since the size field is zero.\n");
	}
	else
	{
		ret = archive_copyfile(SDArchive, Theme_Extdata, body_filepath, install_type==0 ? "/BodyCache.bin" : "/yodyCache.bin", filebuffer, thememanage[0x8>>2], 0x150000, "body-data");

		if(ret==0)
		{
			printf("Successfully finished copying body-data.\n");
		}
		else
		{
			return ret;
		}
	}

	if(bgm_size==0)
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

	return 0;
}

Result http_getactual_payloadurl(char *requrl, char *outurl, u32 outurl_maxsize)
{
	Result ret=0;
	httpcContext context;

	ret = httpcOpenContext(&context, requrl, 0);
	if(ret!=0)return ret;

	ret = httpcAddRequestHeaderField(&context, "User-Agent", "menuhax_manager/"VERSION);
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

Result http_download_payload(char *url, u32 *payloadsize)
{
	Result ret=0;
	u32 statuscode=0;
	u32 contentsize=0;
	httpcContext context;

	ret = httpcOpenContext(&context, url, 0);
	if(ret!=0)return ret;

	ret = httpcAddRequestHeaderField(&context, "User-Agent", "menuhax_manager/"VERSION);
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

	if(contentsize==0 || contentsize>filebuffer_maxsize-0x8000)
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

	*payloadsize = contentsize;

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

Result install_themehax(char *ropbin_filepath)
{
	Result ret = 0;
	u8 region=0;
	u8 new3dsflag = 0;
	u64 menu_programid = 0;
	TitleList menu_title_entry;
	u32 payloadinfo[4];
	char menuhax_basefn[256];
	char body_filepath[256];
	u32 archive_lowpath_data[0x10>>2];//+0 = programID-low, +4 = programID-high, +8 = u8 mediatype.
	u32 file_lowpath_data[0x14>>2];

	FS_archive archive;
	FS_path fileLowPath;

	u8 nver_versionbin[0x8];
	u8 cver_versionbin[0x8];

	u32 payloadsize = 0, payloadsize_aligned = 0;

	char payloadurl[0x80];

	memset(menuhax_basefn, 0, sizeof(menuhax_basefn));
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
	ret = APT_GetAppletInfo(NULL, APPID_HOMEMENU, &menu_programid, NULL, NULL, NULL, NULL);
	aptCloseSession();

	if(ret!=0)
	{
		printf("Failed to get the Home Menu programID: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	printf("Using Home Menu programID: 0x%016llx.\n", menu_programid);

	ret = AM_ListTitles(0, 1, &menu_programid, &menu_title_entry);
	if(ret!=0)
	{
		printf("Failed to get the Home Menu title-version: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	snprintf(menuhax_basefn, sizeof(menuhax_basefn)-1, "menuhax_%s%u_%s", regionids_table[region], menu_title_entry.titleVersion, new3dsflag?"new3ds":"old3ds");
	snprintf(body_filepath, sizeof(body_filepath)-1, "sdmc:/3ds/menuhax_manager/themepayload/%s.lz", menuhax_basefn);
	snprintf(ropbin_filepath, 255, "sdmc:/ropbinpayload_%s.bin", menuhax_basefn);

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

	snprintf(payloadurl, sizeof(payloadurl)-1, "http://smea.mtheall.com/get_payload.php?version=%s-%d-%d-%d-%d-%s", new3dsflag?"NEW":"OLD", cver_versionbin[2], cver_versionbin[1], cver_versionbin[0], nver_versionbin[2], regionids_table[region]);

	printf("Detected system-version: %s %d.%d.%d-%d %s\n", new3dsflag?"New3DS":"Old3DS", cver_versionbin[2], cver_versionbin[1], cver_versionbin[0], nver_versionbin[2], regionids_table[region]);

	memset(filebuffer, 0, filebuffer_maxsize);

	printf("Checking for the otherapp payload on SD...\n");
	ret = archive_getfilesize(SDArchive, "sdmc:/menuhaxmanager_otherapp_payload.bin", &payloadsize);
	if(ret==0)
	{
		if(payloadsize==0 || payloadsize>filebuffer_maxsize-0x8000)
		{
			printf("Invalid SD payload size: 0x%08x.\n", (unsigned int)payloadsize);
			ret = -3;
		}
	}
	if(ret==0)ret = archive_readfile(SDArchive, "sdmc:/menuhaxmanager_otherapp_payload.bin", filebuffer, payloadsize);

	if(ret==0)
	{
		printf("The otherapp payload for this installer already exists on SD, that will be used instead of downloading the payload via HTTP.\n");
	}
	else
	{
		ret = httpcInit();
		if(ret!=0)
		{
			printf("Failed to initialize HTTPC: 0x%08x.\n", (unsigned int)ret);
			if(ret==0xd8e06406)
			{
				printf("The HTTPC service is inaccessible. With the hblauncher-payload this may happen if the process this app is running under doesn't have access to that service. Please try rebooting the system, boot hblauncher-payload, then directly launch the app.\n");
			}

			return ret;
		}

		printf("Requesting the actual payload URL with HTTP...\n");
		ret = http_getactual_payloadurl(payloadurl, payloadurl, sizeof(payloadurl));
		if(ret!=0)
		{
			printf("Failed to request the actual payload URL: 0x%08x.\n", (unsigned int)ret);
			printf("If the server isn't down, and the HTTP request was actually done, this may mean your system-version or region isn't supported by the hblauncher-payload currently.\n");
			httpcExit();
			return ret;
		}

		printf("Downloading the actual payload with HTTP...\n");
		ret = http_download_payload(payloadurl, &payloadsize);
		httpcExit();
		if(ret!=0)
		{
			printf("Failed to download the actual payload with HTTP: 0x%08x.\n", (unsigned int)ret);
			printf("If the server isn't down, and the HTTP request was actually done, this may mean your system-version or region isn't supported by the hblauncher-payload currently.\n");
			return ret;
		}
	}

	payloadsize_aligned = (payloadsize + 0xfff) & ~0xfff;

	printf("Loading info from the hblauncher otherapp payload...\n");
	ret = locatepayload_data((u32*)filebuffer, payloadsize, payloadinfo);
	if(ret!=0)
	{
		printf("Failed to parse the payload: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	memcpy(&filebuffer[payloadsize_aligned], &filebuffer[payloadinfo[0]], payloadinfo[1]);
	memcpy(&filebuffer[payloadsize_aligned+0x8000], &filebuffer[payloadsize_aligned], payloadinfo[1]);

	printf("Patching the menuropbin...\n");
	ret = patchPayload((u32*)&filebuffer[payloadsize_aligned], 0x1, (u32)new3dsflag);
	if(ret!=0)
	{
		printf("Patching failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	printf("Writing the menuropbin to SD, to the following path: %s.\n", ropbin_filepath);
	unlink("sdmc:/menuhax_ropbinpayload.bin");//Delete the ropbin with the filepath used by the <=v1.2 menuhax.
	unlink(ropbin_filepath);
	ret = archive_writefile(SDArchive, ropbin_filepath, &filebuffer[payloadsize_aligned], 0x10000);
	if(ret!=0)
	{
		printf("Failed to write the menurop to the SD file: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	memset(filebuffer, 0, filebuffer_maxsize);

	printf("Enabling persistent themecache...\n");
	ret = menu_enablethemecache_persistent();
	if(ret!=0)return ret;

	printf("Installing to the SD theme-cache...\n");
	ret = sd2themecache(body_filepath, "sdmc:/3ds/menuhax_manager/bgm_bundledmenuhax.bcstm", 0);
	if(ret!=0)return ret;

	return 0;
}

void print_padbuttons(u32 val)
{
	u32 i;

	if(val==0)
	{
		printf("<no-buttons>");
		return;
	}

	for(i=0; i<12; i++)
	{
		if((val & (1<<i))==0)continue;

		switch(1<<i)
		{
			case KEY_A:
				printf("A ");
			break;

			case KEY_B:
				printf("B ");
			break;

			case KEY_SELECT:
				printf("SELECT ");
			break;

			case KEY_START:
				printf("START ");
			break;

			case KEY_DRIGHT:
				printf("D-PAD RIGHT ");
			break;

			case KEY_DLEFT:
				printf("D-PAD LEFT ");
			break;

			case KEY_DUP:
				printf("D-PAD UP ");
			break;

			case KEY_DDOWN:
				printf("D-PAD DOWN ");
			break;

			case KEY_R:
				printf("R ");
			break;

			case KEY_L:
				printf("L ");
			break;

			case KEY_X:
				printf("X ");
			break;

			case KEY_Y:
				printf("Y ");
			break;
		}
	}
}

Result setup_sdcfg()
{
	Result ret=0;
	u32 kDown;

	u32 sdcfg[0x10>>2];//Last u32 is reserved atm.

	printf("Configuring the padcfg file on SD...\n");

	memset(sdcfg, 0, sizeof(sdcfg));

	ret = archive_readfile(SDArchive, "sdmc:/menuhax_padcfg.bin", (u8*)sdcfg, sizeof(sdcfg));
	if(ret==0)
	{
		printf("The cfg file already exists on SD.\n");
		printf("Current cfg:\n");
		printf("Type 0x%x: ", (unsigned int)sdcfg[0]);

		if(sdcfg[0]==0x1)
		{
			printf("Only trigger the haxx when the PAD state matches the specified value(specified button(s) must be pressed).\n");
			printf("Currently selected PAD value: 0x%x ", (unsigned int)sdcfg[1]);
			print_padbuttons(sdcfg[1]);
			printf("\n");
		}
		else if(sdcfg[0]==0x2)
		{
			printf("Only trigger the haxx when the PAD state doesn't match the specified value.\n");
			printf("Currently selected PAD value: 0x%x ", (unsigned int)sdcfg[2]);
			print_padbuttons(sdcfg[2]);
			printf("\n");
		}
		else
		{
			printf("None, the default PAD trigger is used.\n");
		}
	}
	else
	{
		printf("The cfg file currently doesn't exist on SD.\n");
	}

	printf("Select a type by pressing a button: A = type1, B = type2, Y = type0. Or, press START to abort configuration(no file data will be written). You can also press X to delete the config file(same end result on the menuhax as type0 basically).\n");
	printf("Type1: Only trigger the haxx when the PAD state matches the specified value(specified button(s) must be pressed).\n");
	printf("Type2: Only trigger the haxx when the PAD state doesn't match the specified value.\n");
	printf("Type0: Default PAD config is used.\n");

	memset(sdcfg, 0, sizeof(sdcfg));

	while(1)
	{
		gspWaitForVBlank();
		hidScanInput();
		kDown = hidKeysDown();

		if(kDown & KEY_A)
		{
			sdcfg[0] = 0x1;
			break;
		}

		if(kDown & KEY_B)
		{
			sdcfg[0] = 0x2;
			break;
		}

		if(kDown & KEY_Y)
		{
			sdcfg[0] = 0x0;
			break;
		}

		if(kDown & KEY_START)
		{
			return 0;
		}

		if(kDown & KEY_X)
		{
			unlink("sdmc:/menuhax_padcfg.bin");
			return 0;
		}
	}

	if(sdcfg[0])
	{
		printf("Press the button(s) you want to select for the PAD state value as described above(no New3DS-only buttons). If you want to select <no-buttons>, don't press any buttons. Then, while the buttons are being pressed, if any, touch the bottom-screen.\n");

		while(1)
		{
			gspWaitForVBlank();
			hidScanInput();
			kDown = hidKeysHeld();

			if(kDown & KEY_TOUCH)
			{
				sdcfg[sdcfg[0]] = kDown & 0xfff;
				break;
			}
		}

		printf("Selected PAD value: 0x%x ", (unsigned int)sdcfg[sdcfg[0]]);
		print_padbuttons(sdcfg[sdcfg[0]]);
		printf("\n");
	}

	ret = archive_writefile(SDArchive, "sdmc:/menuhax_padcfg.bin", (u8*)sdcfg, sizeof(sdcfg));
	if(ret!=0)printf("Failed to write the cfg file: 0x%x.\n", (unsigned int)ret);
	if(ret==0)printf("Config file successfully written.\n");

	return ret;
}

void displaymessage_waitbutton()
{
	printf("\nPress the A button to continue.\n");
	while(1)
	{
		gspWaitForVBlank();
		hidScanInput();
		if(hidKeysDown() & KEY_A)break;
	}
}

int main(int argc, char **argv)
{
	Result ret = 0;
	int redraw = 0;

	char ropbin_filepath[256];

	// Initialize services
	gfxInitDefault();

	consoleInit(GFX_BOTTOM, NULL);

	printf("menuhax_manager %s by yellows8.\n", VERSION);

	memset(ropbin_filepath, 0, sizeof(ropbin_filepath));

	ret = amInit();
	if(ret!=0)
	{
		printf("Failed to initialize AM: 0x%08x.\n", (unsigned int)ret);
		if(ret==0xd8e06406)
		{
			printf("The AM service is inaccessible. With the hblauncher-payload this should never happen.\n");
		}
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
			printf("Finished opening extdata.\n\n");

			redraw = 1;

			while(1)
			{
				if(redraw)
				{
					redraw = 0;

					consoleClear();
					printf("This can install Home Menu haxx to the SD card, for booting hblauncher. Select an option by pressing a button:\nA = install\nY = configure/check haxx trigger button(s), which can override the default setting.\nX = install custom theme for when Home Menu is using the seperate extdata files for this hax.\nB = exit\n");
				}

				gspWaitForVBlank();
				hidScanInput();

				u32 kDown = hidKeysDown();

				if(kDown & KEY_A)
				{
					consoleClear();
					ret = install_themehax(ropbin_filepath);

					if(ret==0)
					{
						printf("Install finished successfully. The following is the filepath which was just now written, you can delete any SD 'ropbinpayload_menuhax_*' file(s) which don't match the following exact filepath: '%s'. Doing so is completely optional. This only applies when menuhax >v1.2 was already installed where it was switched to a different system-version.\n", ropbin_filepath);

						displaymessage_waitbutton();

						redraw = 1;
					}
					else
					{
						printf("Install failed: 0x%08x.\n", (unsigned int)ret);

						break;
					}
				}

				if(kDown & KEY_Y)
				{
					consoleClear();
					ret = setup_sdcfg();

					if(ret==0)
					{
						printf("Configuration finished successfully.\n");
						displaymessage_waitbutton();

						redraw = 1;
					}
					else
					{
						printf("Configuration failed: 0x%08x.\n", (unsigned int)ret);

						break;
					}
				}

				if(kDown & KEY_X)
				{
					consoleClear();
					printf("Enabling persistent themecache...\n");
					ret = menu_enablethemecache_persistent();
					if(ret==0)
					{
						printf("Installing custom-theme...\n");
						ret = sd2themecache("sdmc:/3ds/menuhax_manager/body_LZ.bin", "sdmc:/3ds/menuhax_manager/bgm.bcstm", 1);
					}

					if(ret==0)
					{
						printf("Custom theme installation finished successfully.\n");
						displaymessage_waitbutton();

						redraw = 1;
					}
					else
					{
						printf("Custom theme installation failed: 0x%08x. If you haven't already done so, you might need to enter the theme-settings menu under Home Menu, while menuhax is installed.\n", (unsigned int)ret);

						break;
					}
				}

				if(kDown & KEY_B)
				{
					break;
				}
			}
		}
	}

	free(filebuffer);

	amExit();

	close_extdata();

	if(ret!=0)printf("An error occured, please report this to here if it persists(or comment on an already existing issue if needed), with an image of your 3DS system with the bottom-screen: https://github.com/yellows8/3ds_homemenuhax/issues\n");

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

