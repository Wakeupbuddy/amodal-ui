from django.conf.urls import patterns, include, url
from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
	url(r'^$', 'segmentation.views.home', name="home"),
    url(r'^task/(?P<user_pk>\d+)/$', 'segmentation.views.select_task', name="select_task"),
	url(r'^user/(?P<user_pk>\d+)/$', 'segmentation.views.user_images', name="user_images"),
    url(r'^randome/(?P<user_pk>\d+)/$', 'segmentation.views.randome_image', name="random_image"),
    url(r'^next_overview/(?P<user_pk>\w+)/$', 'segmentation.views.next_overview', name="next_overview"),
    url(r'^demo/(?P<pk>\d+)/$', 'segmentation.views.demo', name='demo'),
    url(r'^instructions/?$', 'segmentation.views.instructions', name='instructions'),
    url(r'^videos/?$', 'segmentation.views.videos', name='videos'),
    url(r'^shortcuts/?$', 'segmentation.views.shortcuts', name='shortcuts'),
    url(r'^thanks/?$', 'segmentation.views.thanks', name='thanks'),
    url(r'^statistic/?$', 'segmentation.views.statistic', name='statistic'),

    url(r'^login/$', 'django.contrib.auth.views.login', {'template_name': 'login.html'}),
    url(r'^logout/$', 'django.contrib.auth.views.logout', {'next_page': '/login/'}, name="logout"),

    # Examples:
    # url(r'^$', 'example_project.views.home', name='home'),
    # url(r'^example_project/', include('example_project.foo.urls')),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    url(r'^admin/', include(admin.site.urls)),
)
