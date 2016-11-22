import json
import hashlib
import pprint
import datetime

from ua_parser import user_agent_parser

from django.shortcuts import render, redirect, get_object_or_404
from django.views.decorators.csrf import ensure_csrf_cookie
from django.http import Http404, HttpResponse, HttpResponseRedirect
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required
from django.db.models import Q

from segmentation.models import Image, UserImage


@login_required
def home(request):
    return redirect(reverse('random_image', kwargs={'user_pk': request.user.pk}))


@login_required
def select_task(request, user_pk):
    user = get_object_or_404(User, pk=int(user_pk))
    return render(request, 'task.html', {'chosen_user': user})


@login_required    
def instructions(request):
    return render(request, 'instructions.html')

@login_required    
def videos(request):
    return render(request, 'videos.html')    
    
@login_required    
def thanks(request):
    return render(request, 'thanks.html')


@login_required    
def shortcuts(request):
    return render(request, 'shortcuts.html')
    
@login_required    
def statistic(req):
    if req.method == 'POST':
        # parse date str to list of integers
        start = req.POST['startDate']
        startY = int(start[0:4])
        startM = int(start[5:7])
        startD = int(start[8:10])
        startH = int(start[11:13])
        if start[17:19] == 'pm' and startH != 12:
            startH = startH + 12
        if start[17:19] == 'am' and startH == 12:
            startH = 0        
        print start 
        print "----"
        print startY, startM, startD, startH
        end = req.POST['endDate']
        
        endY = int(end[0:4])
        endM = int(end[5:7])
        endD = int(end[8:10])
        endH = int(end[11:13])
        if end[17:19] == 'pm':
            if endH < 12:
                endH = endH + 12

        print end 
        print "----"
        print endY, endM, endD, endH

        start_date = datetime.datetime(startY, startM, startD, startH)
        end_date = datetime.datetime(endY, endM, endD, endH)

        data = get_statistics(req, start_date, end_date)
        return HttpResponse(json.dumps(data), content_type="application/json")
    else:
        images = []
        for image in UserImage.objects.all():
            if image.status_str == 'completed' or image.status_str == 'approved':
                images.append({
                    'user' : image.user.username.encode(),
                    'image' : image.pk,
                    'name' : image.image.name.encode(),
                    'modified_dt' : str(image.modified_dt),
                })
        return render(req, 'statistic.html', {
            'images': images
            })

def get_poly_info(QuerySet):
    polygon_num = 0
    pts_num = 0
    for item in QuerySet:
        dict1=json.loads(item.polygons_str)
        id=dict1.keys()
        id=id[0]
        list_poly = dict1[id]
        for poly in list_poly:
            pts_num = pts_num+len(poly)
        polygon_num = polygon_num + len(list_poly)
    return polygon_num, pts_num

def get_total_activetime(QuerySet):
    overall_time = 0.0
    for item in QuerySet:
        dict1 = json.loads(item.activetime_str)
        id=dict1.keys()
        id=id[0]
        list_time = dict1[id]    
        overall_time = overall_time + sum(list_time)*1.0/1000
    return overall_time

def get_total_ann_time(QuerySet):
    overall_time = 0.0
    for item in QuerySet:
        overall_time = overall_time + item.ann_time
    return overall_time

def get_statistics(request, start_date, end_date):
    result = []
    for user in User.objects.all():
        end_date = end_date+datetime.timedelta(days=1) # to get inclusion of the last day
        completed_set = UserImage.objects.filter( Q(status_str__iexact='completed') | Q(status_str__iexact='approved'), user=user, modified_dt__range=(start_date,end_date))
        
        inprogress_set = UserImage.objects.filter(user=user, modified_dt__range=(start_date,end_date),status_str='in-progress')
        completed_polygon_num, completed_pts_num = get_poly_info(completed_set)
        inprogress_polygon_num, inprogress_pts_num = get_poly_info(inprogress_set)
        completed_activetime = get_total_activetime(completed_set)
        inprogress_activetime = get_total_activetime(inprogress_set)
        total_ann_time = get_total_ann_time(completed_set) + get_total_ann_time(inprogress_set)
        print total_ann_time
      #  print "time is: ", completed_activetime+inprogress_activetime
        stats = {
            "username": user.username,
            "totalPolygins" : inprogress_polygon_num+completed_polygon_num,
            "inprogress": len(inprogress_set),
            "completed" : len(completed_set),
            "totalPoints": completed_pts_num+inprogress_pts_num,
            "totalActivetime": completed_activetime + inprogress_activetime,
            "ann_time": total_ann_time
        }
        result.append(stats)
    return result

