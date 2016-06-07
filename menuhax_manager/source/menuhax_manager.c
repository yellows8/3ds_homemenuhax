#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <errno.h>
#include <3ds.h>

#include <lodepng.h>

#include "archive.h"
#include "menu.h"
#include "log.h"

#include "builtin_rootca_der.h"

#include "modules_common.h"

#include "modules.h"//Built by setup_modules.sh.

u8 *filebuffer;
u32 filebuffer_maxsize = 0x400000;

char regionids_table[7][4] = {//https://3dbrew.org/wiki/Nandrw/sys/SecureInfo_A
"JPN",
"USA",
"EUR",
"JPN", //"AUS"
"CHN",
"KOR",
"TWN"
};

#define MAX_MODULES 16
module_entry modules_list[MAX_MODULES];

typedef struct {
	u32 version;//Must be MENUHAXCFG_CURVERSION, the menuhax ROP will ignore the cfg otherwise.
	u32 type;
	u32 padvalues[2];
	u32 exec_type;//This will be reset to 0x0 by the menuhax ROP once done, if non-zero. 0x1: Force-enable the main menuhax ROP regardless of PADCHECK. 0x2: Force-disable the main menuhax ROP regardless of PADCHECK.
	u64 delay_value;//Nano-seconds value to use with svcSleepThread() in the menuhax ROP right before jumping to the *hax payload homemenu ROP.
	u32 flags;
	u32 thread_padvalue;//When non-zero, this is the PAD-value checked by the created menuhax thread during a normal homemenu boot, which triggers launching the *hax payload.
} PACKED menuhax_cfg;

#define MENUHAXCFG_CURVERSION 0x3//0x3 is used since lower values would collide with the PAD type-values at that same offset in the original format version.
#define MENUHAXCFG_DEFAULT_DELAYVAL 3000000000ULL //3 seconds.
#define MENUHAXCFG_FLAG_THEME (1<<0) //Disable the menuhax_manager theme menus when set.

void menuhaxcfg_create();
bool menuhaxcfg_get_themeflag();
void menuhaxcfg_set_themeflag(bool themeflag);

void register_module(module_entry *module)
{
	int pos;
	module_entry *ent;
	module_entry tmp;

	for(pos=0; pos<MAX_MODULES; pos++)
	{
		ent = &modules_list[pos];
		if(ent->initialized)continue;

		memcpy(&tmp, module, sizeof(module_entry));

		tmp.initialized = 1;
		tmp.index = ent->index;

		memcpy(ent, &tmp, sizeof(module_entry));

		return;
	}
}

Result modules_getcompatible_entry(OS_VersionBin *cver_versionbin, module_entry **module, u32 index)
{
	module_entry *ent;
	u32 pos;
	u32 cver = MODULE_MAKE_CVER(cver_versionbin->mainver, cver_versionbin->minor, cver_versionbin->build);

	*module = NULL;

	if(index>=MAX_MODULES)return -1;

	for(pos=index; pos<MAX_MODULES; pos++)
	{
		ent = &modules_list[pos];
		if(!ent->initialized)continue;

		if(ent->unsupported_cver && cver>=ent->unsupported_cver)
		{
			continue;
		}

		*module = ent;

		return 0;
	}

	return -7;
}

Result modules_findentryname(char *name, module_entry **module)
{
	module_entry *ent;
	u32 pos;

	*module = NULL;

	for(pos=0; pos<MAX_MODULES; pos++)
	{
		ent = &modules_list[pos];
		if(!ent->initialized)continue;

		if(strncmp(ent->name, name, sizeof(ent->name)))continue;

		*module = ent;

		return 0;
	}

	return -7;
}

Result modules_haxdelete()
{
	module_entry *ent;
	int pos;
	Result ret=0;

	for(pos=0; pos<MAX_MODULES; pos++)
	{
		ent = &modules_list[pos];
		if(!ent->initialized)continue;

		if(!ent->manual_name_display)log_printf(LOGTAR_ALL, "Deleting %s...\n", ent->name);

		ret = ent->haxdelete();
		if(ret)return ret;
	}

	return 0;
}

Result enablethemecache(u32 type, u32 shuffle, u32 index)
{	
	Result ret=0;
	u32 filesize = 0;
	u8 *ent;

	if(index>9)index = 9;

	ent = &filebuffer[0x13b8 + (index*0x8)];

	log_printf(LOGTAR_ALL, "Reading SaveData.dat...\n");

	ret = archive_getfilesize(HomeMenu_Extdata, "/SaveData.dat", &filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to get filesize for extdata SaveData.dat: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(filesize > filebuffer_maxsize)
	{
		log_printf(LOGTAR_ALL, "Extdata SaveData.dat filesize is too large: 0x%08x\n", (unsigned int)filesize);
		return ret;
	}

	ret = archive_readfile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to read file: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(ret==0)
	{
		if(filebuffer[0x141b]==shuffle && ent[0x0]!=0 && ent[0x4]==0 && ent[0x5]==type)
		{
			ret = 0;
			log_printf(LOGTAR_ALL, "SaveData.dat is already set for using the theme cache with the intended theme.\n");
			return ret;
		}
	}

	if(ret==0)
	{
		filebuffer[0x141b]=shuffle;//Theme shuffle flag.
		memset(&filebuffer[0x13b8], 0, 11*8);//Clear the theme entry structures.
		ent[0x5]=type;//theme-type
		ent[0x0] = 0xff;//theme-index

		if(index && index < 11)//Home Menu will enter an infinite loop if there isn't at least two theme-shuffle entries.
		{
			memcpy(&ent[0x8*2], ent, 0x8);
		}

		log_printf(LOGTAR_ALL, "Writing updated SaveData.dat...\n");

		ret = archive_writefile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize, 0);
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to write file: 0x%08x\n", (unsigned int)ret);
		}
	}

	return ret;
}

Result menu_enablethemecache_persistent()
{
	return enablethemecache(3, 0, 0);
}

Result disablethemecache()
{
	Result ret=0;
	u32 filesize = 0;

	log_printf(LOGTAR_ALL, "Reading SaveData.dat...\n");

	ret = archive_getfilesize(HomeMenu_Extdata, "/SaveData.dat", &filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to get filesize for extdata SaveData.dat: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(filesize > filebuffer_maxsize)
	{
		log_printf(LOGTAR_ALL, "Extdata SaveData.dat filesize is too large: 0x%08x\n", (unsigned int)filesize);
		return ret;
	}

	ret = archive_readfile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to read file: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(ret==0)
	{
		filebuffer[0x141b]=0;//Disable theme shuffle.
		memset(&filebuffer[0x13b8], 0, 8*11);//Clear the theme structures.

		log_printf(LOGTAR_ALL, "Writing updated SaveData.dat...\n");

		ret = archive_writefile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize, 0);
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to write file: 0x%08x\n", (unsigned int)ret);
		}
	}

	return ret;
}

