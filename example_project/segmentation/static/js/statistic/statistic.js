(function(){
    // SETUP TABLE
    var formatString = 'Y-m-d h:i a';
    var $startDate = $('#startDate');
    var $endDate = $('#endDate');
    
    // set initial value
    var today = new Date();
    today.setMinutes(0);
    var weekAgo = new Date(today); weekAgo.setDate(today.getDate() - 7);
    
    $endDate.datetimepicker({
        format: formatString,
        formatTime:'h:i a',
        closeOnDateSelect: true,
        value : today.dateFormat(formatString)
    });
    $startDate.datetimepicker({
        format: formatString,
        formatTime:'h:i a',
        closeOnDateSelect: true,
        value : weekAgo.dateFormat(formatString)
    });
    
    // execute on load or on any datepicker change
    function update() {
        if (new Date($startDate.val()) > new Date($endDate.val())) {
            console.warn('bad date range');
            return;
        }
        var data = {
            startDate : $startDate.val(),
            endDate : $endDate.val()
        }
        $.ajax({
            type : 'POST',
            url: window.location.href,
            data : data,
            success : function(data) {
                updateTable(data);
            }
        });
    }
    
    function updateTable(dataList) {
        $("#statistic-table").trigger("destroy");
        var html = '';
        dataList.forEach(function(item){
            html += '<tr>';
            html += '<td>' + item.username + '</td>';
            html += '<td>' + item.inprogress + '</td>';
            html += '<td>' + item.completed + '</td>';
            html += '<td>' + item.totalPolygins + '</td>';
            html += '<td>' + item.totalPoints + '</td>';
            html += '<td>' + (item.totalActivetime/60).toFixed(2) + '</td>';
            html += '<td>' + (item.ann_time/60).toFixed(2) + '</td>';
            if(item.totalPolygins >0){
                html += '<td>' + (item.totalPoints/item.totalPolygins).toFixed(2) + '</td>';                
            }
            else{
                html += '<td>' + "N/A" + '</td>';                                
            }
            if(item.completed >0){
                html += '<td>' + (item.totalActivetime/(60*item.completed)).toFixed(2) + '</td>';              
            }
            else{
                html += '<td>' + "N/A" + '</td>';                                
            }
            if(item.completed >0){
                html += '<td>' + (item.ann_time/(60*item.completed)).toFixed(2) + '</td>';                
            }
            else{
                html += '<td>' + "N/A" + '</td>';                                
            }
                         
                         
            html += '</tr>';
        });

        $('#tableBody').html(html)
        $("#statistic-table").tablesorter(); 
    }
    
    $('.datepicker').on('change', update);
    update();


    // SETUP IMAGE SELECTORS
    $image_userSelect = $('#image-userSelect');
    $image_imageSelect = $('#image-imageSelect');
    
    
    // sort images in alphabetical order of names
    window.images.sort(function(a,b) {
        return b.name.localeCompare(a.name);;
    });
    
    
    var users = [];
    var addedImagesName = [];
    
    
    window.images.forEach(function(image) {
        if (users.indexOf(image.user) === -1) {
            users.push(image.user);
        }
        // if image with such name is already added to list we should no dubplicate it
        if (addedImagesName.indexOf(image.name) > -1) {
            return;
        } else {
            addedImagesName.push(image.name);
        }
        $image_imageSelect.append('<option value="' + image.name + '">' + image.name + '</option>');
    });
    
    
    function onImageChange() {
        // now we need to find users who have image with the same name
       var imageName = $image_imageSelect.val();
       
       // create list for such images with name from select
       var imagesWithSameName = window.images.filter(function(image) {
           return image.name === imageName
       });
       
       // then find users
       var usersForImage = imagesWithSameName.map(function(image) {
           return image.user;
       });
       
       // sort user list alphabeticaly
       usersForImage.sort();
       
       // and draw on page
       $image_userSelect.empty();
       usersForImage.forEach(function(user) {
            $image_userSelect.append('<option value="' + user + '">' + user + '</option>');
        });
    }
    $image_imageSelect.on('change', onImageChange);
    onImageChange();
    
    // admin want to see user annotated image
    $('#image-checkResult').on('click', function(e) {
        e.preventDefault();
        // so we need to take name of selected image
        var imageName = $image_imageSelect.val();
        // and user's name
        var user = $image_userSelect.val();
        
        // then find actual image to display
        var image = window.images.filter(function(image) {
            return image.name === imageName && image.user === user;
        })[0];
        
        
        // as image.image is ID of UserImage in database making url is very easy:
        var url = location.origin + '/demo/' + image.image + '?overview=1';
        window.open(url,'_blank');
    });
    
    
    // SETUP IMAGE SELECTORS
    $user_userSelect = $('#user-userSelect');
    $user_imageSelect = $('#user-imageSelect');
    
    // var users = [];
    // window.images.forEach(function(image) {
    //     if (users.indexOf(image.user) === -1) {
    //         users.push(image.user);
    //     }
    // });
    
    users.forEach(function(user) {
        $user_userSelect.append('<option value="' + user + '">' + user + '</option>');
    });
    
    
    
    function onUserChange() {
       var images = [];
       var user = $user_userSelect.val();
       $user_imageSelect.empty();
       var userImages = window.images.filter(function(img) {return img.user === user;});
       userImages.sort(function(a, b) {
           return a.modified_dt > b.modified_dt;
           
       });
       userImages.forEach(function(image) {
            $user_imageSelect.append('<option value="' + image.image + '">' + image.name + '</option>');
        });
    }
    $user_userSelect.on('change', onUserChange);
    onUserChange();
    
    
    $('#user-checkResult').on('click', function(e) {
        e.preventDefault();
        var url = location.origin + '/demo/' + $user_imageSelect.val() + '?overview=1';
        window.open(url,'_blank');
    });
})();