# -*- coding: utf-8 -*-
from south.utils import datetime_utils as datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models


class Migration(SchemaMigration):

    def forwards(self, orm):
        # Deleting model 'Polygon'
        db.delete_table(u'segmentation_polygon')

        # Deleting model 'Point'
        db.delete_table(u'segmentation_point')

        # Deleting model 'Annotation'
        db.delete_table(u'segmentation_annotation')

        # Adding model 'AssignedImage'
        db.create_table(u'segmentation_assignedimage', (
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
            ('user', self.gf('django.db.models.fields.related.ForeignKey')(related_name='assigned_images', to=orm['auth.User'])),
        ))
        db.send_create_signal(u'segmentation', ['AssignedImage'])

        # Adding M2M table for field images on 'AssignedImage'
        m2m_table_name = db.shorten_name(u'segmentation_assignedimage_images')
        db.create_table(m2m_table_name, (
            ('id', models.AutoField(verbose_name='ID', primary_key=True, auto_created=True)),
            ('assignedimage', models.ForeignKey(orm[u'segmentation.assignedimage'], null=False)),
            ('image', models.ForeignKey(orm[u'segmentation.image'], null=False))
        ))
        db.create_unique(m2m_table_name, ['assignedimage_id', 'image_id'])

        # Adding model 'UserImage'
        db.create_table(u'segmentation_userimage', (
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
            ('user', self.gf('django.db.models.fields.related.ForeignKey')(related_name='images', to=orm['auth.User'])),
            ('image', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['segmentation.Image'])),
            ('polygons_str', self.gf('django.db.models.fields.TextField')()),
            ('depth_str', self.gf('django.db.models.fields.TextField')()),
            ('activetime_str', self.gf('django.db.models.fields.TextField')()),
        ))
        db.send_create_signal(u'segmentation', ['UserImage'])


    def backwards(self, orm):
        # Adding model 'Polygon'
        db.create_table(u'segmentation_polygon', (
            ('check_sum', self.gf('django.db.models.fields.CharField')(max_length=200)),
            ('create_dt', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, blank=True)),
            ('annotation', self.gf('django.db.models.fields.related.ForeignKey')(related_name='polygons', to=orm['segmentation.Annotation'])),
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
        ))
        db.send_create_signal(u'segmentation', ['Polygon'])

        # Adding model 'Point'
        db.create_table(u'segmentation_point', (
            ('y', self.gf('django.db.models.fields.FloatField')()),
            ('x', self.gf('django.db.models.fields.FloatField')()),
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
            ('polygon', self.gf('django.db.models.fields.related.ForeignKey')(related_name='points', to=orm['segmentation.Polygon'])),
        ))
        db.send_create_signal(u'segmentation', ['Point'])

        # Adding model 'Annotation'
        db.create_table(u'segmentation_annotation', (
            ('modified_dt', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, blank=True)),
            ('image', self.gf('django.db.models.fields.related.ForeignKey')(related_name='annotations', to=orm['segmentation.Image'])),
            ('user', self.gf('django.db.models.fields.related.ForeignKey')(related_name='annotations', to=orm['auth.User'])),
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
            ('created_dt', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, blank=True)),
        ))
        db.send_create_signal(u'segmentation', ['Annotation'])

        # Deleting model 'AssignedImage'
        db.delete_table(u'segmentation_assignedimage')

        # Removing M2M table for field images on 'AssignedImage'
        db.delete_table(db.shorten_name(u'segmentation_assignedimage_images'))

        # Deleting model 'UserImage'
        db.delete_table(u'segmentation_userimage')


    models = {
        u'auth.group': {
            'Meta': {'object_name': 'Group'},
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '80'}),
            'permissions': ('django.db.models.fields.related.ManyToManyField', [], {'to': u"orm['auth.Permission']", 'symmetrical': 'False', 'blank': 'True'})
        },
        u'auth.permission': {
            'Meta': {'ordering': "(u'content_type__app_label', u'content_type__model', u'codename')", 'unique_together': "((u'content_type', u'codename'),)", 'object_name': 'Permission'},
            'codename': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'content_type': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['contenttypes.ContentType']"}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '50'})
        },
        u'auth.user': {
            'Meta': {'object_name': 'User'},
            'date_joined': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'email': ('django.db.models.fields.EmailField', [], {'max_length': '75', 'blank': 'True'}),
            'first_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'groups': ('django.db.models.fields.related.ManyToManyField', [], {'symmetrical': 'False', 'related_name': "u'user_set'", 'blank': 'True', 'to': u"orm['auth.Group']"}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'is_active': ('django.db.models.fields.BooleanField', [], {'default': 'True'}),
            'is_staff': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'is_superuser': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'last_login': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'last_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'password': ('django.db.models.fields.CharField', [], {'max_length': '128'}),
            'user_permissions': ('django.db.models.fields.related.ManyToManyField', [], {'symmetrical': 'False', 'related_name': "u'user_set'", 'blank': 'True', 'to': u"orm['auth.Permission']"}),
            'username': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '30'})
        },
        u'contenttypes.contenttype': {
            'Meta': {'ordering': "('name',)", 'unique_together': "(('app_label', 'model'),)", 'object_name': 'ContentType', 'db_table': "'django_content_type'"},
            'app_label': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'model': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '100'})
        },
        u'segmentation.assignedimage': {
            'Meta': {'object_name': 'AssignedImage'},
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'images': ('django.db.models.fields.related.ManyToManyField', [], {'to': u"orm['segmentation.Image']", 'symmetrical': 'False'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'assigned_images'", 'to': u"orm['auth.User']"})
        },
        u'segmentation.image': {
            'Meta': {'object_name': 'Image'},
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '30'}),
            'url': ('django.db.models.fields.URLField', [], {'max_length': '200'})
        },
        u'segmentation.userimage': {
            'Meta': {'object_name': 'UserImage'},
            'activetime_str': ('django.db.models.fields.TextField', [], {}),
            'depth_str': ('django.db.models.fields.TextField', [], {}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'image': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['segmentation.Image']"}),
            'polygons_str': ('django.db.models.fields.TextField', [], {}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'images'", 'to': u"orm['auth.User']"})
        }
    }

    complete_apps = ['segmentation']