Result savedatadat_getshufflestatus(u32 *out)
{
	Result ret=0;
	u32 filesize = 0;

	log_printf(LOGTAR_ALL, "Reading SaveData.dat...\n");

	ret = archive_getfilesize(HomeMenu_Extdata, "/SaveData.dat", &filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to get filesize for extdata SaveData.dat: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(filesize > filebuffer_maxsize)
	{
		log_printf(LOGTAR_ALL, "Extdata SaveData.dat filesize is too large: 0x%08x\n", (unsigned int)filesize);
		return ret;
	}

	ret = archive_readfile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to read file: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(ret==0)
	{
		*out = filebuffer[0x141b];//Theme-stuffle enabled flag.
	}

	return ret;
}

Result sd2themecache(char *body_filepath, char *bgm_filepath, u32 install_type)
{
	Result ret=0;
	u32 body_size=0, bgm_size=0;
	u32 *thememanage = (u32*)filebuffer;
	u32 shuffle=0;
	u32 createsize;
	u8 *tmpbuf = NULL;
	u32 tmpbuf_size = 0x150000*4;

	char path[256];

	ret = archive_getfilesize(SDArchive, body_filepath, &body_size);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to get the filesize of the body-filepath(file likely doesn't exist): %s\n", body_filepath);
		if(install_type==0)
		{
			log_printf(LOGTAR_ALL, "The release-archive you're using doesn't include support for your system. Check the menuhax repo README + verify you're using the latest release.\n");
		}
		return ret;
	}
	else
	{
		log_printf(LOGTAR_ALL, "Using body-filepath: %s\n", body_filepath);
	}

	if(body_size==0)
	{
		log_printf(LOGTAR_ALL, "Error: the theme body-data file is empty(filesize is 0-bytes).\n");
		return -1;
	}

	if(bgm_filepath)
	{
		ret = archive_getfilesize(SDArchive, bgm_filepath, &bgm_size);
		if(ret!=0)
		{
			ret = archive_getfilesize(SDArchive, bgm_filepath, &bgm_size);
			log_printf(LOGTAR_ALL, "Skipping BGM copying.\n");

			bgm_size = 0;
		}
		else
		{
			log_printf(LOGTAR_ALL, "Using bgm-filepath: %s\n", bgm_filepath);
		}
	}

	ret = savedatadat_getshufflestatus(&shuffle);
	if(ret)return ret;
	if(shuffle)shuffle = 1;

	log_printf(LOGTAR_ALL, "Generating a ThemeManage.bin + writing it to extdata...\n");

	memset(thememanage, 0, 0x800);

	thememanage[0x0>>2] = 1;
	thememanage[0x10>>2] = 0xff;
	thememanage[0x14>>2] = 1;
	thememanage[0x18>>2] = 0xff;
	thememanage[0x1c>>2] = 0x200;

	if(shuffle==0)
	{
		thememanage[0x8>>2] = body_size;
		thememanage[0xC>>2] = bgm_size;
	}
	else
	{
		thememanage[(0x338>>2) + (shuffle-1)] = body_size;
		thememanage[((0x338+0x28)>>2) + (shuffle-1)] = bgm_size;

		thememanage[(0x338>>2) + (shuffle-1+2)] = body_size;
		thememanage[((0x338+0x28)>>2) + (shuffle-1+2)] = bgm_size;
	}

	ret = archive_writefile(Theme_Extdata, install_type==0 ? "/ThemeManage.bin" : "/yhemeManage.bin", (u8*)thememanage, 0x800, 0x800);

	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to write ThemeManage.bin to extdata, aborting.\n");
		return ret;
	}

	if(body_size > filebuffer_maxsize)
	{
		log_printf(LOGTAR_ALL, "The body-data size is too large.\n");
		return 2;
	}

	memset(path, 0, sizeof(path));
	strncpy(path, install_type==0 ? "/BodyCache.bin" : "/yodyCache.bin", sizeof(path)-1);

	createsize = 0x150000;
	memset(filebuffer, 0, createsize);
	ret = archive_copyfile(SDArchive, Theme_Extdata, body_filepath, path, filebuffer, createsize, createsize, createsize, "body-data");
	if(ret)return ret;

	//When entering the Home Menu theme-settings menu, Home Menu tries to open the regular body-cache file(even when using theme-shuffle). When that fails, it resets all theme-data. This presumably applies to BgmCache too.

	if(shuffle)
	{
		if(body_size > tmpbuf_size || body_size + 0x2A0000 > tmpbuf_size)
		{
			log_printf(LOGTAR_ALL, "The body-data size is too large.\n");
			return 2;
		}

		tmpbuf = malloc(tmpbuf_size);
		if(tmpbuf==NULL)
		{
			log_printf(LOGTAR_ALL, "Failed to allocate memory for tmpbuf.\n");
			return 1;
		}
		memset(tmpbuf, 0, tmpbuf_size);

		memset(path, 0, sizeof(path));
		strncpy(path, install_type==0 ? "/BodyCache_rd.bin" : "/yodyCache_rd.bin", sizeof(path)-1);
		createsize = 0xd20000;

		log_printf(LOGTAR_ALL, "Reading body-data...\n");
		ret = archive_readfile(SDArchive, body_filepath, tmpbuf, body_size);
		if(ret)
		{
			free(tmpbuf);
			return ret;
		}

		memcpy(&tmpbuf[0x2A0000], tmpbuf, body_size);

		log_printf(LOGTAR_ALL, "Writing body-data...\n");
		ret = archive_writefile(Theme_Extdata, path, tmpbuf, 0x2A0000 + body_size, createsize);
		free(tmpbuf);
		if(ret)
		{
			return ret;
		}
	}

	if(ret==0)
	{
		log_printf(LOGTAR_ALL, "Successfully finished copying body-data.\n");
	}
	else
	{
		return ret;
	}

	if(bgm_filepath && bgm_size)
	{
		ret = archive_copyfile(SDArchive, Theme_Extdata, bgm_filepath, "/BgmCache.bin", filebuffer, bgm_size, 0x337000, 0x337000, "bgm-data");

		if(ret==0 && shuffle)
		{
			memset(path, 0, sizeof(path));
			snprintf(path, sizeof(path)-1, "/BgmCache_%02d.bin", (int)(shuffle-1));

			ret = archive_copyfile(SDArchive, Theme_Extdata, bgm_filepath, path, filebuffer, bgm_size, 0x337000, 0x337000, "bgm-data");
		}

		if(ret==0 && shuffle)
		{
			memset(path, 0, sizeof(path));
			snprintf(path, sizeof(path)-1, "/BgmCache_%02d.bin", (int)(shuffle-1+2));

			ret = archive_copyfile(SDArchive, Theme_Extdata, bgm_filepath, path, filebuffer, bgm_size, 0x337000, 0x337000, "bgm-data");
		}

		if(ret==0)
		{
			log_printf(LOGTAR_ALL, "Successfully finished copying bgm-data.\n");
		}
		else
		{
			return ret;
		}
	}

	return 0;
}

Result delete_menuhax()
{
	Result ret=0;
	bool themeflag;

	ret = displaymessage_prompt("Do you want to skip deleting menuhax itself, so that only the menuhax-specific theme-data if any is deleted?", NULL);

	themeflag = menuhaxcfg_get_themeflag();

	if(ret==0)
	{
		log_printf(LOGTAR_ALL, "Skipping menuhax deletion.\n");
	}
	else
	{
		log_printf(LOGTAR_ALL, "Deleting menuhax.\n");

		ret = modules_haxdelete();
		if(ret)return ret;

		unlink("sdmc:/menuhax/menuhax_installedversion");

		log_printf(LOGTAR_ALL, "The menuhax itself has been deleted successfully.\n");

		if(!themeflag)menuhaxcfg_set_themeflag(true);
	}

	if(!themeflag)
	{
		log_printf(LOGTAR_ALL, "Deleting the additional menuhax files under theme-cache extdata now. Errors will be ignored since those don't matter here.\n");

		log_printf(LOGTAR_ALL, "Deleting the menuhax ThemeManage...\n");
		ret = archive_deletefile(Theme_Extdata, "/yhemeManage.bin");
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to delete the menuhax ThemeManage: 0x%08x.\n", (unsigned int)ret);
		}

		log_printf(LOGTAR_ALL, "Deleting the menuhax regular BodyCache...\n");
		ret = archive_deletefile(Theme_Extdata, "/yodyCache.bin");
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to delete the menuhax regular BodyCache: 0x%08x.\n", (unsigned int)ret);
		}

		log_printf(LOGTAR_ALL, "Deleting menuhax shuffle BodyCache...\n");
		ret = archive_deletefile(Theme_Extdata, "/yodyCache_rd.bin");
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to delete the menuhax shuffle BodyCache: 0x%08x.\n", (unsigned int)ret);
		}
	}

	return 0;
}

