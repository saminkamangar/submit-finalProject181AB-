#! /usr/bin/env python
import csv
import Image
import numpy
import sys

lines = []
filename = sys.argv[1]
with open(filename, 'r') as file:
	data = csv.reader(file)
	for line in data:
		lines.append(map(int, line))

lines = numpy.uint8(numpy.asarray(lines))
Image.fromarray(lines).save(sys.argv[2])
