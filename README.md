This is menuhax, exploits for the Nintendo 3DS Home Menu.

# Summary
When the Home Menu is starting up, it can load theme-data from the home-menu theme SD extdata. The exploits can be triggered from here. The ROP starts running at roughly the same time the LCD backlight gets turned on.

Although this triggers during Home Menu boot, this can't cause any true bricks: just remove the *SD card if any booting issues ever occur(or delete/rename the theme-cache extdata directory: http://3dbrew.org/wiki/Extdata). Note that this also applies when the ROP causes a crash(the installed exploit itself), like when the ROP is for a different version of Home Menu(this can also happen if you boot into a nandimage which has a different Home Menu version, but still uses the exact same SD data). In some(?) cases Home Menu crashes with this just result in Home Menu displaying the usual error dialog for system-applet crashes.

# Vulns
* themehax: The original vuln for this repo was discovered on December 22, 2014. This flaw was introduced with the Home Menu version which added support for themes: 9.0.0-X on Old3DS, v8.1 on JPN-New3DS. Old3DS JPN theme support was "added" 9.1.0-XJ. The release date for this exploit was September 25, 2015.
* shufflehax: The vuln for this was discovered on January 3, 2015. The shufflehax exploit itself was finally implemented in December 2015, it was finished on the 7th-8th. The release date for this exploit was on December 27, 2015, in US-time. https://events.ccc.de/congress/2015/Fahrplan/events/7240.html Exactly one week later from release-date would be exactly one year since the vuln was discovered. Theme-shuffling and this vuln were introduced with 9.3.0-X.

## Vuln used with themehax
Home Menu allocates a 0x2a0000-byte heap buffer using the ctrsdk heap code: offset 0x0 size 0x150000 is for the output decompressed data, offset 0x150000 size 0x150000 is for the input compressed data. Immediately after this buffer is a CTRSDK heap freemem memchunkhdr, successfully overwriting it results a crash(when the data written there is junk) in the CTRSDK heap memchunk handling code with the linked-lists.

