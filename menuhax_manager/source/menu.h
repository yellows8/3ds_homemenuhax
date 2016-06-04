void initialize_menu();
void menu_configscreencontrol(bool flag, int curscreen);
int menu_getcurscreen(void);

void display_menu(char **menu_entries, int total_entries, int *menuindex, char *headerstr);

void displaymessage_waitbutton();
Result displaymessage_prompt(const char *message, const char *keymsg);

