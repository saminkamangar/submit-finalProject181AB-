#! /bin/bash

if [[ $# != 1 ]]; then
	echo "usage: $0 <someimage>"
	exit
else
	IMGNAME="$1"
	FORMAT=${1##*.}
fi

OLDDIR="$PWD"
DIR=`find -name edge.c`
DIR=${DIR#*/}
DIR=${DIR%/*}
ln -f "$IMGNAME" "$DIR"
cd "$DIR"

echo "(1) Converting image to text format..."
$PWD/pre.py "$IMGNAME" > tmp1

echo "(2) Applying edge detection algorithm in C..."
#time $PWD/process tmp1 > tmp2
time $PWD/a.out tmp1 > tmp2

echo "(3) Converting text back to image..."
$PWD/post.py tmp2 "processed.$FORMAT"
mv "processed.$FORMAT" "$OLDDIR/processed_$IMGNAME"

echo "Done."
#rm -f "$IMGNAME" tmp1 tmp2
