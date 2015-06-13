#!/bin/bash

# This script builds the ROP address #define headers included via the gcc -include option in the Makefile.
# The tool from here is required: https://github.com/yellows8/ropgadget_patternfinder
# Usage: generate_menurop_addrs.sh {path}
# {path} must contain JPN and USA directories, which contain the following for each title-version: <v{titlever}>/*exefs/code.bin

mkdir -p menurop
mkdir -p menurop/USA
mkdir -p menurop/JPN

if [ ! -d "$1/JPN" ]; then
	echo "The \"$1/JPN\" directory doesn't exist."
	exit 1
fi

if [ ! -d "$1/USA" ]; then
	echo "The \"$1/USA\" directory doesn't exist."
	exit 1
fi

for dir in $1/JPN/*
do
	version=$(basename "$dir")
	version=${version:1}
	echo "JPN $version"
	ropgadget_patternfinder $dir/*exefs/code.bin --script=homemenu_ropgadget_script --baseaddr=0x100000 --patterntype=sha256 > "menurop/JPN/$version"

	if [[ $? -ne 0 ]]; then
		echo "ropgadget_patternfinder returned an error, output from it(which will be deleted after this):"
		cat "menurop/JPN/$version"
		rm "menurop/JPN/$version"
	fi
done

for dir in $1/USA/*
do
	version=$(basename "$dir")
	version=${version:1}
	echo "USA $version"
	ropgadget_patternfinder $dir/*exefs/code.bin --script=homemenu_ropgadget_script --baseaddr=0x100000 --patterntype=sha256 > "menurop/USA/$version"

	if [[ $? -ne 0 ]]; then
		echo "ropgadget_patternfinder returned an error, output from it(which will be deleted after this):"
		cat "menurop/USA/$version"
		rm "menurop/USA/$version"
	fi
done