Result setup_builtin_theme()
{
	Result ret=0;
	int menuindex = 0;
	u32 filesize=0;

	Handle filehandle = 0;

	u32 file_lowpath_data[0xc>>2];

	FS_Path archpath = { PATH_EMPTY, 1, (u8*)"" };
	FS_Path fileLowPath;

	struct romfs_mount *mount = NULL;

	char *menu_entries[] = {
	"Red",
	"Blue",
	"Yellow",
	"Pink",
	"Black"};

	char str[64];
	char str2[64];

	memset(file_lowpath_data, 0, sizeof(file_lowpath_data));

	fileLowPath.type = PATH_BINARY;
	fileLowPath.size = 0xc;
	fileLowPath.data = (u8*)file_lowpath_data;

	display_menu(menu_entries, 5, &menuindex, "Select a built-in Home Menu theme for installation with the below menu. You can press the B button to exit. Note that this implementation can only work when this app is running from *hax payloads >=v2.0(https://smealum.github.io/3ds/).");

	if(menuindex==-1)return 0;

	ret = FSUSER_OpenFileDirectly(&filehandle, ARCHIVE_ROMFS, archpath, fileLowPath, FS_OPEN_READ, 0x0);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to open the RomFS image for the current process: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = romfsMountFromFile(filehandle, 0x0, &mount);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to mount the RomFS image for the current process: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	memset(str, 0, sizeof(str));
	snprintf(str, sizeof(str)-1, "romfs:/theme/%s_LZ.bin", menu_entries[menuindex]);

	log_printf(LOGTAR_ALL, "Using the following theme: %s\n\n", str);

	ret = displaymessage_prompt("Dump the theme-data to the menuhax_manager SD directory? Normally there's no need to use this.", NULL);

	if(ret==0)
	{
		memset(str2, 0, sizeof(str2));
		snprintf(str2, sizeof(str2)-1, "sdmc:/3ds/menuhax_manager/%s_LZ.bin", menu_entries[menuindex]);

		log_printf(LOGTAR_ALL, "Copying the built-in theme to '%s'...\n", str2);

		ret = archive_getfilesize(SDArchive, str, &filesize);
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to get the filesize for the theme-data: 0x%08x.\n", (unsigned int)ret);
		}
		else
		{
			ret = archive_copyfile(SDArchive, SDArchive, str, str2, filebuffer, filesize, 0x150000, 0, "body-data");
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Copy failed: 0x%08x.\n", (unsigned int)ret);
			}
		}
	}
	else
	{
		log_printf(LOGTAR_ALL, "Skipping theme-dumping.\n");
	}

	ret = sd2themecache(str, NULL, 1);

	romfsUnmount(mount);

	return ret;
}

Result http_getactual_payloadurl(char *requrl, char *outurl, u32 outurl_maxsize)
{
	Result ret=0;
	httpcContext context;

	ret = httpcOpenContext(&context, HTTPC_METHOD_GET, requrl, 1);
	if(ret!=0)return ret;

	ret = httpcAddRequestHeaderField(&context, "User-Agent", "menuhax_manager/"VERSION);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcAddTrustedRootCA(&context, (u8*)builtin_rootca_der, builtin_rootca_der_size);
	if(R_FAILED(ret))
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

	memset(outurl, 0, outurl_maxsize);
	ret = httpcGetResponseHeader(&context, "Location", outurl, outurl_maxsize);

	httpcCloseContext(&context);

	return ret;
}

Result http_download_content(char *url, u32 *contentsize)
{
	Result ret=0;
	u32 statuscode=0;
	httpcContext context;

	ret = httpcOpenContext(&context, HTTPC_METHOD_GET, url, 1);
	if(ret!=0)return ret;

	ret = httpcAddRequestHeaderField(&context, "User-Agent", "menuhax_manager/"VERSION);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcAddTrustedRootCA(&context, (u8*)builtin_rootca_der, builtin_rootca_der_size);
	if(R_FAILED(ret))
	{
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcAddDefaultCert(&context, SSLC_DefaultRootCert_DigiCert_EV);
	if(R_FAILED(ret))
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
		log_printf(LOGTAR_ALL, "Error: server returned HTTP statuscode %u.\n", (unsigned int)statuscode);
		httpcCloseContext(&context);
		return -2;
	}

	ret=httpcGetDownloadSizeState(&context, NULL, contentsize);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	if((*contentsize)==0 || (*contentsize)>filebuffer_maxsize)
	{
		log_printf(LOGTAR_ALL, "Invalid HTTP content-size: 0x%08x.\n", (unsigned int)*contentsize);
		ret = -3;
		httpcCloseContext(&context);
		return ret;
	}

	ret = httpcDownloadData(&context, filebuffer, *contentsize, NULL);
	if(ret!=0)
	{
		httpcCloseContext(&context);
		return ret;
	}

	httpcCloseContext(&context);

	return 0;
}

//Parse the config. The format of the first line is: "release_version=<version>". The format of each line starting with the second one is: "<modulename> <X.X.X>", where X.X.X is the unsupported_cver version.
Result parse_config(char *config, u32 configsize)
{
	Result ret=0;
	u32 configpos=0;
	u32 line_endpos;
	u32 line_len;
	u32 linenum=0;
	unsigned char version[3];

	char *linestr;
	char *strptr, *strptr2;
	module_entry *module;

	while(configpos < configsize)
	{
		linestr = &config[configpos];
		line_endpos = configsize;

		strptr = strchr(linestr, '\n');
		if(strptr)
		{
			line_len = ((size_t)strptr) - ((size_t)linestr);
			line_endpos = configpos+line_len;
		}
		else
		{
			line_len = line_endpos - configpos;
		}

		*strptr = 0;

		if(line_len)
		{
			if(linenum==0)
			{
				strptr = strstr(linestr, "release_version=");
				if(strptr)
				{
					strptr = strtok(&strptr[16], " ");
					if(strptr)
					{
						if(strncmp(strptr, VERSION, strlen(strptr)))
						{
							log_printf(LOGTAR_ALL, "This menuhax_manager build's version doesn't match the version from config.\nYou likely aren't using the latest release version, outdated versions are not supported.\n");
							return -2;
						}
					}
				}
			}
			else
			{
				strptr = strtok(linestr, " ");
				if(strptr)strptr2 = strtok(NULL, " ");

				if(strptr==NULL || strptr2==NULL)
				{
					log_printf(LOGTAR_ALL, "A line in the config is invalid.\n");
					return -1;
				}
				else
				{
					memset(version, 0, sizeof(version));
					sscanf(strptr2, "%hhu.%hhu.%hhu", &version[0], &version[1], &version[2]);

					module = NULL;
					ret = modules_findentryname(strptr, &module);
					if(ret!=0)
					{
						log_printf(LOGTAR_ALL, "This menuhax_manager build doesn't include a module with the name specified by the config: %s. Ignoring this.\n", strptr);
					}

					module->unsupported_cver = MODULE_MAKE_CVER(version[0], version[1], version[2]);
				}
			}
		}

		linenum++;
		configpos = line_endpos+1;
	}

	return 0;
}

Result load_config()
{
	Result ret=0;
	u32 configsize=0;
	char *sd_cfgpath = "sdmc:/3ds/menuhax_manager/config";

	memset(filebuffer, 0, filebuffer_maxsize);

	log_printf(LOGTAR_ALL, "Downloading config via HTTPC...\n");
	
	ret = httpcInit(0);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "Failed to initialize HTTPC: 0x%08x.\n", (unsigned int)ret);
	}
	else
	{
		ret = http_download_content("https://yls8.mtheall.com/menuhax/config", &configsize);
		httpcExit();

		if(ret==0)
		{
			unlink(sd_cfgpath);
			ret = archive_writefile(SDArchive, sd_cfgpath, filebuffer, configsize, configsize);
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Failed to write the config to SD(0x%08x), ignoring.\n", (unsigned int)ret);
				ret = 0;
			}
		}
	}

	if(ret!=0)
	{
		memset(filebuffer, 0, filebuffer_maxsize);

		log_printf(LOGTAR_ALL, "Config download failed(0x%08x), trying to load it from SD...\n", (unsigned int)ret);

		ret = archive_getfilesize(SDArchive, sd_cfgpath, &configsize);
		if(ret==0 && configsize>filebuffer_maxsize)
		{
			log_printf(LOGTAR_ALL, "Filesize is too large(0x%x).\n", (unsigned int)configsize);
			ret = -1;
		}

		if(ret==0)ret = archive_readfile(SDArchive, sd_cfgpath, filebuffer, configsize);
		if(ret!=0)log_printf(LOGTAR_ALL, "Failed to load config from SD: 0x%08x.\n", (unsigned int)ret);
	}

	if(ret!=0)return ret;

	if(configsize==filebuffer_maxsize)
	{
		configsize--;
		filebuffer[configsize] = 0;
	}

	log_printf(LOGTAR_ALL, "Parsing config...\n");

	return parse_config((char*)filebuffer, configsize);
}