@login_required
def user_images(request, user_pk):
    user = get_object_or_404(User, pk=int(user_pk))
    if request.method == 'POST':
        image = get_object_or_404(Image, pk=int(request.POST.get('image')))
        # check if polygons for (user, image) are created
        try:
            user_image = UserImage.objects.get(user=user, image=image)
        except UserImage.DoesNotExist:
            user_image = UserImage(user=user, image=image)
            user_image.save()
        return redirect(reverse('demo', kwargs={'pk': user_image.pk}))
    error = False
    # try:
    images = []
    assigned_images = user.assigned_images.images.all()
    #print(assigned_images)
    images_with_data = [item.image for item in user.images.all() if item.namelist_str]
    for img in assigned_images:
        if img in images_with_data:
            images.append({
                'pk' : img.pk,
                'name' : img.name
            })
        else:
            images.append({
                'pk' : img.pk,
                'name' : 'no data - ' + img.name
            })
    # except:
    #     images = None
    #     error = True
    return render(request, 'select_image.html', {
        'images': images,
        'chosen_user': user,
        'error': error
        })


@login_required
def randome_image(request, user_pk):
    user = get_object_or_404(User, pk=int(user_pk))
    try:
        assigned_images = user.assigned_images.images.all()
    except:
        return redirect(reverse('thanks'))


    # make sure that we have user_image for all assigned images
    for image in assigned_images:
        try:
            user_image = UserImage.objects.get(user=user, image=image)
        except UserImage.DoesNotExist:
            user_image = UserImage(user=user, image=image)
            user_image.save()
    
    images = UserImage.objects.filter(Q(status_str__iexact='clean') | Q(status_str__iexact='in-progress'), user = user).order_by('?')
    user_image = images[0] if len(images) else None
    # first get clean images
    # clean_images = images.filter(status_str__iexact='clean')
    # user_image = clean_images[0] if len(clean_images) else None
    
    # if no clean image then find random in progress image
    # if not user_image:
        # in_progress_images = images.filter(status_str__iexact='in-progress').order_by('?')
        # user_image = in_progress_images[0] if len(in_progress_images) else None
    
    # if no clean and no in-progress image then return "THANK YOU!!"
    if not user_image:
        return redirect(reverse('thanks'))
    
    print('overview' in request.GET, request.GET.get('overview', 0))
    if 'overview' in request.GET:
        redirect_url = reverse('demo', kwargs={'pk': user_image.pk})
        redirect_url += '?overview=1'
        return HttpResponseRedirect( redirect_url )
        
    return redirect(reverse('demo', kwargs={'pk': user_image.pk}))
    
@login_required
def next_overview(request, user_pk):
    if user_pk != 'random':
        user = get_object_or_404(User, pk=int(user_pk))
        try:
            assigned_images = user.assigned_images.images.all()
        except:
            return redirect(reverse('thanks'))

    
    if user_pk == 'random':
        images = UserImage.objects.filter(Q(status_str__iexact='completed') | Q(status_str__iexact='approved')).order_by('?')
    else:
        images = UserImage.objects.filter(Q(status_str__iexact='completed') | Q(status_str__iexact='approved'), user = user).order_by('?')
    user_image = images[0] if len(images) else None
    if not user_image:
        return redirect(reverse('thanks'))
    
    redirect_url = reverse('demo', kwargs={'pk': user_image.pk})
    redirect_url += '?overview=1'
    return HttpResponseRedirect( redirect_url )


