from django.contrib import admin
from django import forms
from segmentation.models import Image, AssignedImage, UserImage
import json

class ImageAdmin(admin.ModelAdmin):
	list_display = ('name', 'url')

admin.site.register(Image, ImageAdmin)

class AssignedImageForm(forms.ModelForm):
	class Meta:
		model = AssignedImage
		widgets = {
			'images':forms.SelectMultiple(attrs={'size':100})
		}
class AssignedImageAdmin(admin.ModelAdmin):
	form = AssignedImageForm

admin.site.register(AssignedImage, AssignedImageAdmin)

class UserImageAdmin(admin.ModelAdmin):
	date_hierarchy = 'modified_dt'
	list_display = ('image','user','status_str','modified_dt','get_poly_info','get_total_activetime')

	def get_poly_info(self, obj):
		if len(obj.activetime_str)==0:
			return 0
		return len(obj.activetime_str.strip().split(','))

	get_poly_info.short_description = 'Polygons'
#	get_poly_info.admin_order_field = 'Polygons'

	def get_total_activetime(self, obj):
		if len(obj.activetime_str)==0:
			return 0
		dict1 = json.loads(obj.activetime_str)
		id=dict1.keys()
		id=id[0]
		list_time = dict1[id]
		return sum(list_time)*1.0/1000

	get_total_activetime.short_description = 'total active time (second)'
 #   get_total_activetime.admin_order_field = 'total active time

admin.site.register(UserImage, UserImageAdmin)