Result install_menuhax(char *ropbin_filepath)
{
	Result ret = 0, tmpret;
	u8 region=0;
	u8 new3dsflag = 0;
	u64 menu_programid = 0;
	AM_TitleEntry menu_title_entry;
	u32 payloadinfo[4];
	char menuhax_basefn[256];

	OS_VersionBin nver_versionbin;
	OS_VersionBin cver_versionbin;

	module_entry *module = NULL;

	u32 sdcfg[0x10>>2];
	menuhax_cfg new_sdcfg;

	u32 payloadsize = 0;

	char payloadurl[0x80];

	char tmpstr[256];

	memset(menuhax_basefn, 0, sizeof(menuhax_basefn));

	memset(payloadinfo, 0, sizeof(payloadinfo));

	memset(&nver_versionbin, 0, sizeof(OS_VersionBin));
	memset(&cver_versionbin, 0, sizeof(OS_VersionBin));

	memset(payloadurl, 0, sizeof(payloadurl));

	log_printf(LOGTAR_ALL, "Getting system info...\n");

	ret = cfguInit();
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to init cfg: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}
	ret = CFGU_SecureInfoGetRegion(&region);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to get region from cfg: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}
	if(region>=7)
	{
		log_printf(LOGTAR_ALL, "Region value from cfg is invalid: 0x%02x.\n", (unsigned int)region);
		ret = -9;
		return ret;
	}
	cfguExit();

	APT_CheckNew3DS(&new3dsflag);

	aptOpenSession();
	ret = APT_GetAppletInfo(APPID_HOMEMENU, &menu_programid, NULL, NULL, NULL, NULL);
	aptCloseSession();

	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to get the Home Menu programID: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = AM_GetTitleInfo(MEDIATYPE_NAND, 1, &menu_programid, &menu_title_entry);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to get the Home Menu title-version: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	snprintf(menuhax_basefn, sizeof(menuhax_basefn)-1, "menuhax_%s%u_%s", regionids_table[region], menu_title_entry.version, new3dsflag?"new3ds":"old3ds");

	snprintf(ropbin_filepath, 255, "sdmc:/ropbinpayload_%s.bin", menuhax_basefn);
	unlink(ropbin_filepath);

	snprintf(ropbin_filepath, 255, "sdmc:/menuhax/ropbinpayload_%s.bin", menuhax_basefn);

	ret = osGetSystemVersionData(&nver_versionbin, &cver_versionbin);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to load the system-version: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	snprintf(payloadurl, sizeof(payloadurl)-1, "https://smea.mtheall.com/get_ropbin_payload.php?version=%s-%d-%d-%d-%d-%s", new3dsflag?"NEW":"OLD", cver_versionbin.mainver, cver_versionbin.minor, cver_versionbin.build, nver_versionbin.mainver, regionids_table[region]);

	log_printf(LOGTAR_ALL, "Detected system-version: %s %d.%d.%d-%d %s\n", new3dsflag?"New3DS":"Old3DS", cver_versionbin.mainver, cver_versionbin.minor, cver_versionbin.build, nver_versionbin.mainver, regionids_table[region]);

	ret = modules_getcompatible_entry(&cver_versionbin, &module, 0);
	if(ret)
	{
		if(ret == -7)log_printf(LOGTAR_ALL, "All of the exploit(s) included with this menuhax_manager app are not supported with your system-version due to the exploit(s) being fixed.\n");
		return ret;
	}

	memset(filebuffer, 0, filebuffer_maxsize);

	log_printf(LOGTAR_ALL, "\n");
	ret = displaymessage_prompt("Skip ropbin-payload setup? Normally you should just press B.", NULL);

	if(ret==0)
	{
		log_printf(LOGTAR_ALL, "Skipping ropbin payload setup. If this was not intended, re-run the install again after this.\n");
	}
	else
	{
		log_printf(LOGTAR_ALL, "Setting up ropbin payload...\n");

		ret = archive_getfilesize(SDArchive, "sdmc:/menuhax/menuhaxmanager_input_payload.bin", &payloadsize);
		if(ret==0)
		{
			if(payloadsize==0 || payloadsize>filebuffer_maxsize)
			{
				log_printf(LOGTAR_ALL, "Invalid SD payload size: 0x%08x.\n", (unsigned int)payloadsize);
				ret = -3;
			}
		}
		if(ret==0)ret = archive_readfile(SDArchive, "sdmc:/menuhax/menuhaxmanager_input_payload.bin", filebuffer, payloadsize);

		if(ret==0)
		{
			log_printf(LOGTAR_ALL, "The input payload already exists on SD, that will be used instead of downloading the payload.\n");
		}
		else
		{
			ret = httpcInit(0);
			if(R_FAILED(ret))
			{
				log_printf(LOGTAR_ALL, "Failed to initialize HTTPC: 0x%08x.\n", (unsigned int)ret);
				if(ret==0xd8e06406)
				{
					log_printf(LOGTAR_ALL, "The HTTPC service is inaccessible. With the *hax-payload this may happen if the process this app is running under doesn't have access to that service. Please try rebooting the system, boot *hax-payload, then directly launch the app.\n");
				}

				return ret;
			}

			log_printf(LOGTAR_ALL, "Requesting the actual payload URL with HTTPC...\n");
			ret = http_getactual_payloadurl(payloadurl, payloadurl, sizeof(payloadurl));
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Failed to request the actual payload URL: 0x%08x.\n", (unsigned int)ret);
				log_printf(LOGTAR_ALL, "If the server isn't down, and the HTTP request was actually done, this may mean your system-version or region isn't supported by the *hax-payload currently.\n");
				httpcExit();
				return ret;
			}

			//Use https instead of http with the below site.
			if(strncmp(payloadurl, "http://smealum.github.io/", 25)==0)
			{
				memmove(&payloadurl[5], &payloadurl[4], strlen(payloadurl)-4);
				payloadurl[4] = 's';
			}

			log_printf(LOGTAR_ALL, "Downloading the actual payload with HTTPC...\n");
			ret = http_download_content(payloadurl, &payloadsize);
			httpcExit();
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Failed to download the actual payload with HTTP: 0x%08x.\n", (unsigned int)ret);
				log_printf(LOGTAR_ALL, "If the server isn't down, and the HTTP request was actually done, this may mean your system-version or region isn't supported by the *hax-payload currently.\n");
				return ret;
			}
		}

		log_printf(LOGTAR_ALL, "Writing the menuropbin to SD, to the following path: %s.\n", ropbin_filepath);
		unlink("sdmc:/menuhax_ropbinpayload.bin");//Delete the ropbin with the filepath used by the <=v1.2 menuhax.
		unlink(ropbin_filepath);
		ret = archive_writefile(SDArchive, ropbin_filepath, filebuffer, 0x10000, 0);
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to write the menurop to the SD file: 0x%08x.\n", (unsigned int)ret);
			return ret;
		}

		memset(filebuffer, 0, filebuffer_maxsize);
	}

	while(1)
	{
		if(!module->manual_name_display)log_printf(LOGTAR_ALL, "Installing %s...\n", module->name);

		ret = module->haxinstall(menuhax_basefn);
		if(ret==0)break;

		if(module->index+1 < MAX_MODULES)
		{
			tmpret = modules_getcompatible_entry(&cver_versionbin, &module, module->index+1);
			if(tmpret)
			{
				break;
			}

			log_printf(LOGTAR_ALL, "Installation failed with error 0x%08x, attempting installation with another module...\n", (unsigned int)ret);
		}
		else
		{
			break;
		}
	}

	if(ret==0)
	{
		memset(sdcfg, 0, sizeof(sdcfg));
		memset(&new_sdcfg, 0, sizeof(new_sdcfg));

		ret = archive_readfile(SDArchive, "sdmc:/menuhax_padcfg.bin", (u8*)sdcfg, sizeof(sdcfg));
		if(ret==0)
		{
			memcpy(&new_sdcfg.type, sdcfg, 0xc);
			new_sdcfg.version = MENUHAXCFG_CURVERSION;
			new_sdcfg.delay_value = MENUHAXCFG_DEFAULT_DELAYVAL;
			new_sdcfg.flags = MENUHAXCFG_FLAG_THEME;

			ret = archive_writefile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&new_sdcfg, sizeof(new_sdcfg), 0);
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Warning: successfully read the old padcfg file,\nbut writing to the new file failed: 0x%08x.\nContinuing anyway.\n", (unsigned int)ret);
				ret = 0;
			}
			else
			{
				unlink("sdmc:/menuhax_padcfg.bin");
			}
		}
		else
		{
			ret = 0;//Ignore file-read failure for the old cfg file.
		}

		rename("sdmc:/menuhax_imagedisplay.bin", "sdmc:/menuhax/menuhax_imagedisplay.bin");

		menuhaxcfg_create();

		menuhaxcfg_set_themeflag(module->themeflag);
	}

	if(ret==0)
	{
		memset(tmpstr, 0, sizeof(tmpstr));
		snprintf(tmpstr, sizeof(tmpstr)-1, "%s:%s", VERSION, module->name);

		unlink("sdmc:/menuhax/menuhax_installedversion");
		archive_writefile(SDArchive, "sdmc:/menuhax/menuhax_installedversion", (u8*)tmpstr, strlen(tmpstr), strlen(tmpstr));
	}

	return ret;
}

