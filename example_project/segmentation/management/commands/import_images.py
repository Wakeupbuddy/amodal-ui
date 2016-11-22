import os

from django.core.management.base import BaseCommand, CommandError
from django.conf import settings

from segmentation.models import Image


class Command(BaseCommand):
	""" Import image data from urls.txt to database """

	help = 'Import image data from urls.txt to database'

	def handle(self, *args, **kwargs):
		filename = os.path.join(os.path.dirname(settings.BASE_DIR), '2016-supp.lst')
		count = 0

		# empty Image objects first
	#	Image.objects.all().delete()

		# import image information
		with open(filename) as f_url:
			content = f_url.readlines()
			for each_line in content:
				url = each_line.rstrip()
				name = url.split('/')[-1]
				if Image.objects.filter(name=name).exists():
					continue
				image = Image(name=name, url=url)
				image.save()
				count += 1

		print 'count=%d' % count

