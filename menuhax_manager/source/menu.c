#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <3ds.h>

#include "log.h"

static bool menu_allowscreencontrol = true;
static int menu_curprintscreen = 0;
static PrintConsole menu_printscreen[2];

void initialize_menu()
{
	menu_allowscreencontrol = true;
	menu_curprintscreen = 0;
	consoleInit(GFX_TOP, &menu_printscreen[0]);
	consoleInit(GFX_BOTTOM, &menu_printscreen[1]);
	consoleSelect(&menu_printscreen[menu_curprintscreen]);
}

void menu_configscreencontrol(bool flag, int curscreen)
{
	if(curscreen)curscreen = 1;

	menu_allowscreencontrol = flag;
	menu_curprintscreen = curscreen;

	consoleClear();
	consoleSelect(&menu_printscreen[menu_curprintscreen]);
}

int menu_getcurscreen(void)
{
	return menu_curprintscreen;
}

void display_menu(char **menu_entries, int total_entries, int *menuindex, char *headerstr)
{
	int i;
	u32 redraw = 1;
	u32 kDown = 0;

	while(1)
	{
		gspWaitForVBlank();
		hidScanInput();

		kDown = hidKeysDown();

		if(redraw)
		{
			redraw = 0;

			consoleClear();
			log_printf(LOGTAR_ALL, "%s.\n\n", headerstr);

			for(i=0; i<total_entries; i++)
			{
				if(*menuindex==i)
				{
					log_printf(LOGTAR_ALL, "-> ");
				}
				else
				{
					log_printf(LOGTAR_ALL, "   ");
				}

				log_printf(LOGTAR_ALL, "%s\n", menu_entries[i]);
			}
		}

		if(kDown & KEY_B)
		{
			*menuindex = -1;
			return;
		}

		if(kDown & (KEY_DDOWN | KEY_CPAD_DOWN))
		{
			(*menuindex)++;
			if(*menuindex>=total_entries)*menuindex = 0;
			redraw = 1;

			continue;
		}
		else if(kDown & (KEY_DUP | KEY_CPAD_UP))
		{
			(*menuindex)--;
			if(*menuindex<0)*menuindex = total_entries-1;
			redraw = 1;

			continue;
		}

		if(kDown & KEY_Y)
		{
			gspWaitForVBlank();
			consoleClear();

			menu_curprintscreen = !menu_curprintscreen;
			consoleSelect(&menu_printscreen[menu_curprintscreen]);
			redraw = 1;
		}

		if(kDown & KEY_A)
		{
			break;
		}
	}
}

void displaymessage_waitbutton()
{
	log_printf(LOGTAR_ALL, "\nPress the A button to continue.\n");
	while(1)
	{
		gspWaitForVBlank();
		hidScanInput();
		if(hidKeysDown() & KEY_A)break;
	}
}

int displaymessage_prompt(const char *message, const char *keymsg)
{
	if(keymsg==NULL)keymsg = "A = Yes, B = No.";

	log_printf(LOGTAR_ALL, "%s\n%s\n\n", message, keymsg);
	while(1)
	{
		gspWaitForVBlank();
		hidScanInput();
		if(hidKeysDown() & KEY_A)return 0;
		if(hidKeysDown() & KEY_B)return 1;
	}
}