void print_padbuttons(u32 val)
{
	u32 i;

	if(val==0)
	{
		log_printf(LOGTAR_ALL, "<no-buttons>");
		return;
	}

	for(i=0; i<12; i++)
	{
		if((val & (1<<i))==0)continue;

		switch(1<<i)
		{
			case KEY_A:
				log_printf(LOGTAR_ALL, "A ");
			break;

			case KEY_B:
				log_printf(LOGTAR_ALL, "B ");
			break;

			case KEY_SELECT:
				log_printf(LOGTAR_ALL, "SELECT ");
			break;

			case KEY_START:
				log_printf(LOGTAR_ALL, "START ");
			break;

			case KEY_DRIGHT:
				log_printf(LOGTAR_ALL, "D-PAD RIGHT ");
			break;

			case KEY_DLEFT:
				log_printf(LOGTAR_ALL, "D-PAD LEFT ");
			break;

			case KEY_DUP:
				log_printf(LOGTAR_ALL, "D-PAD UP ");
			break;

			case KEY_DDOWN:
				log_printf(LOGTAR_ALL, "D-PAD DOWN ");
			break;

			case KEY_R:
				log_printf(LOGTAR_ALL, "R ");
			break;

			case KEY_L:
				log_printf(LOGTAR_ALL, "L ");
			break;

			case KEY_X:
				log_printf(LOGTAR_ALL, "X ");
			break;

			case KEY_Y:
				log_printf(LOGTAR_ALL, "Y ");
			break;
		}
	}
}

Result setup_sdcfg()
{
	Result ret=0;
	u32 kDown, padval=0;
	int menuindex = 0;
	int draw;
	unsigned long long nanosec = 1000000000ULL;
	unsigned long long delayval;
	int endpos;
	int pos, pos2;
	unsigned long long delay_adjustval, delay_adjustval_tmp;

	menuhax_cfg sdcfg;

	char *menu_entries[] = {
	"Type1: Only trigger the haxx when the PAD state matches the specified value(specified button(s) must be pressed).",
	"Type2: Only trigger the haxx when the PAD state doesn't match the specified value.",
	"Type0: Default PAD config is used.",
	"Configure the delay value used with the delay right before jumping to the *hax payload. This may affect the random *hax payload boot failures."};

	log_printf(LOGTAR_ALL, "Configuring the padcfg file on SD...\n");

	memset(&sdcfg, 0, sizeof(sdcfg));

	ret = archive_readfile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&sdcfg, sizeof(sdcfg));
	if(ret==0)
	{
		log_printf(LOGTAR_ALL, "The cfg file already exists on SD.\n");

		if(sdcfg.version!=MENUHAXCFG_CURVERSION)
		{
			log_printf(LOGTAR_ALL, "The cfg format version is invalid(0x%x).\nThe cfg will be deleted, after that you can try using the cfg menu again.\n", (unsigned int)sdcfg.version);
			unlink("sdmc:/menuhax/menuhax_cfg.bin");
			return 0;
		}

		log_printf(LOGTAR_ALL, "Current cfg:\n");
		log_printf(LOGTAR_ALL, "Type 0x%x: ", (unsigned int)sdcfg.type);

		if(sdcfg.type==0x1)
		{
			log_printf(LOGTAR_ALL, "Only trigger the haxx when the PAD state matches the specified value(specified button(s) must be pressed).\n");
			log_printf(LOGTAR_ALL, "Currently selected PAD value: 0x%x ", (unsigned int)sdcfg.padvalues[0]);
			print_padbuttons(sdcfg.padvalues[0]);
			log_printf(LOGTAR_ALL, "\n");
		}
		else if(sdcfg.type==0x2)
		{
			log_printf(LOGTAR_ALL, "Only trigger the haxx when the PAD state doesn't match the specified value.\n");
			log_printf(LOGTAR_ALL, "Currently selected PAD value: 0x%x ", (unsigned int)sdcfg.padvalues[1]);
			print_padbuttons(sdcfg.padvalues[1]);
			log_printf(LOGTAR_ALL, "\n");
		}
		else
		{
			log_printf(LOGTAR_ALL, "None, the default PAD trigger is used.\n");
		}

		delayval = (unsigned long long)sdcfg.delay_value;

		log_printf(LOGTAR_ALL, "Current delay value: %llu(%f seconds).\n", delayval, ((double)delayval) / nanosec);
	}
	else
	{
		log_printf(LOGTAR_ALL, "The cfg file currently doesn't exist on SD.\n");

		sdcfg.version = MENUHAXCFG_CURVERSION;
		sdcfg.delay_value = MENUHAXCFG_DEFAULT_DELAYVAL;
		sdcfg.flags = MENUHAXCFG_FLAG_THEME;

		delayval = (unsigned long long)sdcfg.delay_value;
	}

	displaymessage_waitbutton();

	display_menu(menu_entries, 4, &menuindex, "Select a type/option with the below menu. You can press B to exit without changing anything.");

	if(menuindex==-1)return 0;

	switch(menuindex)
	{
		case 0:
			sdcfg.type = 0x1;
		break;

		case 1:
			sdcfg.type = 0x2;
		break;

		case 2:
			sdcfg.type = 0x0;
		break;
	}

	if(menuindex!=3)memset(sdcfg.padvalues, 0, sizeof(sdcfg.padvalues));

	if(sdcfg.type && menuindex!=3)
	{
		log_printf(LOGTAR_ALL, "Press the button(s) you want to select for the PAD state value as described above(no New3DS-only buttons). If you want to select <no-buttons>, don't press any buttons. Then, while the buttons are being pressed, if any, touch the bottom-screen.\n");

		while(1)
		{
			gspWaitForVBlank();
			hidScanInput();
			kDown = hidKeysHeld();

			if(kDown & KEY_TOUCH)
			{
				padval = kDown & 0xfff;
				break;
			}
		}

		log_printf(LOGTAR_ALL, "Selected PAD value: 0x%x ", (unsigned int)padval);
		print_padbuttons(padval);
		sdcfg.padvalues[sdcfg.type-1] = padval;
		log_printf(LOGTAR_ALL, "\n");
	}

	if(menuindex==3)
	{
		draw = 1;
		delay_adjustval = nanosec;

		while(1)
		{
			gspWaitForVBlank();
			hidScanInput();
			kDown = hidKeysDown();

			if(draw)
			{
				draw = 0;
				consoleClear();

				log_printf(LOGTAR_ALL, "Select the new nano-seconds delay value with the D-Pad/Circle-Pad, then press A to continue, or B to abort.\nThe initial config is exactly 3-seconds, press Y to set the delay to that.\n");
				endpos = log_printf(LOGTAR_ALL, "%llu", delayval);
				log_printf(LOGTAR_ALL, "(%f seconds).\n", ((double)delayval) / nanosec);

				pos2 = 0;
				delay_adjustval_tmp = delay_adjustval;
				while(delay_adjustval_tmp>1)
				{
					pos2++;
					delay_adjustval_tmp/= 10;
				}

				while(pos2+1 > endpos)
				{
					pos2--;
					delay_adjustval/= 10;
				}

				for(pos=0; pos<endpos-(pos2+1); pos++)log_printf(LOGTAR_ALL, " ");
				log_printf(LOGTAR_ALL, "^\n");
			}

			if(kDown & KEY_A)
			{
				break;
			}
			else if(kDown & KEY_B)
			{
				return 0;
			}

			if((kDown & KEY_DOWN) && delayval!=0)
			{
				delayval-= delay_adjustval;
				draw = 1;
			}
			else if(kDown & KEY_UP)
			{
				delayval+= delay_adjustval;
				draw = 1;
			}
			else if(kDown & KEY_LEFT)
			{
				delay_adjustval*= 10;
				draw = 1;
			}
			else if((kDown & KEY_RIGHT) && delay_adjustval>1)
			{
				delay_adjustval/= 10;
				draw = 1;
			}
			else if(kDown & KEY_Y)
			{
				delayval = MENUHAXCFG_DEFAULT_DELAYVAL;
				draw = 1;
			}
		}

		sdcfg.delay_value = (u64)delayval;
	}

	ret = archive_writefile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&sdcfg, sizeof(sdcfg), 0);
	if(ret!=0)log_printf(LOGTAR_ALL, "Failed to write the cfg file: 0x%x.\n", (unsigned int)ret);
	if(ret==0)log_printf(LOGTAR_ALL, "Config file successfully written.\n");

	return ret;
}

