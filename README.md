# menuhax is obsolete.

This is menuhax, exploits for the Nintendo 3DS Home Menu.

# Summary
These exploits trigger during Home Menu startup.

Although this triggers during Home Menu boot, this can't cause any true bricks: just remove the \*SD card if any booting issues ever occur(or delete/rename the main Home Menu [extdata](https://www.3dbrew.org/wiki/Extdata) directory). Note that this also applies when the ROP causes a crash(the installed exploit itself), like when the ROP is for a different version of Home Menu(this can also happen if you boot into a nandimage which has a different Home Menu version, but still uses the exact same SD data). In some(?) cases Home Menu crashes with this just result in Home Menu displaying the usual error dialog for system-applet crashes.

# Old3DS return-to-menu
On Old3DS with applications which trigger a firmlaunch due to requiring more memory for the APPLICATION memregion, pressing the HOME button will result in a hang due to Home Menu crashing with menuhax installed. This include Super Smash Bros, Monster Hunter as well as Pokemon Sun and Moon.

The only way this could ever be resolved is with a Home Menu vuln which doesn't involve linearmem pre-\*hax-payload, unlike all of the ones used in this repo publicly currently.

# Vulns
* themehax: The original vuln for this repo was discovered on December 22, 2014. This flaw was introduced with the Home Menu version which added support for themes: 9.0.0-X on Old3DS, v8.1 on JPN-New3DS. Old3DS JPN theme support was "added" 9.1.0-XJ. The release date for this exploit was September 25, 2015.
* shufflehax: The vuln for this was discovered on January 3, 2015. The shufflehax exploit itself was finally implemented in December 2015, it was finished on the 7th-8th. The release date for this exploit was on December 27, 2015, in US-time. https://events.ccc.de/congress/2015/Fahrplan/events/7240.html Exactly one week later from release-date would be exactly one year since the vuln was discovered. Theme-shuffling and this vuln were introduced with 9.3.0-X.
* sdiconhax: For vuln details, see source and [here](https://www.3dbrew.org/wiki/3DS_Userland_Flaws). This was exploited in June 2016.
* bossbannerhax: For vuln details, see source and [here](https://www.3dbrew.org/wiki/3DS_Userland_Flaws). This was exploited in December 2016.

## Vuln used with themehax
Home Menu allocates a 0x2a0000-byte heap buffer using the ctrsdk heap code: offset 0x0 size 0x150000 is for the output decompressed data, offset 0x150000 size 0x150000 is for the input compressed data. Immediately after this buffer is a CTRSDK heap freemem memchunkhdr, successfully overwriting it results a crash(when the data written there is junk) in the CTRSDK heap memchunk handling code with the linked-lists.

The decompression code only has an input-size parameter, no output size parameter. Hence, the output size is not restricted/checked at all. Since the decompressed data is located before the compressed data, the buf overflow results in the input compressed data being overwritten first. Eventually this overflow will result in the input data actually being used by the decompression function being overwritten, which can later result in an error before the function ever writes to the CTRSDK memchunk-hdr(if the input compressed data doesn't workaround that).

## Vuln used with shufflehax
Hence the name, this is a vuln with theme-data loading for theme-shuffling. Home Menu does a file-read from extdata for loading the compressed input-theme-data, with a size field loaded from extdata ThemeManage. This size is not validated at all.

## Vuln fix sysupdate(s)
* The 10.2.0-X sysupdate [fixed](https://www.3dbrew.org/wiki/10.2.0-28) the vuln with theme decompression(themehax).
* The 10.6.0-X sysupdate [fixed](https://www.3dbrew.org/wiki/10.6.0-31) shufflehax.
* The 11.1.0-X sysupdate [fixed](https://www.3dbrew.org/wiki/11.1.0-34) sdiconhax.
* The 11.3.0-X sysupdate [fixed](https://www.3dbrew.org/wiki/11.3.0-36) bossbannerhax.

# Usage notes for sdiconhax
With sdiconhax installed, when Home Menu does a normal boot all writes to extdata SaveData.dat are blocked. This is only for normal boots, not when \*hax payload was booted *from* menuhax. This *had* to be blocked because the haxx data was getting reset every time Home Menu wrote to this file. This blocks *anything* from being done with this file, hence you can't run menuhax-install/deletion with this unless you booted \*hax payload from menuhax.

Also note that you can't do/use any of the following without Home Menu entering a crash-boot-loop: exit from hbmenu for returning to Home Menu, menuhax-thread hax-payload boot(due to restarting homemenu), or returning from any system-applets on Old3DS(web-browser etc). This will also happen when a regular-application crashes when trying to return to Home Menu. Basically, anything that causes the Home Menu process to restart.

If you use the menuhax-thread keycombo, the non-icon-data areas of SaveData.dat will be written to FS prior to terminating the process, however see above regarding this thread. This is mostly useful for when you changed theme-settings. Icon-related data is not saved because the written data would be reset anyway, and the haxx didn't trigger properly.

Due to the above, you can't change anything related to SD icon layout(including presents) and have it persist after a Home Menu process restart. You can only do so when sdiconhax isn't installed(uninstall, change layout, then install again). Deleting/renaming the main Home Menu extdata directory will of course reset this SD icon layout data.

If you enter the power-off screen then return to Home Menu, the icon layout will be reset with presents however this will not be saved to FS.

Do not change the system language with System Settings with sdiconhax installed. If you do so, you will have to delete the Home Menu extdata as mentioned in the Summary section above.

# Usage notes for bossbannerhax
This is used for system-version v11.1-v11.2.

This does not trigger during Home Menu boot. This triggers when the Face Raiders icon is selected by the user, which triggers loading the exbanner data(Face Raiders is just the ideal target title for this among the system titles with exbanner-usage enabled). The usual PAD-config for actually running it still applies.

Normal {return to homemenu code} is not supported with bossbannerhax. It will terminate Home Menu via svcExitProcess instead, resulting in the usual crash message. This doesn't matter much since the exploit only triggers when selecting the icon listed above.

For deleting bossbannerhax you should use menuhax_manager. But if you really want to delete it manually, even though face-raiders BOSS data(non-hax-data) won't be completely deleted, you can manually delete the Face Raiders extdata(you could even do this with System Settings if you want). Nothing else on SD is required for bossbannerhax deletion.

For installing bossbannerhax, either ctr-httpwn >=v1.2(with bosshaxx) must be already active, or the system must be running "CFW" with sigchecks patched.

# Supported System Versions
As of menuhax v3.2, system-versions 9.0.0-X..11.2.0-X are all supported. During installation it automatically detects which exploit to install. See also the above sections. Note that as of November 2016 [bossbannerhax](https://www.3dbrew.org/wiki/3DS_Userland_Flaws) was the last known Home Menu vuln.

The initial release archive only supported USA, EUR, and JPN. TWN and CHN aren't supported currently. KOR builds which are *actually* usable are included starting with v3.0, via sdiconhax for 9.6.0-X..11.0.0-X(the theme-data exploit KOR builds were removed since themes aren't actually usable with KOR).

# Building
See Building.md.

# Usage
Just boot the system, the haxx/initial-ROP will automatically trigger while Home Menu loads. Prior to v2.0 Home Menu attempted theme-loading when returning from the power-off screen, however since Home Menu state is finally proper now with v2.0 that doesn't happen anymore. Home Menu process boot can be triggered on Old3DS-only by entering a system-applet then leaving it. Hardware-reboot via System Settings for example has a similar affect too.

With the release archive the default PAD-trigger configuration is that you have to hold down the L button while Home Menu is booting, in order to boot into the \*hax payload. Otherwise, Home Menu will boot like normal. The user can override the default PAD-trigger with multiple configuration options in the menuhax_manager app. The data for this is stored in SD file "/menuhax/menuhax_padcfg.bin".

Right before it jumps to executing the loaded ropbin, this delays with a default of 3-seconds. This helps with \*hax payload booting not failing as much with this. This can be adjusted in the menuhax_manager configuration menu.

## menuhax thread
If the menuhax-thread options are setup via the menuhax_manager configuration menu(specifically the PAD config), during a normal boot to Home Menu menuhax will start a new thread which runs with just ROP.

This thread executes a loop. First it runs svcSleepThread, delaying with the user-specified value. Then it verifies that Home Menu is active by comparing the GSPGPU service session handle with 0x0. Then it checks if the pressed PAD buttons match the value specified in config. If so, the config file is updated so that menuhax automatically boots \*hax payload on next boot, then svcExitProcess is executed so that Home Menu restarts.

This is not usable with bossbannerhax due to no ret2menu.

# Installation
To install menuhax you must use the menuhax_manager app. You must already have a way to boot into the \*hax payload for running this app(which can include menuhax if it's already setup):
https://www.3dbrew.org/wiki/Homebrew_Exploits    

Before using HTTP, the app will first try to load the input [payload](https://smealum.github.io/3ds/) from SD "/menuhax/menuhaxmanager_input_payload.bin", then continue to use HTTP if loading from SD isn't successful. Actually using this SD payload is not recommended for end-users when HTTP download works fine. The input payload from SD is basically just copied to the ropbin file used by menuhax, where only the first 0x10000-bytes are written(only the first 0x10000-bytes get loaded by menuhax, anything after that doesn't matter). Hence, the input payload must be a ropbin file, not [otherapp](https://smealum.github.io/3ds/). Hence, you can't use \*hax payload pre-v2.5 starting with menuhax_manager v2.0 unless you already have the ropbin file for it(which would have to be located at the SD input-payload filepath).  

If you haven't already done so before, you may have to enter the Home Menu theme-settings so that Home Menu can create the theme extdata, prior to running menuhax_manager(for USA/EUR/JPN regions).

Versions >v1.2 uses a seperate menuropbin path for each menuhax build. <=v1.2 used the same filepath for all builds, rendering menuhax unusable for multiple system-versions/etc with the same SD card without changing that file(like with booting into SD-nandimages, for example). The app versions >v1.2 delete the old menuropbin file used by <=v1.2.

During installation there's an option for skipping \*hax payload setup. Normally this isn't needed. Doing this would result in only menuhax itself being setup.

Whenever the Home Menu version installed on your system changes where the installed exploit is for a different version, or when you want to update the \*hax payload, you must run the installation again. For the former you can do the following: you can remove the SD card before booting the system, then once booted insert the SD card then boot into the \*hax payload via a different method(https://www.3dbrew.org/wiki/Homebrew_Exploits).

## System-version override
During installation there's an option to override what system-version is used for installing. This is only enabled if there's a "enable_sysveroverride_option.txt" file(contents don't matter) detected in the same directory as menuhax_manager.3dsx(normally SD "/3ds/menuhax_manager/"). This should only ever be used if you're installing a different Home Menu version later(see the Summary section regarding Home Menu version mismatch).

## Splash-screen
This app can setup an image for displaying on the screens when menuhax triggers, if you use the app option for that. Using this is highly recommended(in some cases \*hax payload booting may be more successful with this than without it). When the file for this isn't setup, junk will be displayed on the top-screen(from elsewhere in VRAM). The input image can be either be the default one, or from SD.  

The input PNGs for this are located at SD directory "{CurrentWorkingDirectory}/splashscreen/"(all PNGs stored under "{CurrentWorkingDirectory}" are automatically moved into this splashscreen directory if they exist). "CurrentWorkingDirectory" is normally "/3ds/menuhax_manager" unless it's running from elsewhere. The PNG dimensions must be either LENx240 or 240xLEN, where LEN is one of: 400, 800, or 1120. See the menuhax_manaager/imagedisplay_example_\*.png files, in this repo. See also #26.

## Deletion
The hax can be deleted by menuhax_manager with the app option for that.  

If you have menuhax installed on USA/EUR/JPN <=10.5.0-30, another way to only "remove" menuhax(this shouldn't be used unless you can't boot the menuhax_manager), is to just select the "no-theme" option in the Home Menu theme settings. Then restart Home Menu / reboot your system. Then, you can select any theme you want under Home Menu theme-settings if want to do so.

See the "Summary" section if you have issues with Home Menu failing to boot, or if you want to manually remove menuhax.

## Ninjhax v1.x
Due to AM access / etc being required with >v1.2, this app is not usable with regular ninjhax v1.x without additional hax. Use \*hax >=v2.x instead.

# Themes
The below only applies for USA/EUR/JPN <=10.5.0-X. The theme-install menus are disabled in menuhax_manager if menuhax was last installed with a non-theme-data exploit.

Starting with v2.0, you can now use menuhax with an actual theme you want. After installing v2.0(nothing higher), you have to enter the Home Menu theme-settings menu first, so that it can create the seperate extdata files. Under the menuhax_manager, there are menu options for installing custom-themes with menuhax already setup, and for setting up one of the Home Menu built-in "Basic: {color}" themes as a "custom-theme".

Currently menuhax_manager doesn't support installing multiple themes from multiple input SD files, when shufflehax is setup.

Under Home Menu theme-settings:  
The only theme-change you can do without menuhax being disabled, is selecting a DLC theme.
* themehax: Any theme you select must be a DLC-theme as a regular theme. Theme shuffling isn't usable.
* shufflehax: You must select exactly two DLC-themes via theme-shuffling, no regular-theme. You can't successfully select the same DLC-theme twice. Normally Home Menu won't allow you to select only one theme for theme-shuffling, but in this case it does, do not try this because Home Menu will just reset the theme-data settings in this case.

When you're selecting a "Basic: {color}" theme with the menuhax_manager option mentioned above, there's an option to dump the theme-data to {CurrentWorkingDirectory}. "CurrentWorkingDirectory" is normally "/3ds/menuhax_manager" unless it's running from elsewhere. This isn't needed unless you want to use that theme-data with other tools/etc. Note that this menu in menuhax_manager is only usable when the app is running via \*hax payload >=v2.0.

If you want to revert the theme to "no-theme" with menuhax still installed, you can select the menuhax_manager "Delete" menu option, then select the option for this. After doing so, you have to enter the Home Menu theme-settings menu again if you want to setup more themes later.

With menuhax setup, Home Menu uses seperate theme-cache extdata filenames for everything except for BGM. These seperate filenames are the same as the original except that the first character is replaced with 'y'(see also source code). As a result, other custom-theme installation tools will not be compatible with installing to these seperate files, without an update for them to support this. Using those tools without being updated for this, will result in menuhax being overwritten with the custom-theme.

For custom-theme installation, the theme-data must be located at SD "{CurrentWorkingDirectory}/body_LZ.bin". If used, the BGM must be located at SD "{CurrentWorkingDirectory}/bgm.bcstm". "CurrentWorkingDirectory" is normally "/3ds/menuhax_manager" unless it's running from elsewhere.

If Home Menu is already using a theme with BGM, before installing a custom theme using BGM, you must first switch to a non-BGM theme and run menuhax_manager again. If this theme switch wasn't done via Home Menu itself, the Home Menu process must be restarted(like with a system-reboot for example). This applies to all custom theme installation tools, not just menuhax_manager.

# Credits
* This app uses code based on code from the following repos: https://github.com/yellows8/3ds_homemenu_extdatatool  
* The original vuln for themehax was, as said on this page(https://smealum.github.io/3ds/), "exploited jointly by yellows8 and smea". The payload.py script was originally written by smea, this is where the actual generation for the compressed data which triggers the buf-overflow is done.
* The system-version override menu code is based on the code from [sploit_installer](https://github.com/smealum/sploit_installer).
* menuhax_manager uses lodepng: https://github.com/lvandeve/lodepng
* menuhax_manager uses minizip for handling .zip.
* Graphics(#26): @NaxiD for the menuhax_manager icon and @LouchDaishiteru for the default haxx boot splash-screen.

