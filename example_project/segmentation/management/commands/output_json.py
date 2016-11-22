import os, json, datetime
import re
from django.contrib.auth.models import User
import segmentation
from django.shortcuts import get_object_or_404
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from pprint import pprint
from segmentation.models import Image, UserImage

## ugly copy here #####
def decode_results_polygons(results):
    polygon_info = []
    if results:
        this_ann = json.loads(results)
        aaa = this_ann.keys()
        photo_id = aaa[0]
        polygon_info = this_ann[photo_id]    
    return polygon_info

def decode_results_imgid(results):
    photo_id = -1
    if results:
        this_ann = json.loads(results)
        aaa = this_ann.keys()
        photo_id = aaa[0]
    return photo_id
#####

# format is xxxx_user1.jpg:
# url || polygon_str[] || activetime[]
class Command(BaseCommand):  ## in multi user version, need to add a user_id parameter
	""" Export polygon points data to points.json """
	args = '<user_id user_id ...>'
	print "all users:"
	for item in User.objects.all():
		print item.username
	help = 'Export polygon points data to points.json'
	def handle(self, *args, **kwargs):
		timestamp = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
		output_dir = "annotations/annotation_out_" + timestamp + "/"
		saveto_dir = os.path.join(os.path.dirname(os.path.dirname(settings.BASE_DIR)), output_dir)
		if not os.path.exists(saveto_dir):
			os.makedirs(saveto_dir)
		for user in User.objects.all():
			user_id = user.id
			username = user.username
			#print UserImage.objects.filter(user=user)
			for userimage in UserImage.objects.filter(user=user):
			#for image in Image.objects.all():
				if(len(userimage.polygons_str)) > 0 and userimage.status_str=='completed':
					# for multi user, we assume all the annotation is in the str, just go over keys and output
					[file_suff, ext] = re.split('.j',userimage.image.name)
					filename = file_suff + "_"+ username + ".ann"
					filename = os.path.join(saveto_dir, filename) 
					print filename
					out = {}
					out['url'] = userimage.image.url
					out['polygons_str'] = userimage.polygons_str
					out['activetime'] = userimage.activetime_str
					out['namelist'] = userimage.namelist_str
					out['depth_str'] = userimage.depth_str
					out['ann_time'] = userimage.ann_time
					out['created_dt'] = userimage.created_dt.strftime('%Y-%m-%d_%H-%M-%S')
					out['modified_dt'] = userimage.modified_dt.strftime('%Y-%m-%d_%H-%M-%S')
					with open(filename, 'wb') as json_output:
						json.dump(out, json_output)
