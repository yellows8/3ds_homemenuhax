#!/bin/bash

# This script builds the ROP address #define headers included via the gcc -include option in the Makefile.
# The tool from here is required: https://github.com/yellows8/ropgadget_patternfinder
# Usage: generate_menurop_addrs.sh {path}
# {path} must contain JPN, USA, and EUR directories, which contain the following for each title-version: <v{titlever}>/*exefs/code.bin

homemenudir=$1

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
			findthemestr_filepath "$1" "FILEPATHPTR_THEME_SHUFFLE_BODYRD" "810b64901687c68a2685b1e39b9a2660ed745eefcff85623b0303a95bd29a372" "0x30"
			findthemestr_filepath "$1" "FILEPATHPTR_THEME_REGULAR_THEMEMANAGE" "1bcc1fb0802e1bce26f4a8a9a2492fb85e47f40de6eea2b3380cafe08e1f80ea" "0x2e"
			findthemestr_filepath "$1" "FILEPATHPTR_THEME_REGULAR_BODYCACHE" "1e677c0cec6485761901d967ed7677cda1b4cf6571de439fad1e9236f975e6a3" "0x2a"
			findthemestr_filepath "$1" "FILEPATHPTR_THEME_SHUFFLE_THEMEMANAGE" "080925b250c4a0cf6f2b290d58b85412c4bb79ace0f8be1fd7404f283bb0d0d1" "0x38"
			findthemestr_filepath "$1" "FILEPATHPTR_THEME_SHUFFLE_BODYCACHE" "434e73d1416c87ff3a9305b5aa66c5e765a55a3d8fbdc5d0f3061a725b4497a4" "0x34"
		fi
	done
}

process_region "JPN"
process_region "USA"
process_region "EUR"
process_region "KOR"