The decompression code only has an input-size parameter, no output size parameter. Hence, the output size is not restricted/checked at all. Since the decompressed data is located before the compressed data, the buf overflow results in the input compressed data being overwritten first. Eventually this overflow will result in the input data actually being used by the decompression function being overwritten, which can later result in an error before the function ever writes to the CTRSDK memchunk-hdr(if the input compressed data doesn't workaround that).

## Vuln used with shufflehax
Hence the name, this is a vuln with theme-data loading for theme-shuffling. Home Menu does a file-read from extdata for loading the compressed input-theme-data, with a size field loaded from extdata ThemeManage. This size is not validated at all.

## Vuln fix sysupdate(s)
The 10.2.0-X update fixed the vuln with theme decompression(themehax).

The Home Menu code changes *just* added a "if(decompressed_size_from_lzheader > 0x150000){exit};" check after loading a theme, prior to decompression.

# Supported System Versions
Every version starting with v9.0 is supported unless mentioned otherwise, system-versions starting with 10.2.0-X are not supported with themehax(see above). The release-archive builds for shufflehax are only built for 10.2.0-X and 10.3.0-X.

The initial release archive only supported USA, EUR, and JPN. KOR builds are included in the release-archive starting with v2.0. TWN can't be supported currently. CHN isn't supported since the last Home Menu update(v7.0) was before themes even existed in Home Menu.

# Building
Just run "make defaultbuild", or even "make clean && make defaultbuild". For building ROP binaries which can be used for general homemenu ROP(like for use with Home Menu exploits in general), this can be used: "{make clean &&} make ropbins {options}". "defaultbuild" Builds with the default options, see the Makefile for the default options. "{...} make {options}" Can be used to build with your own options if you prefer.

If you don't want to use the prebuilt menurop(using the menurop_prebuilt is recommended), the menurop directories+files must be generated. "./generate_menurop_addrs.sh {path}". See the source of that script for details(this requires the Home Menu code-binaries).

The final built files are located under "finaloutput/".

Note that the compression done in .py is rather slow: this is why building all versions and such takes a while.

Build options:
* "ENABLE_RET2MENU=1" Just return from the haxx to the Home Menu code after writing to the framebufs.
* "CODEBINPAYLOAD=path" Code binary payload to load into the launched process(default is the system web-browser). This will be included in the theme-data itself.
* "LOADSDPAYLOAD=1" Enable loading a code binary from SD for loading into the launched process("/menuhax_payload.bin"). The total size of the code(including additional code prior to the binary from SD) loaded into the process is 0x4000-bytes. Therefore, the max size of the code binary from SD is a bit less than 0x3000-bytes.
* "BOOTGAMECARD=1" Reboot the system via NSS:RebootSystem to launch the gamecard(region-free). This is handled right after the ROP for LOADROPBIN, if that's even enabled. If GAMECARD_PADCHECK isn't used, the ROP will always execute this without executing the title-launch + takeover ROP.
* "USE_PADCHECK=val" When set, at the very start of the menu ROP it will check if the current HID PAD state is set to the specified value. When they match, it continues the ROP, otherwise it returns to the homemenu code. This is done before writing to the framebuffers.
* "LOADSDCFG_PADCHECK=1" When USE_PADCHECK was used, load a config file which overrides the value used for USE_PADCHECK, and can invert PADCHECK too if specified(see source code for details).
* "GAMECARD_PADCHECK=val" Similar to USE_PADCHECK except for BOOTGAMECARD: the BOOTGAMECARD ROP only gets executed when the specified HID PAD state matches the current one. After writing to framebufs the ROP will delay 3 seconds, then run this PADCHECK ROP.
* "EXITMENU=1" Terminate homemenu X seconds(see source) after getting code exec under the launched process.
* "ENABLE_LOADROPBIN=1" Load a homemenu ropbin then stack-pivot to it, see the Makefile HEAPBUF_ROPBIN_* values for the load-address. When LOADSDPAYLOAD isn't used, the binary is the one specified by CODEBINPAYLOAD, otherwise it's loaded from a filepath which is different for each build, see the Makefile for that. The binary size should be <=0x10000-bytes.
* "ENABLE_HBLAUNCHER=1" When used with ENABLE_LOADROPBIN, setup the additional data needed by the hblauncher payload.
* "MENUROP_PATH={path}" Use the specified path for the "menurop" directory, instead of the default one which requires running generate_menurop_addrs.sh. To use the prebuilt menurop headers included with this repo, the following can be used: "MENUROP_PATH=menurop_prebuilt".
* "THEMEDATA_PATH={*decompressed* regular theme body_LZ filepath}" Build hax with the specified theme, instead of using the "default theme" one. Also note that compression during building takes a *lot* longer with this. This option is *not* recommended, use the LOADOTHER_THEMEDATA option instead.
* "LOADOTHER_THEMEDATA=1" When doing RET2MENU, re-run the theme-loading Home Menu code with different extdata file-paths(BGM file-paths are not changed). This allows loading actual themes while menuhax is installed.
* "ENABLE_IMAGEDISPLAY=1" Instead of doing a DMA-copy to the top-screen framebuffers from other data in VRAM resulting in junk being displayed, DMA from data in this payload. Framebuffer format is the same as usual: 240x400 byte-swapped RGB8(http://3dbrew.org/wiki/GPU/External_Registers#Framebuffer_color_formats). If 3D stereoscopy isn't used by the image, the 3D-right image should be the same as the 3D-left. The original "data in this payload" is just the end of the payload, with the data copied from VRAM+0(which is where the framebuf data comes from when ENABLE_IMAGEDISPLAY isn't used).
* "ENABLE_IMAGEDISPLAY_SD=1" Only used if ENABLE_IMAGEDISPLAY was specified. Overwrite the raw image-display data in the payload, with the data from SD "/menuhax_imagedisplay.bin", if the data from SD is loaded successfully. The format is the same described above. The first 0x46500-bytes are for the 3D-left, the 0x46500-bytes after that are for the 3D-right. The size of this file on SD should be 0x8ca00-bytes(0x46500*2), but if it's smaller only part of the image-data in this payload will be overwritten. Note that the manager app includes functionality for handling this file.

Building the menuhax_manager app requires zlib, handled the same way as hbmenu. Lodepng(https://github.com/lvandeve/lodepng) is also required: you must manually create a "menuhax_manager/lodepng/" directory, which contains the following(these can be symlinks for example): "lodepng.c" and "lodepng.h".

Before building menuhax(_manager), you must run setup_modules.sh at least once. You won't need to run the script again unless the contents of the "modules" directory changes, or if the "setup_modules.sh" script changes.

# Usage
Just boot the system, the haxx/initial-ROP will automatically trigger when Home Menu loads the theme-data from the cache in SD extdata. This happens when the Home Menu process is starting up. Prior to v2.0 Home Menu attempted theme-loading when returning from the power-off screen, however since Home Menu state is finally proper now with v2.0 that doesn't happen anymore. Said process boot can be triggered on Old3DS-only by entering a system-applet then leaving it. Hardware-reboot via System Settings for example has a similar affect too.

When the ROP returns from the haxx to running the actual Home Menu code, such as when USE_PADCHECK is used where the current PAD state doesn't match the specified state, with the default build options Home Menu will attempt to load the theme from the seperate theme-cache files. If there's no theme available, the "default-theme" one will be used.

With the release archive, you have to hold down the L button while Home Menu is booting(at the time the ROP checks for it), in order to boot into the **hax payload. Otherwise, Home Menu will boot like normal. This is the default PAD-trigger configuration.

The user can override the default PAD-trigger with multiple configuration options in the menuhax_manager app. The data for this is stored in SD file "/menuhax_padcfg.bin".

The ROP does the following:
* 1) Mount SD archive.
* 2) Restore Home Menu state to what it was pre-hax, and setup stack/etc for returning to the actual Home Menu code if needed later.
* 3) Setup the memory + string ptrs for the filepaths used with LOADOTHER_THEMEDATA, when that option is enabled(which it is by default).
* 4) Load the PAD sdcfg when LOADSDCFG_PADCHECK is enabled(which is the default).
* 5) Check PAD, if it's enabled with USE_PADCHECK(which it is with the release archive). On mismatch it will return to executing the actual Home Menu code.
* 6) Overwrite framebuffer data.
* 7) Run the actual main ROP.

