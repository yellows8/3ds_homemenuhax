# Usage: <script path> <menuhax_manager log file> {old3ds|new3ds}
# This is for generating the entries in sdiconhax.c sdiconhax_addrset_builtinlist[].

textline=$(grep linearaddr $1)

systext="LINEARMEMSYS_BASE_RELOFFSET_NEW3DS("
if [ "$2" == "old3ds" ]
then
	systext="LINEARMEMSYS_BASE_RELOFFSET_OLD3DS("
fi

echo -e "\t{"
echo -e "\t\t.region = CFG_REGION_TODO,"
echo -e "\t\t.language = CFG_LANGUAGE_TODO,"
echo ""
echo -n -e "\t\t.linearaddr_savedatadat = $systext" && echo -n "$textline" | cut "-d=" -f2 | cut "-d," -f1 | tr -d '\n' && echo "),"
#echo -n -e "\t\t.linearaddr_target_objectslist_buffer = $systext" && echo -n "$textline" | cut "-d=" -f3 | cut "-d," -f1 | tr -d '\n' && echo "),"
echo -n -e "\t\t.original_objptrs = {$systext" && echo -n "$textline" | cut "-d=" -f4 | cut "-d," -f1 | tr -d '\n'
echo -n -e "), $systext" && echo -n "$textline" | cut "-d=" -f5 | cut "-d," -f1 | tr -d '\n' && echo ")}"
echo -e "\t}"
