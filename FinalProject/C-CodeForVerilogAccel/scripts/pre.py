#! /usr/bin/env python
import sys
import Image

filename = sys.argv[1]
img = Image.open(filename).convert('L')
xSize, ySize = img.size
bitmap = img.load()

for j in range(ySize):
	for i in range(xSize-1):
		sys.stdout.write(str(bitmap[i,j]) + ',')
	sys.stdout.write(str(bitmap[xSize-1,j]))
	print
