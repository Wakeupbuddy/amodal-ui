# -*- coding: utf-8 -*-
from south.utils import datetime_utils as datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models


class Migration(SchemaMigration):

    def forwards(self, orm):
        # Adding field 'Polygon.check_sum'
        db.add_column(u'segmentation_polygon', 'check_sum',
                      self.gf('django.db.models.fields.CharField')(default='', max_length=200),
                      keep_default=False)


    def backwards(self, orm):
        # Deleting field 'Polygon.check_sum'
        db.delete_column(u'segmentation_polygon', 'check_sum')


    models = {
        u'segmentation.image': {
            'Meta': {'object_name': 'Image'},
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '30'}),
            'url': ('django.db.models.fields.URLField', [], {'max_length': '200'})
        },
        u'segmentation.point': {
            'Meta': {'object_name': 'Point'},
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'polygon': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'points'", 'to': u"orm['segmentation.Polygon']"}),
            'x': ('django.db.models.fields.IntegerField', [], {}),
            'y': ('django.db.models.fields.IntegerField', [], {})
        },
        u'segmentation.polygon': {
            'Meta': {'object_name': 'Polygon'},
            'check_sum': ('django.db.models.fields.CharField', [], {'max_length': '200'}),
            'create_dt': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'image': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'polygons'", 'to': u"orm['segmentation.Image']"})
        }
    }

    complete_apps = ['segmentation']