void menuhaxcfg_create()//Create the cfg file when it doesn't already exist.
{
	Result ret=0;
	menuhax_cfg sdcfg;

	ret = archive_readfile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&sdcfg, sizeof(sdcfg));
	if(ret==0)return;

	memset(&sdcfg, 0, sizeof(sdcfg));

	sdcfg.version = MENUHAXCFG_CURVERSION;
	sdcfg.delay_value = MENUHAXCFG_DEFAULT_DELAYVAL;
	sdcfg.flags = MENUHAXCFG_FLAG_THEME;

	ret = archive_writefile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&sdcfg, sizeof(sdcfg), 0);
}

bool menuhaxcfg_get_themeflag()
{
	Result ret=0;
	menuhax_cfg sdcfg;
	u32 old_sdcfg[0x10>>2];

	ret = archive_readfile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&sdcfg, sizeof(sdcfg));
	if(ret!=0)//When the old/new cfg files don't exist, return true for disabled user-themes.
	{
		memset(old_sdcfg, 0, sizeof(old_sdcfg));

		ret = archive_readfile(SDArchive, "sdmc:/menuhax_padcfg.bin", (u8*)old_sdcfg, sizeof(old_sdcfg));
		if(ret==0)return false;//When the new cfg file doesn't exist but the old cfg file does exist, return false for enabled user-themes.

		return true;
	}

	if(sdcfg.flags & MENUHAXCFG_FLAG_THEME)return true;
	return false;
}

void menuhaxcfg_set_themeflag(bool themeflag)
{
	Result ret=0;
	menuhax_cfg sdcfg;

	ret = archive_readfile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&sdcfg, sizeof(sdcfg));
	if(ret!=0)return;

	sdcfg.flags &= ~MENUHAXCFG_FLAG_THEME;
	if(themeflag)sdcfg.flags |= MENUHAXCFG_FLAG_THEME;

	ret = archive_writefile(SDArchive, "sdmc:/menuhax/menuhax_cfg.bin", (u8*)&sdcfg, sizeof(sdcfg), 0);
}

Result imagedisplay_loadpng(char *filepath, u8 **finalimage_out)
{
	Result ret=0;
	unsigned w = 0, h = 0, x, y, pos0, pos1;
	size_t pngsize = 0;
	u8 *outbuf = NULL;
	u8 *pngbuf = NULL;
	u8 *finalimage = NULL;

	*finalimage_out = NULL;

	log_printf(LOGTAR_LOG, "Loading PNG from FS: %s\n", filepath);

	ret = archive_getfilesize(SDArchive, filepath, (u32*)&pngsize);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to get the filesize of the PNG: 0x%08x. The file probably doesn't exist.\n", (unsigned int)ret);
		return ret;
	}

	pngbuf = malloc(pngsize);
	if(pngbuf==NULL)
	{
		log_printf(LOGTAR_LOG, "Failed to alloc the PNG buffer with size 0x%08x.\n", (unsigned int)pngsize);
		return 1;
	}

	ret = archive_readfile(SDArchive, filepath, pngbuf, pngsize);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to read the PNG from FS: 0x%08x.\n", (unsigned int)ret);
		free(pngbuf);
		return ret;
	}

	log_printf(LOGTAR_LOG, "Decoding PNG...\n");

	ret = lodepng_decode24(&outbuf, &w, &h, pngbuf, pngsize);
	free(pngbuf);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "lodepng returned an error: %s\n", lodepng_error_text(ret));
		return ret;
	}

	log_printf(LOGTAR_LOG, "Decoding finished.\n");

	if(!(w==800 && h==240) && !(w==240 && h==800))
	{
		log_printf(LOGTAR_LOG, "PNG width and/or height is invalid. 800x240 or 240x800 is required but the PNG is %ux%u.\n", (unsigned int)w, (unsigned int)h);
		free(outbuf);
		return 2;
	}

	finalimage = malloc(0x8ca00);
	if(finalimage==NULL)
	{
		log_printf(LOGTAR_LOG, "Failed to alloc the finalimage buffer.\n");
		free(outbuf);
		return 1;
	}

	log_printf(LOGTAR_LOG, "Converting the image to the required format...\n");

	for(x=0; x<w; x++)
	{
		for(y=0; y<h; y++)
		{
			//Convert the image to 240x800 if it's not already those dimensions.
			pos0 = (x*h + (h-1-y)) * 3;
			pos1 = (y*w + x) * 3;
			if(w==240)pos0 = pos1;

			//Copy the pixel data + swap the color components.
			finalimage[pos0 + 2] = outbuf[pos1 + 0];
			finalimage[pos0 + 1] = outbuf[pos1 + 1];
			finalimage[pos0 + 0] = outbuf[pos1 + 2];
		}
	}

	free(outbuf);

	*finalimage_out = finalimage;

	return 0;
}

int imagedisplay_dirfilter(const struct dirent *dirent)//Only return dir-entries with a name ending with ".png".
{
	size_t len;

	len = strlen(dirent->d_name);
	if(len < 4)return 0;

	if(dirent->d_name[0]=='.')return 0;//Ignore "hidden" dir-entries.

	if(strncmp(&dirent->d_name[len-4], ".png", 4))return 0;

	return 1;
}

//Originally this was supposed to use scandir() but scandir() isn't actually available.
Result imagedisplay_scandir(const char *dirpath, struct dirent ***namelist, size_t *total_entries)
{
	Result ret=0;

	size_t pos=0;
	DIR *dirp;
	struct dirent *direntry;

	*total_entries = 0;

	dirp = opendir(dirpath);
	if(dirp==NULL)return errno;

	while((direntry = readdir(dirp)))
	{
		if(imagedisplay_dirfilter(direntry)==0)continue;

		(*total_entries)++;
	}

	closedir(dirp);

	if(*total_entries == 0)return 0;

	dirp = opendir(dirpath);
	if(dirp==NULL)return errno;

	*namelist = malloc(sizeof(struct dirent *) * (*total_entries));
	if(*namelist == NULL)
	{
		closedir(dirp);
		return -2;
	}

	ret = 0;

	while((direntry = readdir(dirp)) && pos < *total_entries)
	{
		if(imagedisplay_dirfilter(direntry)==0)continue;

		(*namelist)[pos] = malloc(sizeof(struct dirent));
		if((*namelist)[pos] == NULL)
		{
			ret = -2;
			break;
		}

		memcpy((*namelist)[pos], direntry, sizeof(struct dirent));

		pos++;
	}

	closedir(dirp);

	if(ret!=0)
	{
		for(pos=0; pos<(*total_entries); pos++)free((*namelist)[pos]);
		free(*namelist);
		*namelist = NULL;
	}

	return 0;
}

void imagedisplay_previewimage(u8 *finalimage)
{
	u8 *framebuf;
	u32 size = 240*400*3;
	u32 i;

	gspWaitForVBlank();
	gfxSetDoubleBuffering(GFX_TOP, true);
	gfxSetScreenFormat(GFX_TOP, GSP_BGR8_OES);

	for(i=0; i<2; i++)
	{
		framebuf = gfxGetFramebuffer(GFX_TOP, GFX_LEFT, NULL, NULL);
		if(finalimage)memcpy(framebuf, finalimage, size);
		if(finalimage==NULL)memset(framebuf, 0, size);

		framebuf = gfxGetFramebuffer(GFX_TOP, GFX_RIGHT, NULL, NULL);
		if(finalimage)memcpy(framebuf, &finalimage[size], size);
		if(finalimage==NULL)memset(framebuf, 0, size);

		gfxFlushBuffers();
		gfxSwapBuffersGpu();
		gspWaitForVBlank();
	}
}

