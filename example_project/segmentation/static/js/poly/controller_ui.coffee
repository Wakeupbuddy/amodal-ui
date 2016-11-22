# Main control logic for the UI.  Actions in this class delegate through
# undo/redo and check whether something is feasible.
class ControllerUI
  constructor: (args) ->
    @s = new ControllerState(@, args)
    @btn_anno_status = false
    # disable right click
    $('#mt-container').on('contextmenu', (e) =>
      @click(e)
      false
    )

    # capture all clicks and disable text selection
    $('#mt-container')
      .on('click', @click)
      .on('mouseup', @mouseup)
      .on('mousemove', @mousemove)
    
    $('#mt-container').on('selectstart', -> false)

    # init buttons
    $(@s.btn_draw).on('click', =>
      if not @s.draw_mode then @toggle_mode())
    $(@s.btn_edit).on('click', =>
      if @s.draw_mode then @toggle_mode())
    $(@s.btn_close).on('click', =>
      if not @s.loading then @close_poly())
    $(@s.btn_delete).on('click', =>
      if not @s.loading then @delete_sel_poly())
    $(@s.btn_zoom_reset).on('click', =>
      if not @s.loading then @zoom_reset())

    # log instruction viewing
    $('#modal-instructions').on('show', =>
      @s.log.action(name: "ShowInstructions")
    )
    $('#modal-instructions').on('hide', =>
      @s.log.action(name: "HideInstructions")
    )
    $('#btn-show-annotation').on('click', =>
      if @btn_anno_status
        @remove_fill()
        @btn_anno_status = false
        $('#btn-show-annotation').text('Fill (F)')
        $('#btn-show-annotation').removeClass('active')
        
      else
        @add_fill()
        @btn_anno_status = true
        $('#btn-show-annotation').text('Fill (F)')
        $('#btn-show-annotation').addClass('active')
    )

    $('#polygons_dropdown').on('change', =>
      poly_id = $('#polygons_dropdown').val()
      @s.draw_mode = false
      if $.isNumeric(poly_id)
        @s.select_poly(@, parseInt(poly_id))
        $('#polygon_name').attr("readonly", false)
        $('#polygon_name').val(@.s.sel_poly.name || "");
      else
        $('#polygon_name').attr("readonly", true)
        $('#polygon_name').val("");
        @s.toggle_mode()
    )
    
    $('#polygon_name').on('change keydown', (e) =>
      # disable bubbling to avoid howkeys
      e.stopPropagation()
      if not @s.sel_poly?
        return
      setTimeout(=>
          @s.sel_poly.name = e.target.value
          @s.sel_poly.update_text()
          @update_polygon_dropdown()
          @update_order_sortable()
      , 10)
    )

    # keep track of modal state
    # (since we want to allow scrolling)
    $('.modal').on('show', =>

      @s.modal_count += 1
      true
    )

    $('.modal').on('hide', =>
      @s.modal_count -= 1
      true
    )

    # listen for scrolling
    $(window).on('mousewheel DOMMouseScroll', @wheel)

    # listen for translation
    $(window)
      .on('keydown', @keydown)
      .on('keyup', @keyup)
      .on('blur', @blur)

    # keep track of invalid close attempts to show a
    # popup explaining the problem
    @num_failed_closes = 0

    # init photo
    console.log args.photo_url
    if args.photo_url? then @set_photo(args.photo_url, args.polygon_data, args.list_activetime, args.namelist, @)

    # init polygons
    #if args.polygon_data? then @set_polygons(args.polygon_data)
    
    # init order sortable
    @create_sortable()

  create_sortable: ->
    $sortable = $("#sortable")
    $sortable.sortable({
        stop: (e) =>
            sortedIDs = $sortable.sortable( "toArray" )
            ids = sortedIDs.map (id) => id.slice(5,id.length)
            @s.resort(ids)
            @update_order_sortable()
    })
    $("#sortable").disableSelection()
    
    
  get_submit_data: =>
    @s.get_submit_data()

  set_photo: (photo_url, polygon_data, list_activetime, namelist) =>
    @s.disable_buttons()
    @s.loading = true
    @s.stage_ui.set_photo(photo_url,polygon_data,list_activetime,namelist, @, =>
      @s.loading = false
      @s.update_buttons()
      @update_polygon_dropdown()
      @update_order_sortable()
    )

  remove_photo: =>
    @s.stage_ui.remove_photo()

  add_photo: =>
    @s.stage_ui.add_photo()

  remove_fill: =>
    @s.remove_fill()

  add_fill: =>
    @s.add_fill()

  set_polygons: (polygon_data, list_activetime, namelist) =>  # added
    # console.log("drawing existing polygons")
    # console.log "drawing now, width: " 
    # console.log @s.stage_ui.size.width
    # console.log "drawing now, height: " 
    # console.log @s.stage_ui.size.height
    # console.log "list_activetime", list_activetime
    # console.log "namelist", namelist
    for polygon in polygon_data
     # console.log('load', polygon);
      for point, index in polygon
        if index == 0
          @s.undoredo.run(new UECreatePolygon({x:point[0]*@s.stage_ui.size.width, y:point[1]*@s.stage_ui.size.height}))
        else
          @s.undoredo.run(new UEPushPoint({x:point[0]*@s.stage_ui.size.width, y:point[1]*@s.stage_ui.size.height}))
      @s.undoredo.run(new UEClosePolygon())

    if list_activetime and polygon_data.length == list_activetime.length
      cnt = @s.closed_polys.length-1
      for poly, i in @s.closed_polys
        poly.time_active_ms = list_activetime[cnt]
        # poly.name = names[cnt]
        cnt = cnt-1
