headerpath=menuhax_manager/source/modules/modules.h

rm -f $headerpath
rm -f "Makefile_modules_include"

echo "BUILDMODULES_COMMAND	:=	" >> Makefile_modules_include

for path in modules/*; do echo "void register_module_"$(basename "$path")"();" >> $headerpath; echo "include Makefile."$(basename "$path") >> Makefile_modules_include; echo "BUILDMODULES_COMMAND	:=	\$(BUILDMODULES_COMMAND) make -f Makefile "$(basename "$path")"_build --no-print-directory; " >> Makefile_modules_include; done
echo "" >> $headerpath
echo "void register_modules()" >> $headerpath
echo "{" >> $headerpath
for path in modules/*; do echo register_module_$(basename "$path")"();" >> $headerpath; done
echo "}" >> $headerpath
echo "" >> $headerpath

