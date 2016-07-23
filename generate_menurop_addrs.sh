#!/bin/bash

# This script builds the ROP address #define headers included via the gcc -include option in the Makefile.
# The tool from here is required: https://github.com/yellows8/ropgadget_patternfinder
# Usage: generate_menurop_addrs.sh {path} <path to yellows8github/3ds_ropkit repo>
# {path} must contain JPN, USA, and EUR directories, which contain the following for each title-version: <v{titlever}>/*exefs/code.bin

homemenudir=$1
ropkitpath=$2

mkdir -p menurop

function findthemestr_filepath
{
	rawaddr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --stride=0x1 --patterndata=$3 --patternsha256size=$4 "--plainout=" --printrawval`
	if [[ $? -eq 0 ]]; then
		printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=datacmp --patterndata=$rawaddr "--plainout=#define $2 "`

		if [[ $? -eq 0 ]]; then
			echo "$printstr" >> "menurop/$1/$version"
		fi
	fi
}

function process_region
{
	mkdir -p "menurop/$1"

	if [ ! -d "$homemenudir/$1" ]; then
		echo "The \"$homemenudir/$1\" directory doesn't exist."
		exit 1
	fi

	for dir in $homemenudir/$1/*
	do
		version=$(basename "$dir")
		version=${version:1}
		echo "$1 $version"

		ropgadget_patternfinder $dir/*exefs/code.bin --script=homemenu_ropgadget_script --baseaddr=0x100000 --patterntype=sha256 > "menurop/$1/$version"
		if [[ $? -ne 0 ]]; then
			echo "ropgadget_patternfinder returned an error, output from it(which will be deleted after this):"
			cat "menurop/$1/$version"
			rm "menurop/$1/$version"
		else
			
			$ropkitpath/generate_ropinclude.sh $dir/*exefs/code.bin $ropkitpath >> "menurop/$1/$version"
			if [[ $? -ne 0 ]]; then
				echo "3ds_ropkit generate_ropinclude.sh returned an error, output from it(which will be deleted after this):"
				cat "menurop/$1/$version"
				rm "menurop/$1/$version"
			else
				printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --patterndata=34a5207f79d4bf19d84f30b515545dd573012961fa1f73140203b91c5c4388b8 --patternsha256size=0x1c "--plainout=#define ROP_LOADR4_FROMOBJR0 "`

				if [[ $? -eq 0 ]]; then
					echo "$printstr" >> "menurop/$1/$version"
				fi

				printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --patterndata=52e0aa6d5ac4cda766a2b4d0d0702c2d756d4df5d4a57c43d35d64cce3f85881 --patternsha256size=0x10 "--plainout=#define ROP_LDRR1_FROMR5ARRAY_R4WORDINDEX "`

				if [[ $? -eq 0 ]]; then
					echo "$printstr" >> "menurop/$1/$version"
				fi

				printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --patterndata=17fded5d443cfddad96c2020b28745000374792c1d4f594390171369e785fadb --patternsha256size=0x28 --dataload=0x2c "--plainout=#define ORIGINALOBJPTR_BASELOADADR "`

				#--patterndata=bf686cf1bbadd44648618925d9d8e83bb54cff8f99cb7285bddaea994ea72d45 --patternsha256size=0x14 "--plainout=#define APT_SendParameter "

				if [[ $? -eq 0 ]]; then
					echo "$printstr" >> "menurop/$1/$version"
				fi

				printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --patternsha256size=0x30 --patterndata=458a4883ac20d00cced6f64adb8de336a9bc568793a7c3e1d64fefa2dad70aa8 "--plainout=#define ROP_PUSHR4R8LR_CALLVTABLEFUNCPTR "`

				if [[ $? -eq 0 ]]; then
					echo "$printstr" >> "menurop/$1/$version"
				fi

				printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --patterndata=36ef6f0a979e4486db2bb1bd060b63e69331712df98dda78fb3f122a47683367 --patternsha256size=0x30 "--plainout=#define NSS_LaunchTitle "`

				if [[ $? -eq 0 ]]; then
					echo "$printstr" >> "menurop/$1/$version"
				fi

				printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --patterndata=a65851d28ca7254df126e2e40a5ca17a349b03cca328e6d548eee4a18cff7233 --patternsha256size=0x20 "--plainout=#define NSS_RebootSystem "`

				if [[ $? -eq 0 ]]; then
					echo "$printstr" >> "menurop/$1/$version"
				fi

				printstr=`ropgadget_patternfinder $dir/*exefs/code.bin --baseaddr=0x100000 --patterntype=sha256 --patterndata=67593efa79a84116be6ef1302e4472bd91fdb8002f78bfa724a795a05250a260 --patternsha256size=0x18 "--plainout=#define GSPGPU_Shutdown "`

				if [[ $? -eq 0 ]]; then
					echo "$printstr" >> "menurop/$1/$version"
				fi

				findthemestr_filepath "$1" "FILEPATHPTR_THEME_SHUFFLE_BODYRD" "810b64901687c68a2685b1e39b9a2660ed745eefcff85623b0303a95bd29a372" "0x30"
				findthemestr_filepath "$1" "FILEPATHPTR_THEME_REGULAR_THEMEMANAGE" "1bcc1fb0802e1bce26f4a8a9a2492fb85e47f40de6eea2b3380cafe08e1f80ea" "0x2e"
				findthemestr_filepath "$1" "FILEPATHPTR_THEME_REGULAR_BODYCACHE" "1e677c0cec6485761901d967ed7677cda1b4cf6571de439fad1e9236f975e6a3" "0x2a"
				findthemestr_filepath "$1" "FILEPATHPTR_THEME_SHUFFLE_THEMEMANAGE" "080925b250c4a0cf6f2b290d58b85412c4bb79ace0f8be1fd7404f283bb0d0d1" "0x38"
				findthemestr_filepath "$1" "FILEPATHPTR_THEME_SHUFFLE_BODYCACHE" "434e73d1416c87ff3a9305b5aa66c5e765a55a3d8fbdc5d0f3061a725b4497a4" "0x34"
			fi
		fi
	done
}

process_region "JPN"
process_region "USA"
process_region "EUR"
process_region "KOR"

cp -R menurop/* menurop_prebuilt/