Result imagedisplay_selectsdimage(const char *dirpath, u8 **finalimage_out, int *exitflag)
{
	struct dirent **namelist = NULL;
	Result ret=0;
	int pos=0;
	size_t total_entries=0;

	u32 redraw = 1;
	u32 kDown = 0;

	char filepath[256];

	*finalimage_out = NULL;
	*exitflag = 0;

	ret = imagedisplay_scandir(dirpath, &namelist, &total_entries);
	if(ret!=0)return ret;

	if(total_entries==0)
	{
		log_printf(LOGTAR_ALL, "The custom splash-screen directory doesn't contain any PNGs, aborting...\n");
		*exitflag = 1;
		return 0;
	}

	while(1)
	{
		gspWaitForVBlank();
		hidScanInput();

		kDown = hidKeysDown();

		if(redraw)
		{
			redraw = 0;

			consoleClear();
			log_printf(LOGTAR_ALL, "Select a custom splash-screen image via the D-Pad/Circle-Pad, then press A.\nYou can press B to exit without changing anything.\nThe selected image if successfully loaded is displayed on the top-screen.\n");
			log_printf(LOGTAR_ALL, "%d of %u:\n", pos+1, total_entries);
			log_printf(LOGTAR_ALL, "%s\n", namelist[pos]->d_name);

			memset(filepath, 0, sizeof(filepath));
			snprintf(filepath, sizeof(filepath)-1, "%s/%s", dirpath, namelist[pos]->d_name);

			free(*finalimage_out);//This will free the finalimage buffer if it's already allocated.
			*finalimage_out = NULL;
			ret = imagedisplay_loadpng(filepath, finalimage_out);
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "N/A since PNG loading failed(details were logged).\n");
			}

			imagedisplay_previewimage(*finalimage_out);
		}

		if(kDown & (KEY_RIGHT | KEY_DOWN))
		{
			pos++;
			if(pos>=total_entries)pos = 0;
			redraw = 1;

			continue;
		}
		else if(kDown & (KEY_LEFT | KEY_UP))
		{
			pos--;
			if(pos<0)pos = total_entries-1;
			redraw = 1;

			continue;
		}

		if(ret == 0 && (kDown & KEY_A))
		{
			break;
		}
		else if(kDown & KEY_B)
		{
			*exitflag = 1;
			break;
		}
	}

	for(pos=0; pos<total_entries; pos++)free(namelist[pos]);
	free(namelist);

	return 0;
}

Result setup_imagedisplay()
{
	Result ret=0;
	int menuindex = 0;
	u32 imgdisp_exists = 0;
	u32 imgid = 0;
	u32 pos;
	int exitflag = 0;
	u8 *finalimages[2];

	struct stat filestats;

	struct dirent **namelist = NULL;
	size_t total_entries=0;

	char *menu_entries[] = {
	"Default image.",
	"Select a custom image.",
	"Delete the image-display file."};

	char new_menutext[128];
	char filepath0[256];
	char filepath1[256];

	memset(finalimages, 0, sizeof(finalimages));

	imgdisp_exists = 1;
	ret = stat("sdmc:/menuhax/menuhax_imagedisplay.bin", &filestats);
	if(ret==-1)imgdisp_exists = 0;

	log_printf(LOGTAR_ALL, "This will configure the image displayed on the main-screen when menuhax triggers. When the image-display file isn't loaded successfully by menuhax, it will display junk.\nToggling the screen used by this app via the Y button is disabled under this menu.\n\n");
	if(imgdisp_exists)
	{
		log_printf(LOGTAR_ALL, "The image-display file already exists on SD.\n");

		finalimages[0] = malloc(0x8ca00);
		if(finalimages[0])
		{
			memset(finalimages[0], 0, 0x8ca00);

			ret = archive_readfile(SDArchive, "sdmc:/menuhax/menuhax_imagedisplay.bin", finalimages[0], 0x8ca00);
			if(ret==0)
			{
				imagedisplay_previewimage(finalimages[0]);
				log_printf(LOGTAR_ALL, "The image now displayed on the top-screen is the current content of the image-display file.\n");
			}

			free(finalimages[0]);
			finalimages[0] = NULL;
		}
	}
	else
	{
		log_printf(LOGTAR_ALL, "The image-display file doesn't exist on SD.\n");
	}

	//Create the 'splashscreen' directory, then move each .png file under the menuhax_manager directory, if any, into this directory.
	mkdir("sdmc:/3ds/menuhax_manager/splashscreen/", 0777);

	ret = imagedisplay_scandir("sdmc:/3ds/menuhax_manager", &namelist, &total_entries);
	if(ret==0 && total_entries>0)
	{
		for(pos=0; pos<total_entries; pos++)
		{
			memset(filepath0, 0, sizeof(filepath0));
			snprintf(filepath0, sizeof(filepath0)-1, "%s/%s", "sdmc:/3ds/menuhax_manager", namelist[pos]->d_name);

			memset(filepath1, 0, sizeof(filepath1));
			snprintf(filepath1, sizeof(filepath1)-1, "%s/%s", "sdmc:/3ds/menuhax_manager/splashscreen", namelist[pos]->d_name);

			rename(filepath0, filepath1);

			free(namelist[pos]);
		}

		free(namelist);
	}

	displaymessage_waitbutton();

	log_printf(LOGTAR_ALL, "Loading PNG(s)...\n");

	imagedisplay_loadpng("romfs:/default_imagedisplay.png", &finalimages[0]);

	memset(new_menutext, 0, sizeof(new_menutext));

	for(pos=0; pos<1; pos++)
	{
		if(finalimages[pos]==NULL)
		{
			snprintf(&new_menutext[64*pos], 63, "%s %s", menu_entries[pos], "N/A since PNG loading failed.");
			menu_entries[pos] = &new_menutext[64*pos];
		}
	}

	imagedisplay_previewimage(finalimages[0]);

	display_menu(menu_entries, 2 + imgdisp_exists, &menuindex, "Select an option with the below menu. You can press B to exit without changing anything. The image displayed on the top-screen is what would be used if you select the default-image option below");

	log_printf(LOGTAR_ALL, "\n");

	if(menuindex==-1)
	{
		for(pos=0; pos<2; pos++)free(finalimages[pos]);
		return 0;
	}

	switch(menuindex)
	{
		case 0:
		case 1:
			imgid = (u32)menuindex;
		break;

		case 2:
			unlink("sdmc:/menuhax/menuhax_imagedisplay.bin");
			for(pos=0; pos<2; pos++)free(finalimages[pos]);
		return 0;
	}

	if(imgid==1)
	{
		ret = imagedisplay_selectsdimage("sdmc:/3ds/menuhax_manager/splashscreen", &finalimages[imgid], &exitflag);
		if(ret!=0)
		{
			log_printf(LOGTAR_ALL, "Failed to select the custom image: 0x%08x.\n", (unsigned int)ret);
			for(pos=0; pos<2; pos++)free(finalimages[pos]);
			return ret;
		}

		if(exitflag)
		{
			for(pos=0; pos<2; pos++)free(finalimages[pos]);
			return 0;
		}
	}

	if(finalimages[imgid]==NULL)
	{
		log_printf(LOGTAR_ALL, "The selected image isn't available since PNG loading failed(details were logged).\n");
		for(pos=0; pos<2; pos++)free(finalimages[pos]);
		return -1;
	}

	log_printf(LOGTAR_ALL, "Writing the final image to SD...\n");

	ret = archive_writefile(SDArchive, "sdmc:/menuhax/menuhax_imagedisplay.bin", finalimages[imgid], 0x8ca00, 0);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to write the image-display file to SD: 0x%08x.\n", (unsigned int)ret);
	}

	for(pos=0; pos<2; pos++)free(finalimages[pos]);

	return ret;
}

void delete_dir(const char *dirpath)
{
	DIR *dirp;
	struct dirent *direntry;

	char entpath[NAME_MAX];

	dirp = opendir(dirpath);
	if(dirp==NULL)return;

	while((direntry = readdir(dirp)))
	{
		if(strcmp(direntry->d_name, ".")==0 || strcmp(direntry->d_name, "..")==0)continue;

		memset(entpath, 0, sizeof(entpath));

		snprintf(entpath, sizeof(entpath)-1, "%s/%s", dirpath, direntry->d_name);

		unlink(entpath);
	}

	closedir(dirp);
	rmdir(dirpath);
}

