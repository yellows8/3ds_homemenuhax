#!/bin/bash

echo "v9.6:"
./menuhax_locateaddrs.sh $1/USA/v16404/*exefs/code.bin
echo -n -e "\n"

echo "v9.5:"
./menuhax_locateaddrs.sh $1/USA/v15360/*exefs/code.bin
echo -n -e "\n"

echo "v9.4:"
./menuhax_locateaddrs.sh $1/USA/v14336/*exefs/code.bin
echo -n -e "\n"

echo "v9.3:"
./menuhax_locateaddrs.sh $1/USA/v13330/*exefs/code.bin
echo -n -e "\n"

echo "v9.2:"
./menuhax_locateaddrs.sh $1/USA/v12288/*exefs/code.bin
echo -n -e "\n"

echo "v9.0:"
./menuhax_locateaddrs.sh $1/USA/v11272/*exefs/code.bin
echo -n -e "\n"

echo "v9.0j:"
./menuhax_locateaddrs.sh $1/JPN/v13313/*exefs/code.bin
echo -n -e "\n"

echo "v9.1j:"
./menuhax_locateaddrs.sh $1/JPN/v14336/*exefs/code.bin
echo -n -e "\n"

