from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from segmentation.models import Image, UserImage

class Command(BaseCommand):
	def handle(self, *args, **kwargs):
		filename = "COCO_train2014_000000021169.jpg"
		res = Image.objects.filter(name=filename)
		print("Key: " + filename)
		print(res)