void deleteold_sd_data()
{
	log_printf(LOGTAR_ALL, "Deleting SD data from old menuhax_manager versions, etc...\n");

	mkdir("sdmc:/menuhax/", 0777);

	unlink("sdmc:/3ds/menuhax_manager/blanktheme.lz");

	delete_dir("sdmc:/3ds/menuhax_manager/finaloutput/themepayload");
	delete_dir("sdmc:/3ds/menuhax_manager/finaloutput/shufflepayload");
	rmdir("sdmc:/3ds/menuhax_manager/finaloutput");
}

int main(int argc, char **argv)
{
	Result ret = 0;
	int menuindex = 0;
	int pos, count=0;
	int menucount;
	int curscreen = 0;
	u32 size=0;

	char headerstr[1024];
	char tmpstr[256];
	char tmpstr2[256];

	char ropbin_filepath[256];

	char *menu_entries[] = {
	"Install",
	"Delete",
	"Configure menuhax.",
	"Configure the menuhax splash-screen.",
	"Install custom theme.",
	"Setup a built-in Home Menu 'Basic' color theme."};

	// Initialize services
	gfxInitDefault();

	initialize_menu();

	memset(ropbin_filepath, 0, sizeof(ropbin_filepath));

	memset(modules_list, 0, sizeof(modules_list));

	ret = log_init("sdmc:/3ds/menuhax_manager/menuhax_manager.log");
	if(ret!=0)
	{
		printf("Failed to initialize logging: 0x%08x.\n", (unsigned int)ret);
	}

	log_printf(LOGTAR_ALL, "menuhax_manager %s by yellows8.\n", VERSION);

	if(ret==0)
	{
		for(pos=0; pos<MAX_MODULES; pos++)
		{
			modules_list[pos].index = pos;
		}

		register_modules();

		for(pos=0; pos<MAX_MODULES; pos++)
		{
			if(modules_list[pos].initialized)count++;
		}

		if(count==0)
		{
			ret = -2;
			log_printf(LOGTAR_ALL, "No modules were found, this menuhax_manager app wasn't built properly. This should never happen with the release-archive.\n");
		}
	}

	if(ret==0)
	{
		ret = romfsInit();
		if(R_FAILED(ret))log_printf(LOGTAR_ALL, "romfsInit() failed: 0x%08x.\n", (unsigned int)ret);
	}

	if(ret==0)
	{
		ret = amInit();
		if(R_FAILED(ret))
		{
			log_printf(LOGTAR_ALL, "Failed to initialize AM: 0x%08x.\n", (unsigned int)ret);
			if(ret==0xd8e06406)
			{
				log_printf(LOGTAR_ALL, "The AM service is inaccessible. With the *hax-payload this should never happen. This is normal with plain ninjhax v1.x, ninjhax >=v2.x should be used instead.\n");
			}
		}
	}

	if(ret==0)
	{
		filebuffer = (u8*)malloc(0x400000);
		if(filebuffer==NULL)
		{
			log_printf(LOGTAR_ALL, "Failed to allocate memory.\n");
			ret = -1;
		}
		else
		{
			memset(filebuffer, 0, filebuffer_maxsize);
		}
	}

	if(R_SUCCEEDED(ret))
	{
		deleteold_sd_data();

		log_printf(LOGTAR_ALL, "Opening extdata archives...\n");

		ret = open_extdata();
		if(ret==0)
		{
			log_printf(LOGTAR_ALL, "Finished opening extdata.\n\n");

			ret = load_config();
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Failed to load config: 0x%08x.\n", (unsigned int)ret);
			}

			while(ret==0)
			{
				menucount = 6;
				if(menuhaxcfg_get_themeflag())menucount-= 2;

				memset(tmpstr, 0, sizeof(tmpstr));
				memset(tmpstr2, 0, sizeof(tmpstr2));
				ret = archive_getfilesize(SDArchive, "sdmc:/menuhax/menuhax_installedversion", &size);
				if(ret==0 && size>0 && size<sizeof(tmpstr)-1)
				{
					ret = archive_readfile(SDArchive, "sdmc:/menuhax/menuhax_installedversion", (u8*)tmpstr, size);
					if(ret==0 && tmpstr[0])snprintf(tmpstr2, sizeof(tmpstr2)-1, "\nInstalled menuhax: '%s'.", tmpstr);
				}
				if(ret!=0)ret = 0;

				memset(headerstr, 0, sizeof(headerstr));
				snprintf(headerstr, sizeof(headerstr)-1, "menuhax_manager %s by yellows8.%s\n\nThis can install Home Menu haxx to the SD card, for booting the *hax payloads. Select an option with the below menu via the D-Pad/Circle-Pad, then press A. You can press the B button to exit. You can press the Y button at any time while at a menu like the below one, to toggle the screen being used by this app.\nThe theme menu options are only available when the cfg file exists on SD with an exploit installed which requires seperate theme-data files", VERSION, tmpstr2);

				display_menu(menu_entries, menucount, &menuindex, headerstr);

				if(menuindex==-1)break;

				consoleClear();

				switch(menuindex)
				{
					case 0:
						ret = install_menuhax(ropbin_filepath);

						if(ret==0)
						{
							log_printf(LOGTAR_ALL, "Install finished successfully. The following is the filepath which was just now written, you can delete any SD 'ropbinpayload_menuhax_*' file(s) which don't match the following exact filepath: '%s'. Doing so is completely optional. This only applies when menuhax >v1.2 was already installed where it was switched to a different system-version.\n", ropbin_filepath);
						}
						else
						{
							log_printf(LOGTAR_ALL, "Install failed: 0x%08x.\n", (unsigned int)ret);
						}
					break;

					case 1:
						ret = delete_menuhax();
						if(ret==0)
						{
							log_printf(LOGTAR_ALL, "Deletion finished successfully.\n");
						}
						else
						{
							log_printf(LOGTAR_ALL, "Deletion failed: 0x%08x.\n", (unsigned int)ret);
						}
					break;

					case 2:
						ret = setup_sdcfg();

						if(ret==0)
						{
							log_printf(LOGTAR_ALL, "Configuration finished successfully.\n");
						}
						else
						{
							log_printf(LOGTAR_ALL, "Configuration failed: 0x%08x.\n", (unsigned int)ret);
						}
					break;

					case 3:
						curscreen = menu_getcurscreen();
						menu_configscreencontrol(false, 1);
						gfxSet3D(true);

						ret = setup_imagedisplay();
						imagedisplay_previewimage(NULL);//Clear the top-screen framebuffer.
						gfxSet3D(false);

						if(ret==0)
						{
							log_printf(LOGTAR_ALL, "Configuration finished successfully.\n");
						}
						else
						{
							log_printf(LOGTAR_ALL, "Configuration failed: 0x%08x.\n", (unsigned int)ret);
						}
					break;

					case 4:
						log_printf(LOGTAR_ALL, "Installing custom-theme...\n");
						ret = sd2themecache("sdmc:/3ds/menuhax_manager/body_LZ.bin", "sdmc:/3ds/menuhax_manager/bgm.bcstm", 1);

						if(ret==0)
						{
							log_printf(LOGTAR_ALL, "Custom theme installation finished successfully.\n");
						}
						else
						{
							log_printf(LOGTAR_ALL, "Custom theme installation failed: 0x%08x. If you haven't already done so, you might need to enter the theme-settings menu under Home Menu, while menuhax is installed.\n", (unsigned int)ret);
						}
					break;

					case 5:
						ret = setup_builtin_theme();

						if(ret==0)
						{
							log_printf(LOGTAR_ALL, "Theme setup finished successfully.\n");
						}
						else
						{
							log_printf(LOGTAR_ALL, "Theme setup failed: 0x%08x.\n", (unsigned int)ret);
						}
					break;
				}

				if(ret==0)displaymessage_waitbutton();

				if(ret==0 && menuindex==3)menu_configscreencontrol(true, curscreen);
			}
		}
	}

	free(filebuffer);

	romfsExit();

	amExit();

	close_extdata();

	log_printf(LOGTAR_ALL, "\n");

	if(ret!=0)log_printf(LOGTAR_ALL, "An error occured. If this is an actual issue not related to user failure, please report this to here if it persists(or comment on an already existing issue if needed), with the file from SD '/3ds/menuhax_manager/menuhax_manager.log': https://github.com/yellows8/3ds_homemenuhax/issues\n");

	log_printf(LOGTAR_ALL, "Press the START button to exit.\n");

	log_shutdown();

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