#        console.log("initialize ", cnt, "poly actimetime: ", poly.time_active_ms)

    if namelist and polygon_data.length == namelist.length
#      console.log "read in namelist:"
#      console.log namelist
      cnt = @s.closed_polys.length-1
      for poly in @s.closed_polys
        poly.name = namelist[cnt]
        cnt = cnt-1
#        console.log("initialize ", cnt, "poly name: ", poly.name)
    
    # while adding polygon via undoredo
    # we have reversed order
    # so we need to reverse them back to get original order
    ids = @s.closed_polys.map (p) => p.id
    @s.resort(ids.reverse())
    @update_shared_lines()

  keydown: (e) =>
    console.log('key pressed; keycode is ', e.keyCode)
    if @s.modal_count > 0 then return true
    if e.ctrlKey then return 
    switch e.keyCode
      when 37 # left
        @s.translate_delta(-20, 0)
        false
      when 38 # up
        @s.translate_delta(0, -20)
        false
      when 39 # right
        @s.translate_delta(20, 0)
        false
      when 40 # down
        @s.translate_delta(0, 20)
        false
      when 32 # space
        @s.panning = true
        @s.update_cursor()
        false
      when 83 # S
        if @s.sel_poly
            @s.stage_ui.zoom_box(@s.sel_poly.poly.get_aabb())
        false
      when 68 # D
        if not @s.draw_mode then @toggle_mode()
        false
      #when 65 # A
        #if @s.draw_mode then @toggle_mode()
        #false
      when 46,8 # delete,backspace
        # on draw mode wee need to delete open polygon
        if @s.draw_mode
          @remove_open_poly()
          return false
        # in adjust mode we sholud detect where is user mouse
        # on anchor or on fill
        stage = @s.stage_ui.stage
        pos = stage.getPointerPosition()
        shape = stage.getIntersection(pos)
        # if on anchor we need to delete that anchor
        if shape and shape.hasName('anchor') and @s.can_remove_anchor()
          ue = new UERemoveAnchor(shape, @s.sel_poly)
          @s.undoredo.run(ue)
        # or delete whole polygon
        else
            @delete_sel_poly()
        false
      when 67 # C
        if @s.draw_mode
          @add_point()
        false
      when 27 # esc
        if @s.draw_mode
          @s.zoom_reset()
        else
          @unselect_poly()
        false
      when 65 # A , loop to select each closed_polys, added by Zhu
        if @s.open_poly
          return
        if @s.closed_polys.length is 0
          return
        if @s.draw_mode
          @toggle_mode()
          @s.selected_id = @s.closed_polys[0].id
          @s.select_poly(@, @s.selected_id)
        else
          if @s.sel_poly
            @s.selected_id = @s.sel_poly.id
            index = @s.closed_polys.indexOf(@s.sel_poly)
          else
            #@s.selected_id = 0
            index = -1
          nextIndex = (index + 1) % @s.closed_polys.length
          @s.selected_id = @s.closed_polys[nextIndex].id
          @s.select_poly(@, @s.selected_id)
        false
      when 70 # F , Transparent button, added by Zhu
        if @btn_anno_status
          @remove_fill()
          @btn_anno_status = false
          $('#btn-show-annotation').text('Fill (F)')
          $('#btn-show-annotation').removeClass('active')
        else
          @add_fill()
          @btn_anno_status = true
          $('#btn-show-annotation').text('Fill (F)')
          $('#btn-show-annotation').addClass('active')
        false
      when 81 # q (snap to line), added by Zhu
        if @s.panning then return
        p = @s.mouse_pos()
        if not p? then return
        if not @s.loading and @s.draw_mode
          if e.button > 1
            @close_poly()
          else
            if @s.open_poly?
              ue = new UEPushClosestPoint_toLine(p)
              if @s.open_poly.poly.can_push_point(p)
                @s.undoredo.run(ue)
              else
                @s.log.attempted(ue.entry())
            else
              {closest_pt} = @s.get_closest_point_toLine(p)
              @s.undoredo.run(new UECreatePolygon(closest_pt))
            @s.stage_ui.translate_mouse_click()
        false
      when 87 # w: snap to corner of a polygon
  #      console.log("~~~~~~~~~~~ w down! Snap to corner!")
        if @s.panning then return
        p = @s.mouse_pos()
        if not p? then return
        if not @s.loading and @s.draw_mode
          if e.button > 1
            @close_poly()
          else
            if @s.open_poly?
              ue = new UEPushClosestPoint_toCorner(p)
              if @s.open_poly.poly.can_push_point(p)
                @s.undoredo.run(ue)
              else
                @s.log.attempted(ue.entry())
            else
              {closest_pt} = @s.get_closest_point_toCorner(p)
              @s.undoredo.run(new UECreatePolygon(closest_pt))
            @s.stage_ui.translate_mouse_click()
        false
      else
        true

  keyup: (e) =>
    @s.panning = false
    if @s.modal_count > 0 then return true
    @s.update_cursor()
    return true

  blur: (e) =>
    @s.panning = false
    @s.mousedown = false
    if @s.modal_count > 0 then return true
    @s.update_cursor()
    return true

  wheel: (e) =>
    if @s.modal_count > 0 then return true
    oe = e.originalEvent
    if oe.wheelDelta?
      @s.zoom_delta(oe.wheelDelta)
    else
      @s.zoom_delta(oe.detail * -60)
    window.scrollTo(0, 0)
    stop_event(e)

  zoom_reset: (e) =>
    @s.zoom_reset()

  add_point: ->
      p = @s.mouse_pos()
      if not @s.loading and @s.draw_mode
        if @s.open_poly?
          ue = new UEPushPoint(p)
          if @s.open_poly.poly.can_push_point(p)
            @s.undoredo.run(ue)
          else
            @s.log.attempted(ue.entry())
        else
          @s.undoredo.run(new UECreatePolygon(
            @s.stage_ui.mouse_pos()))
        @s.stage_ui.translate_mouse_click()
        
  click: (e) =>
    if @s.panning then return
    p = @s.mouse_pos()
    if not p? then return
    if not @s.loading and @s.draw_mode
      if e.button > 1
        @close_poly()
      else
        @add_point()

  mousedown: (e) =>
    if @s.modal_count > 0 then return true
    @s.mousedown = true
    @s.mousepos = {x: e.pageX, y: e.pageY}
    @s.update_cursor()
    return not @s.panning

  mouseup: (e) =>
    @s.mousedown = false
    if @s.modal_count > 0 then return true
    @s.update_cursor()
    return not @s.panning

  mousemove: (e) =>
    if @s.modal_count > 0 then return true
    if @s.mousedown and @s.panning
      scale = 1.0 / @s.stage_ui.get_zoom_factor()
      @s.stage_ui.translate_delta(
        scale * (@s.mousepos.x - e.pageX),
        scale * (@s.mousepos.y - e.pageY),
        false)
      @s.mousepos = {x: e.pageX, y: e.pageY}
    return true

  update: =>
    @s.open_poly?.update(@)
    @s.sel_poly?.update(@, false, @s.transparent)

  update_polygon_dropdown: ->
    if @s.closed_polys.length > 0
      oldVal = $('#polygons_dropdown').val()
      i = 0
      html_text = ''
      for polygon in @s.closed_polys
        text = '<option value="'+ polygon.id + '">'
        i = i + 1
        text += (parseInt(polygon.id) + 1) + ' ' + (polygon.name || '')
        text += '</option>'
        html_text += text
      $('#polygons_dropdown').html("<option>---</option>" + html_text)
      $('#polygons_dropdown').val(oldVal)
    else
      $('#polygons_dropdown').html("<option>---</option>")
      
  update_order_sortable: ->
      $sortable = $('#sortable')
      # do we need off events from input before clear?
      # just thinking about memory leak
      # I guess there is no mem leak in current code...
      $sortable.empty()
      #console.log('------')
      for polygon, i in @s.closed_polys
        do(polygon) =>
            $li = $("<li id='poly_#{ polygon.id }'>
              <span class='ui-icon ui-icon-arrowthick-2-n-s'>
              </span>#{ i + 1}: </li>")
            
            $input = $("<input type='text' value='#{ polygon.name || '' }'/>")
            # diable global hot keys
            $input.on 'keydown', (e) =>
                e.stopPropagation()
            # update name
            $input.on 'keyup', (e) =>
                polygon.name = $input.val()
            $input.appendTo($li)
            
            #$button = $('<button>Select</button>')
            #$button.appendTo($li)
            $li.on 'click', (e) =>
                @s.draw_mode = false
                @s.select_poly(@, parseInt(polygon.id), false)
                if e.target.nodeName is 'INPUT'
                    $input = $('#poly_' + polygon.id).find('input')
                    $input.focus()
                    # cursor to end
                    strLength= $input.val().length * 2
                    $input[0].setSelectionRange(strLength, strLength)
              
            $li.appendTo($sortable)
            
#            console.log(polygon, @s.sel_poly, @s.closed_polys)
            if polygon is @s.sel_poly
              $li.addClass('selected_row')


  close_poly: => if not @s.loading
    ue = new UEClosePolygon()
    if @s.can_close()
      @s.undoredo.run(ue)
    else
      @s.log.attempted(ue.entry())
      if @s.open_poly?
        if @s.open_poly.poly.area() < window.min_area
          pts = @s.open_poly.poly.points
          @s.stage_ui.error_line(pts[0], pts[pts.length - 1])
          $('#poly-modal-toosmall').modal('show')
          @remove_open_poly()
          return
        pts = @s.open_poly.poly.points
        if pts.length >= 2
          @s.stage_ui.error_line(pts[0], pts[pts.length - 1])
          @num_failed_closes += 1
      if @num_failed_closes >= 3
        @num_failed_closes = 0
        $('#poly-modal-intersect').modal('show')
        

  select_poly: (id) =>
    @s.undoredo.run(new UESelectPolygon(id))

  unselect_poly: (id) =>
    @s.undoredo.run(new UEUnselectPolygon())

  remove_open_poly: (id) =>
    @s.undoredo.run(new UERemoveOpenPoly())

  delete_sel_poly: =>
    ue = new UEDeletePolygon()
    if @s.can_delete_sel()
      @s.undoredo.run(ue)
    else
      @s.log.attempted(ue.entry())

  start_drag_point: (i) =>
    p = @s.sel_poly.poly.get_pt(i)
    @s.drag_valid_point = clone_pt(p)
    @s.drag_start_point = clone_pt(p)

  revert_drag_point: (i) =>
    @s.undoredo.run(new UEDragVertex(i,
      @s.drag_start_point, @s.drag_valid_point))
    return @s.drag_valid_point

  progress_drag_point: (i, p) =>
    @s.stage_ui.layer.batchDraw()
    if @drag_valid(i) then @s.drag_valid_point = clone_pt(p)

  finish_drag_point: (i, p) =>
    @s.undoredo.run(new UEDragVertex(i, @s.drag_start_point, p))
    @s.drag_valid_point = null
    @s.drag_start_point = null

  drag_valid: (i) =>
    not @s.sel_poly.poly.self_intersects_at_index(i)

  toggle_mode: =>
    @s.undoredo.run(new UEToggleMode())
    @update_order_sortable()

  on_photo_loaded: =>
    @s.update_buttons()
    @s.stage_ui.init_events()
    # init polygons
    if args.polygon_data?
        @set_polygons(args.polygon_data, args.list_activetime, args.namelist)
        
  update_shared_lines : ->
    return
    console.log('checking shared lines')
    # destroy previous shared lines
    @s.stage_ui.layer.find('.sharedLine').destroy()
    
    # we should include open polygon into search
    if @s.open_poly
       polys = [@s.open_poly, @s.closed_polys...]
    else
       polys = @s.closed_polys
       
    # then we need to find shared edges for all polygons
    for poly1 in polys
      for poly2 in polys
        if poly1 is poly2
            continue
        points1 = poly1.poly.points
        points2 = poly2.poly.points
        if points1.length < 2 or points2.length < 2
          continue
        for i1 in [0..points1.length - 1]
          for i2 in [0..points2.length - 1]
            # points of edge of poly1
            p11 = points1[i1]
            p12 = points1[(i1 + 1)  % points1.length]
            
            # points of edge of poly2
            p21 = points2[i2]
            p22 = points2[(i2 + 1)  % points2.length]

            # edges are shared means that points are equal
            
            # code bellow is commented as it not works if we add new point to existing line
            #isEqualLines = isEqualPoints(p11, p21) and isEqualPoints(p12, p22) or isEqualPoints(p11, p22) and isEqualPoints(p12, p21)
            
            isPoint21OnLine1 = distanceBetweenSegmentAndPoint([p11, p12], p21)
            isPoint22OnLine1 = distanceBetweenSegmentAndPoint([p11, p12], p22)
            
            isPoint11OnLine2 = distanceBetweenSegmentAndPoint([p21, p22], p11)
            isPoint12OnLine2 = distanceBetweenSegmentAndPoint([p21, p22], p12)
            if (isPoint11OnLine2 and isPoint12OnLine2) or (isPoint21OnLine1 and isPoint22OnLine1)
               zIndex = Math.max(poly1.group.getZIndex(), poly2.group.getZIndex())
               line = new Konva.Line({
                   strokeWidth : 3,
                   stroke: 'red',
                   points: [p11.x, p11.y, p12.x, p12.y],
                   name : 'sharedLine'
               })
               @s.stage_ui.layer.add(line)
               line.setZIndex(zIndex + 1)
               
        @s.stage_ui.draw()