Right before it jumps to executing the loaded ropbin, this delays 3-seconds. This helps with **hax payload booting not failing as much with this.

# Installation
To install the exploit for booting the **hax payload, you must use the menuhax_manager app. You must already have a way to boot into the payload for running this app(which can include menuhax if it's already setup):
http://3dbrew.org/wiki/Homebrew_Exploits    
Before using HTTP, the app will first try to load the payload(https://smealum.github.io/3ds/) from SD "/menuhaxmanager_input_payload.bin", then continue to use HTTP if loading from SD isn't successful. Actually using this SD payload is not recommended for end-users when HTTP download works fine. The input payload from SD is basically just copied to the ropbin file used by menuhax, where only the first 0x10000-bytes are written(only the first 0x10000-bytes get loaded by menuhax, anything after that doesn't matter). Hence, the input payload must be a ropbin file, not otherapp(https://smealum.github.io/3ds/). Hence, you can't use **hax payload pre-v2.5 starting with menuhax_manager v2.0 unless you already have the ropbin file for it(which would have to be located at the SD input-payload filepath).  

If you haven't already done so before, you may have to enter the Home Menu theme-settings so that Home Menu can create the theme extdata, prior to installing menuhax.

Versions >v1.2 uses a seperate menuropbin path for each menuhax build. <=v1.2 used the same filepath for all builds, rendering menuhax unusable for multiple system-versions/etc with the same SD card without changing that file(like with booting into SD-nandimages, for example). The app versions >v1.2 delete the old menuropbin file used by <=v1.2.

If you have the X button pressed while selecting the "Install" app option, **hax payload setup will be skipped. Normally this isn't needed. Doing this would result in only the extdata being setup/updated for menuhax.

This app uses code based on code from the following repos: https://github.com/yellows8/3ds_homemenu_extdatatool https://github.com/yellows8/3ds_browserhax_common  
Whenever the Home Menu version installed on your system changes where the installed exploit is for a different version, or when you want to update the **hax payload, you must run the installer again. For this you can do the following: you can remove the SD card before booting the system, then once booted insert the SD card then boot into the **hax payload via a different method(http://3dbrew.org/wiki/Homebrew_Exploits).

This app can setup an image for displaying on the main-screen when the menuhax triggers, if you use the app option for that. Using this is highly recommended(in some cases **hax payload booting may be more successful with this than without it). When the file for this isn't setup, junk will be displayed on the top-screen(from elsewhere in VRAM). The image can be either be the default one, or from SD. The input PNG for this is located at SD "/3ds/menuhax_manager/imagedisplay.png". The PNG dimensions must be either 800x240 or 240x800. The first half of the image(in terms of pixels) is for 3D-left, the rest is for the 3D-right. The 3D-right should be same as 3D-left if no stereoscopy is used by the image. See also #26. See the build-options section above regarding ENABLE_IMAGEDISPLAY_SD for the filepath where the actual raw image used by menuhax is stored on SD, if you need that.

The hax can be deleted by menuhax_manager with the app option for that. Another way to only "remove" the menuhax(this shouldn't be used unless you can't boot the menuhax_manager), is to just select the "no-theme" option in the Home Menu theme settings. Then restart Home Menu / reboot your system. Then, you can select any theme you want under Home Menu theme-settings if want to do so. See the "Summary" section if you have issues with Home Menu failing to boot.

If you really want to build a NCCH version of the installer, use the same permissions as 3ds_homemenu_extdatatool, with the same data on SD card as from the release archive. Access to the HTTPC service, and access to an AM service for AM_ListTitles, is required. Due to AM access being required with >v1.2, this app is not usable with regular ninjhax v1.x without additional hax.

# Themes
Starting with v2.0, you can now use menuhax with an actual theme you want. After installing v2.0(nothing higher), you have to enter the Home Menu theme-settings menu first, so that it can create the seperate extdata files. Under the menuhax_manager, there are menu options for installing custom-themes with menuhax already setup, and for setting up one of the Home Menu built-in "Basic: {color}" themes as a "custom-theme".

Currently menuhax_manager doesn't support installing multiple themes from multiple input SD files, when shufflehax is setup.

Under Home Menu theme-settings:  
The only theme-change you can do without menuhax being disabled, is selecting a DLC theme.
* themehax: Any theme you select must be a DLC-theme as a regular theme. Theme shuffling isn't usable.
* shufflehax: You must select exactly two DLC-themes via theme-shuffling, no regular-theme. You can't successfully select the same DLC-theme twice. Normally Home Menu won't allow you to select only one theme for theme-shuffling, but in this case it does, do not try this because Home Menu will just reset the theme-data settings in this case.

When you're selecting a "Basic: {color}" theme with the menuhax_manager option mentioned above, you can keep the X button pressed while selecting the theme to dump the theme-data to '/3ds/menuhax_manager/'. This isn't needed unless you want to use that theme-data with other tools/etc. Note that this menu in menuhax_manager is only usable when the app is running via **hax payload >=v2.0.

If you want to revert the theme to "no-theme" with menuhax still installed, you can keep the X button pressed while selecting the menuhax_manager "Delete" menu option. Then select the menuhax_manager "Install" option. After doing so, you have to enter the Home Menu theme-settings menu again if you want to setup more themes later.

With menuhax setup, Home Menu uses seperate theme-cache extdata filenames for everything except for BGM. These seperate filenames are the same as the original except that the first character is replaced with 'y'(see also source code). As a result, other custom-theme installation tools will not be compatible with installing to these seperate files, without an update for them to support this. Using those tools without being updated for this, will result in menuhax being overwritten with the custom-theme.

For custom-theme installation, the theme-data must be located at SD "/3ds/menuhax_manager/body_LZ.bin". If used, the BGM must be located at SD "/3ds/menuhax_manager/bgm.bcstm".

# Credits
* The original vuln for themehax was, as said on this page(https://smealum.github.io/3ds/), "exploited jointly by yellows8 and smea". The payload.py script was originally written by smea, this is where the actual generation for the compressed data which triggers the buf-overflow is done.
* menuhax_manager uses lodepng: https://github.com/lvandeve/lodepng
* Graphics(#26): @NaxiD for the menuhax_manager icon and @LouchDaishiteru for the default haxx boot splash-screen.