def encode_time(id, list):
    dict = {}
   # print "encode_time"
   # print id, list
    dict[id] = list
    return json.dumps(dict)


def get_real_time_active(time_cur, time_last):
    #print time_cur, time_last
    return time_cur


def decode_results_polygons(results):
    polygon_info = []
    if results:
        json_result = json.loads(results)
        photo_id = json_result.keys()[0]
        polygon_info = json_result[photo_id]
    return polygon_info


def poly_to_points(polygon):
    points = []
    for i in range(0, len(polygon), 2):
        points.append([polygon[i], polygon[i+1]])
    return points

def getAnnotationTime(action_log):
    ann_time = 0.0
    json_log = json.loads(action_log)
    prev_time = None
    for item in json_log:
        if prev_time:
            interval = datetime.datetime.strptime(item[u'time'], '%Y-%m-%dT%H:%M:%S.%fZ') - prev_time
            interval = interval.total_seconds()
            prev_time = datetime.datetime.strptime(item[u'time'], '%Y-%m-%dT%H:%M:%S.%fZ') 
            if(interval<5):
                ann_time = ann_time + interval
        else:
            prev_time = datetime.datetime.strptime(item[u'time'], '%Y-%m-%dT%H:%M:%S.%fZ')
    return ann_time


@ensure_csrf_cookie
@login_required
def demo(request, pk):
    """
    Serve up a segmentation task.
    This is a demo, so we are going to hard-code an image to tag.
    In a live system, you would read the HIT id:
        hit_id = request.REQUEST['hitId']
        assignment_id = request.REQUEST['assignmentId']
    and fetch a photo from the database.
    When a user submits, the data will be in request.body.
    request.body will contain these extra fields corresponding
    to data sent by the task window:
        results: a dictionary mapping from the content.id (which is just "1" in
            this example) to a list of polygons.  Example:
            {"1": [[x1,y1,x2,y2,x3,y3,...], [x1,y1,x2,y2,...]]}.
            The x and y coordinates are fractions of the width and height
            respectively.
        time_ms: amount of time the user spent (whether or not
            they were active)
        time_active_ms: amount of time that the user was
            active in the current window
        namelist: array of names for polygons in same order as in results.1 array
        action_log: a JSON-encoded log of user actions
        screen_width: user screen width
        screen_height: user screen height
        version: always "1.0"
        If the user gives feedback, there will also be this:
        feedback: JSON encoded dictionary of the form:
        {
            'thoughts': user's response to "What did you think of this task?",
            'understand': user's response to "What parts didn't you understand?",
            'other': user's response to "Any other feedback, improvements, or suggestions?"
        }
    """

    if request.method == 'POST':
        
        # get UserImage instance
        user_image = get_object_or_404(UserImage, pk=int(pk))
        
        # decode 'results' field from POST
        polygon_info = decode_results_polygons(request.POST['results'])
        # decode 'names' field from POST
        #names_info = json.loads(request.POST['names'])        
        # display_width = request.POST.get('display_width', None)
        # display_height = request.POST.get('display_height', None)
        # display_width = float(display_width)
        # display_height = float(display_height)
        # print "width: ", display_width
        # print "height: ", display_height   

       # print "getting data"
       # print polygon_info

        # valid_error = ""
        # for id in names_info:
        #     if not names_info[id]:
        #         valid_error += 'Not name for object ' + id
        # if len(valid_error) > 0:
        #     return json_error_response(valid_error);

        if len(polygon_info) > 0:
            user_image.polygons_str = request.POST['results']
            user_image.namelist_str = request.POST['namelist']
            ann_time = getAnnotationTime(request.POST['action_log'])
            print("ann_time: ", ann_time)
            user_image.ann_time = user_image.ann_time + ann_time
           # print "user_image.namelist_str: ", user_image.namelist_str
            
            # validate status info
            status = request.POST['status']
            if request.POST['status'] not in ['in-progress', 'completed', 'approved']:
                status = 'in-progress'
                print('error while getting status info', request.POST['status'])
            user_image.status_str = status
            
            time_active_ms_cur = request.POST.get('time_active_ms', None)
            time_active_ms_last = user_image.activetime_str
            user_image.activetime_str = get_real_time_active(time_active_ms_cur, time_active_ms_last)
            user_image.save()
        else:
            return json_error_response("This is a demo.  Here is the data you submitted: " +
                json.dumps(request.POST))  
        return json_success_response() 

    else:
        response = browser_check(request)
        if response:
            return response

        # get UserImage instance
        user_image = get_object_or_404(UserImage, pk=int(pk))

        data = []
        list_activetime = []
        namelist=[]
        polys = decode_results_polygons(user_image.polygons_str)
        if user_image.activetime_str:
            activetime_str = user_image.activetime_str
            at_dict = json.loads(activetime_str)
            id = at_dict.keys()
            id = id[0]
            list_activetime = at_dict[id]

        if user_image.namelist_str:
         #   print "here's user_image.namelist_str:", user_image.namelist_str
            namelist_str = user_image.namelist_str
         #   print(namelist_str)
            at_dict = json.loads(namelist_str)
            id = at_dict.keys()
            id = id[0]
            namelist = at_dict[id]
            for i in range(len(namelist)):
                namelist[i]=namelist[i].encode('ascii','ignore')
    
                
        for polygon in polys:
            data.append(poly_to_points(polygon)) 
        #print "list_activetime: ", list_activetime
        #print "sending namelist:", namelist

        context = {
            # the current task
            'content': {
                # the database ID of the photo.  You can leave this at 1 if you
                # don't use a database.  When the results are submitted, the
                # content.id is the key in a dictionary holding the polygons.
                'id': user_image.image.pk,
                # url where the photo can be fetched.
                #'url': 'http://farm9.staticflickr.com/8204/8177262167_d749ec58d9_h.jpg'
                'url': user_image.image.url
            },
            'image_name' : user_image.image.url.split('/')[-1],
            
            'status' : user_image.status_str,
            # min number of shapes before the user can submit
            'min_shapes': 1,

            # min number of vertices the user must click for each shape
            'min_vertices': 4,

            'min_area': 600,
            # if 'true', ask the user a feedback survey at the end and promise
            # payment to complete it.  Must be 'true' or 'false'.
            'ask_for_feedback': 'false',

            # feedback_bonus is the payment in dollars that we promise users
            # for completing feedback
            'feedback_bonus': 0.02,

            # template containing html for instructions
            'instructions': 'mturk/mt_segment_material_inst_content.html',

            # deliver image instance to template
            'polygons': data, 
            
            'namelist' : namelist,

            'list_activetime': list_activetime,
            # deliver username to template
            'username': user_image.user.username,


            # show continue button on dialog
            'show_continue_btn': True,
            'overview' : request.GET.get('overview', 0),
            # user_pk
            'user_pk': user_image.user.pk
        }

    return render(request, 'mturk/mt_segment_material.html', context)


def browser_check(request):
    """ Only allow firefox and chrome, and no mobile """
    valid_browser = False
    if 'HTTP_USER_AGENT' in request.META:
        ua = user_agent_parser.Parse(request.META['HTTP_USER_AGENT'])
        if ua['user_agent']['family'].lower() in ('firefox', 'chrome'):
            device = ua['device']
            if 'is_mobile' not in device or not device['is_mobile']:
                valid_browser = True
    if not valid_browser:
        return html_error_response(
            request, '''
            This task requires Google Chrome. <br/><br/>
            <a class="btn" href="http://www.google.com/chrome/"
            target="_blank">Get Google Chrome</a>
        ''')
    return None


def json_success_response():
    return HttpResponse(
        '{"message": "success", "result": "success"}',
        content_type='application/json')


def json_error_response(error):
    """ Return an error as a JSON object """
    return HttpResponse(
        json.dumps({'result': 'error', 'message': error}),
        content_type='application/json')


def html_error_response(request, error):
    return render(request, "error.html", {'message': error})
