from django.db import models
from django.contrib.auth.models import User


class Image(models.Model):
	name = models.CharField(max_length=30)
	url = models.URLField()

	def __unicode__(self):
		return "%s" % self.name


class AssignedImage(models.Model):
	user = models.OneToOneField(User, related_name="assigned_images")
	images = models.ManyToManyField(Image)

	def __unicode__(self):
		return self.user.username


class UserImage(models.Model):
	user = models.ForeignKey(User, related_name="images")
	image = models.ForeignKey(Image)
	polygons_str = models.TextField()
	depth_str = models.TextField()
	activetime_str = models.TextField()
	ann_time = models.FloatField(default=0.0)
	namelist_str = models.TextField()
	created_dt = models.DateTimeField(auto_now_add=True)
	modified_dt = models.DateTimeField(auto_now=True)
	
	# avaliable statuses : ['clean', 'in-progress', 'completed', 'approved']
	status_str = models.TextField(default='clean')

	def __unicode__(self):
		return "%s - %s" % (self.user.username, self.image.name)
