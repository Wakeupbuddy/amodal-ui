import os
import pdb
import sys
# python manage.py assignImage 1 COCO_val2014_000000000042.jpg
batchFile = sys.argv[1]
userid = "1" # this is piotr's id
suffix = "python manage.py assignImage "
for line in open(batchFile):
	filename = line.rstrip()
	if len(filename) < 8:
		continue
	cmd = suffix + userid + " " + filename
	print(cmd)
	#pdb.set_trace()
	os.system(cmd)
	
	
