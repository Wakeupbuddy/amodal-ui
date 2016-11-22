from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from segmentation.models import Image, UserImage, AssignedImage
import sys
# usage: python manage.py assignImage 1 COCO_val2014_000000000042.jpg

class Command(BaseCommand):
	def handle(self, *args, **kwargs):
		userid = int(args[0])
		newImage = args[1]
#		userid = 1
#		newImage = "COCO_val2014_000000000042.jpg"
		res = AssignedImage.objects.all()
		#print(res[userid])
		#print(res[userid].images.all())
		try:
			imageObject = Image.objects.get(name=newImage)
		except:
			print("image name: " + newImage + " not exist")
			sys.exit()
		#print(imageObject)
		# if deleting ..			
		# res[userid].images.remove(imageObject)
		res[userid].images.add(imageObject)
		print("now user " + str(userid) + " has " + str(len(res[userid].images.all())) + " images")
