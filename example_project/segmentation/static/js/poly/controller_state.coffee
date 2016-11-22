# Holds UI state; when something is modified, any dirty items are returned.
# an instance of this is held by ControllerUI
class ControllerState
  constructor: (@ui, args) ->
    @loading = true

    # save id for get_submit_data
    @photo_id = args.photo_id if args.photo_id?

    # action log and undo/redo
    @undoredo = new UndoRedo(@ui, args)
    @log = new ActionLog()
    @log.action($.extend(true, {name:'init'}, args))

    # true: draw, false: adjust
    @draw_mode = true
    @transparent = true  # init status should be transparent, added by Zhu
    # enabled when shift is held to drag the viewport around
    @panning = false

    # mouse state (w.r.t document page)
    @mousedown = false
    @mousepos = null

    # if true, the user was automagically zoomed in
    # after clicking on a polygon
    @zoomed_adjust = false

    # if nonzero, a modal is visible
    @modal_count = 0

    # buttons
    @btn_draw = if args.btn_draw? then args.btn_draw else '#btn-draw'
    @btn_edit = if args.btn_edit? then args.btn_edit else '#btn-edit'
    @btn_close = if args.btn_close? then args.btn_close else '#btn-close'
    @btn_submit = if args.btn_submit? then args.btn_submit else '#btn-submit'
    @btn_save = if args.btn_submit? then args.btn_save else '#btn-save'
    @btn_finalize = if args.btn_finalize? then args.btn_finalize else '#btn-finalize'
    @btn_delete = if args.btn_delete? then args.btn_delete else '#btn-delete'
    @btn_zoom_reset = if args.btn_zoom_reset? then args.btn_zoom_reset else '#btn-zoom-reset'

    # gui elements
    @stage_ui = new StageUI(@ui, args)
    @closed_polys = []  # PolygonUI elements
    @open_poly = null
    @sel_poly = null
    @selected_id = 0
    @saved_point = null  # start of drag

  # return data that will be submitted
  get_submit_data: =>
    results_list = []
    for poly in @closed_polys
      points_scaled = []
      for p in poly.poly.points
        points_scaled.push(Math.max(0, Math.min(1,
          p.x / @stage_ui.size.width)))
        #console.log "p.x"
        #console.log p.x 
        points_scaled.push(Math.max(0, Math.min(1,
          p.y / @stage_ui.size.height)))
       # console.log "p.y"
       # console.log p.y
      results_list.push(points_scaled)

    results = {}
    time_ms = {}
    namelist = {}
    time_active_ms = {}
    results[@photo_id] = results_list
    time_ms[@photo_id] = (p.time_ms for p in @closed_polys)
    time_active_ms[@photo_id] = (p.time_active_ms for p in @closed_polys)
    namelist[@photo_id] = (p.name for p in @closed_polys)
    errors = []
    
    # check for polygons without names
    for p in @closed_polys
        if not p.name
#            console.log(p, p.order)
            errors.push('Object ' + (p.order+1) + ' has no name')
    # check for "If object A totally contain object B, and A is above B"
    for p1 in @closed_polys
        for p2 in @closed_polys
            if p1.poly.contains_poly(p2.poly) and p1.order < p2.order
                errors.push("Double check your depth order!
                     #{p2.order + 1} is contained by #{ p1.order + 1 },
                     and #{p2.order + 1} is under #{p1.order + 1}.")    
#    console.log "namelist is :"
#    console.log JSON.stringify(namelist)
    version: '1.0'
    results: JSON.stringify(results)
    time_ms: JSON.stringify(time_ms)
    namelist: JSON.stringify(namelist)
    errors : errors
    time_active_ms: JSON.stringify(time_active_ms)
    action_log: @log.get_submit_data()

  # redraw the stage
  draw: => @stage_ui.draw()

  # get mouse position (after taking zoom into account)
  mouse_pos: => @stage_ui.mouse_pos()

  # zoom in/out by delta
  zoom_delta: (delta) =>
    @zoomed_adjust = false
    @stage_ui.zoom_delta(delta)
    @update_buttons()
    @update_zoom()

  # reset to 1.0 zoom
  zoom_reset: =>
    @zoomed_adjust = false
    @stage_ui.zoom_reset()
    @update_buttons()
    @update_zoom()

  update_zoom: (redraw=true, permutate=false) =>
    inv_f = 1.0 / @stage_ui.get_zoom_factor()
    for poly in @closed_polys
      poly.update_zoom(@ui, inv_f, false, @transparent, permutate)
    @open_poly?.update_zoom(@ui, inv_f, false, @transparent, permutate)
    @sel_poly?.add_anchors(@ui, @transparent)
    if redraw
      @draw()

  get_zoom_factor: =>
    @stage_ui.get_zoom_factor()

  translate_delta: (x, y) =>
    @stage_ui.translate_delta(x, y)

  # add a point to the current polygon at point p
  push_point: (p) ->
    @open_poly?.poly.push_point(p)
    @open_poly
  
  get_closest_point_toLine: (p) ->
    boundaryPoints = []
    bp1 = clone_pt(p)
    bp2 = clone_pt(p)
    bp3 = clone_pt(p)
    bp4 = clone_pt(p)
    bp1.x = 0
    bp1.y = 0

    bp2.x = @stage_ui.size.width
    bp2.y = 0

    bp3.x = @stage_ui.size.width
    bp3.y = @stage_ui.size.height

    bp4.x = 0
    bp4.y = @stage_ui.size.height

    console.log('pushing') 
    boundaryPoints = [bp1, bp2, bp3, bp4]
    frame = new Polygon(boundaryPoints)
    [closest_pt, dist] = frame.poly_projection_toline(p)
    #dist = Number.MAX_VALUE
    #closest_pt = null
    #console.log "initial distance: ", dist
    cnt=0
    closestPoly = null
    for expoly in @closed_polys
      cnt = cnt+1
#      console.log "cnt:", cnt, " lines of this poly:", expoly.poly.points.length, expoly
      [pt, dist2] = expoly.poly.poly_projection_toline(p)
      #console.log(dist2)
      if dist2<dist
        dist = dist2
        closest_pt = pt
        closestPoly = expoly
    return {
        closestPoly : closestPoly,
        closest_pt : clone_pt(closest_pt)
    }
    
  push_closest_point_toLine: (p) -> # added by Zhu
    {closest_pt, closestPoly} = @get_closest_point_toLine(p)
    if not @open_poly
        return {}
    
    if closest_pt
      # do not add point into existing line
      points = @open_poly.poly.points
      for i in [0..points.length - 1]
        p1 = points[i]
        p2 = points[(i + 1) % points.length]

        if distanceBetweenSegmentAndPoint([p1, p2], closest_pt)
          return {}
      @open_poly.poly.push_point(closest_pt)
      return {
          poly : @open_poly,
          point : closest_pt,
          closestPoly : closestPoly
      }
    else
      return {}

  share_edge: () ->
    console.log('sharing...')
    
    open_points = @open_poly.poly.points
    last_point = open_points[open_points.length - 1]
    previous_point = open_points[open_points.length - 2]
    
    # first we need to find apolygon to share
    poly_to_share = null
    for poly in @closed_polys
        if poly.poly.has_point(last_point) and poly.poly.has_point(previous_point)
            poly_to_share = poly
            
    console.log(poly_to_share)
    if not poly_to_share
        console.error('no share polygon.. skiping')
        return
        
    share_points = poly_to_share.poly.points
    
    
    
    if not previous_point
        console.error('can not find previous point')

    # we need to point in "polygon to share" to start sharing edges
    first_point = null
    for p in share_points
        if isEqualPoints(p, previous_point)
            first_point = p
            break
            
    if not first_point
        console.log('no shared edges case found')
        return
    
    # then we need detect direction clockwise or anticlockwise
    
    # we will use shortest distance
    clockwise_distance = 0
    anticlockwise_distance = 0
    # start search from first_point
    start_index = share_points.indexOf(first_point)
    n = share_points.length
    i = 1

    # if we are on last_point while next loop step we neet do skip all other steps
    clockwise_done = false
    clockwise_valid = true
    
    # direction can be unvalid if we alredy have points from this direction on open polygon
    anticlockwise_done = false
    anticlockwise_valid = true
    
    while true
        if ((start_index + i + n) % n) is start_index
            break
        
        previous_clockwise_point = share_points[(start_index + i - 1 + n) % n]
        next_clockwise_point = share_points[(start_index + i + n) % n]
        
        previous_anticlockwise_point = share_points[(start_index - i + 1 + n) % n]
        next_anticlockwise_point = share_points[(start_index - i + n) % n]
        
        if not clockwise_done
            clockwise_distance += dist_pt(previous_clockwise_point, next_clockwise_point)
            
        if not anticlockwise_done
            anticlockwise_distance += dist_pt(previous_anticlockwise_point, next_anticlockwise_point)
        
        if isEqualPoints(next_clockwise_point, last_point)
            clockwise_done = true
        if isEqualPoints(next_anticlockwise_point, last_point)
            anticlockwise_done = true
            
        if @open_poly.poly.has_point(next_clockwise_point) and not clockwise_done
            clockwise_valid = false
        if @open_poly.poly.has_point(next_anticlockwise_point)  and not anticlockwise_valid
            anticlockwise_valid = false
            
        i += 1
    
    # clockwise default direction
    direction = 1
    if anticlockwise_distance < clockwise_distance or not clockwise_valid
        direction = -1
        
    # ok. now we detected direction
    # now we need to loop from first_point in closed poly to last_point
    # and get all points to insert
    i = start_index
    points_to_push = []
    while true
        i = i + direction
        point = share_points[(i + n) % n]

        if isEqualPoints(point, last_point)
            break
        points_to_push.push(point)
        
    # we found points to push..
    [points_before..., last_points] = open_points
    new_open_points = [points_before..., points_to_push..., last_point]
    @open_poly.poly.points = new_open_points
    
    # return indexes to remove in undo operation
    return {
        fromIndex : points_before.length,
        pointsNumber: points_to_push.length
    }
    
    
    
  get_closest_point_toCorner: (p) ->
    boundaryPoints = []
    bp1 = clone_pt(p)
    bp2 = clone_pt(p)
    bp3 = clone_pt(p)
    bp4 = clone_pt(p)
    bp1.x = 0
    bp1.y = 0

    bp2.x = @stage_ui.size.width
    bp2.y = 0

    bp3.x = @stage_ui.size.width
    bp3.y = @stage_ui.size.height

    bp4.x = 0
    bp4.y = @stage_ui.size.height

    boundaryPoints = [bp1, bp2, bp3, bp4]
    frame = new Polygon(boundaryPoints)
    [closest_pt, dist] = frame.poly_projection_tocorner(p)
    #dist = Number.MAX_VALUE
    #closest_pt = null
    #console.log "initial distance: ", dist
    cnt=0
    for expoly in @closed_polys
      cnt = cnt+1
      #console.log "cnt:", cnt, " lines of this poly:", expoly.poly.points.length, expoly
      [pt, dist2] = expoly.poly.poly_projection_tocorner(p)
      #console.log(dist2)
      if dist2<dist
        dist = dist2
        closest_pt = pt
        closestPoly = expoly
        
    return {
        closest_pt : clone_pt(closest_pt),
        closestPoly : closestPoly
    }
    
  push_closest_point_toCorner: (p) -> # added by Zhu
    
    {closest_pt, closestPoly} = @get_closest_point_toCorner(p)
    if closest_pt and @open_poly?.poly.can_push_point(closest_pt)
      @open_poly?.poly.push_point(closest_pt)
      
    return {
          poly : @open_poly,
          point : closest_pt,
          closestPoly : closestPoly
      }


  # delete the last point on the open polygon
  pop_point: ->
    @open_poly?.poly.pop_point()
    @open_poly

  # get the location of point i on polygon id
  get_pt: (id, i) ->
    @get_poly(id)?.poly.get_pt(i)

  # resort polygons in order
  # first on top
  resort: (ids) ->
      # if we have no new list array of ids
      # we will get old order
      # resort here helps us to apply "order" property for each polygon
      # and redraw stage
      if not @closed_polys
        return
      if not ids?
        ids = @closed_polys.map (poly) => poly.id

      new_list = []
      for id, i in ids
        polys = @closed_polys.filter (poly) =>
            poly.id.toString() is id.toString()
        poly = polys[0]
        poly.order = i
        poly.update_text()
        new_list.push(poly)
        poly.group.moveToBottom()
      @closed_polys = new_list
      @ui.s.stage_ui.layer.draw()
      @ui.update_shared_lines()

  # add point to position for selected polygon
  addPoint: (position) ->
    pos = @stage_ui.mouse_pos()
    @undoredo.run(new UEAddPoint(pos))
    @
    
  can_remove_anchor: () ->
      if not @sel_poly
        return false
      if @sel_poly.poly.points.length < 5
        return false
      return true
        
  remove_point: (point) ->
      @sel_poly.poly.remove_point(p)
      
      
  # add an open polygon using points
  create_poly: (points) ->
    @open_poly.remove_all() if @open_poly?
    poly = new Polygon(points)
    ids = @closed_polys.map (p) -> p.id
    if not ids.length
        ids = [0]
    maxid = Math.max.apply(null, ids)
    @open_poly = new PolygonUI(++maxid, poly, @stage_ui)
    @open_poly.timer = new ActiveTimer()
    @open_poly.timer.start()
    @update_buttons()
    @open_poly

  # add a closed polygon in the specified slot
  insert_closed_poly: (points, id, order, time_ms, time_active_ms) ->
    poly = new Polygon(points)
    poly.close()
    closed_poly = new PolygonUI(id, poly, @stage_ui)
    closed_poly.time_ms = time_ms
    closed_poly.time_active_ms = time_active_ms
    @closed_polys.splice(order, 0, closed_poly)
    @update_buttons()
    closed_poly

  # return polygon id
  get_poly: (id) ->
    for p in @closed_polys
      if p.id == id
        return p
    return null

  # return number of polygons
  num_polys: -> @closed_polys.length

  # delete the open polygon
  remove_open_poly: ->
    @open_poly?.remove_all()
    @open_poly = null

  # close the open polygon
  close_poly: ->
    if @open_poly?
      @open_poly.time_ms = @open_poly.timer.time_ms()
      @open_poly.time_active_ms = @open_poly.timer.time_active_ms()
      poly = @open_poly
      @open_poly.poly.close()
      @closed_polys.unshift(@open_poly)
      @resort()
      @open_poly = null
      @update_buttons()
      poly
    else
      null

  can_close: =>
    if not @loading and @open_poly?
      if (window.min_vertices? and @open_poly.poly.num_points() < window.min_vertices)
        return false
#      console.log("state threshold:", window.min_area)
#      console.log("state area:", @open_poly.poly.area())
      if(@open_poly.poly.area() < window.min_area) # added by Zhu
        return false
      @open_poly.poly.can_close()
    else
      false

  # re-open the most recently closed polygon
  unclose_poly: ->
    if @draw_mode and not @open_poly? and @num_polys() > 0
      @open_poly = @closed_polys.shift()
      @open_poly.poly.unclose()
      @update_buttons()
      @open_poly
    else
      null

  # true if the selected polygon can be deleted
  can_delete_sel: ->
    not @loading and not @draw_mode and @sel_poly? and @num_polys() > 0

  # delete the currently selected polygon
  delete_sel_poly: ->
    if @can_delete_sel()
      for p,i in @closed_polys
        if p.id == @sel_poly.id
          @closed_polys.splice(i, 1)
          @sel_poly?.remove_all()
          @sel_poly = null
          break
      if @zoomed_adjust then @zoom_reset()
      @update_buttons()
      null
    else
      null

  # select the specified polygon
  select_poly: (ui, id, zoom=true) ->
    if @draw_mode then return
    if @sel_poly?
      if @sel_poly.id == id then return
      @unselect_poly(false)

    @sel_poly = @get_poly(id)
    @sel_poly.add_anchors(ui)
    #if zoom
        #@stage_ui.zoom_box(@sel_poly.poly.get_aabb())
    @zoomed_adjust = true
    @update_buttons()
    ui.update_order_sortable()
    @update_zoom(false)
    @draw()
    
#    @select_id = id  # added by Zhu
    $('#polygons_dropdown').val(id) # added by Zhu, update the dropdown selection
    $('#polygons_name').val(@sel_poly.name);
    @sel_poly

  unselect_poly: (reset_zoomed_adjust=true) =>
    @sel_poly?.remove_anchors()
    @sel_poly = null
    if reset_zoomed_adjust and @zoomed_adjust
      @zoom_reset()
    @update_buttons()
    null

  toggle_mode: ->
    @draw_mode = not @draw_mode
    if @draw_mode
      if @sel_poly?
        @unselect_poly()
    else
      if @open_poly?
        @remove_open_poly()
    @update_buttons()

  disable_buttons: ->
    set_btn_enabled(@btn_draw, false)
    set_btn_enabled(@btn_edit, false)
    set_btn_enabled(@btn_close, false)
    #set_btn_enabled(@btn_submit, false)
    set_btn_enabled(@btn_finalize, false)

  # update cursor only
  update_cursor: ->
    if @panning
      if $.browser.webkit
        if @mousedown
          $('canvas').css('cursor', '-webkit-grabing')
        else
          $('canvas').css('cursor', '-webkit-grab')
      else
        if @mousedown
          $('canvas').css('cursor', '-moz-grabing')
        else
          $('canvas').css('cursor', '-moz-grab')
    else if @draw_mode
      $('canvas').css('cursor', 'crosshair')
    else
      $('canvas').css('cursor', 'default')

  # update buttons and cursor
  update_buttons: ->
    @update_cursor()
    enable_submit = (not window.min_shapes? or
      @num_polys() >= window.min_shapes)
    #set_btn_enabled(@btn_submit, enable_submit)
    set_btn_enabled(@btn_finalize, enable_submit)
    set_btn_enabled(@btn_draw, not @loading)
    set_btn_enabled(@btn_edit, not @loading)
    set_btn_enabled(@btn_delete, @can_delete_sel())
    set_btn_enabled(@btn_zoom_reset,
      not @loading and @stage_ui.zoom_exp > 0)
    if @draw_mode
      $(@btn_draw).button('toggle')
      set_btn_enabled(@btn_close, @can_close())
    else
      $(@btn_edit).button('toggle')
      set_btn_enabled(@btn_close, false)

  # remove_fill: ->
  #   @stage_ui.add_loading()
  #   for poly in @closed_polys
  #     poly.remove_fill()
  #     poly.remove_text()
  #     poly.add_line()
  #     pp = clone_pt(poly.poly.points[0])
  #     poly.add_hover_line(pp)
  #   @stage_ui.remove_loading()

  # add_fill: ->
  #   @stage_ui.add_loading()
  #   for poly in @closed_polys
  #     poly.add_fill(@ui)
  #     poly.add_text()
  #   @stage_ui.remove_loading()

  remove_fill: -> # added by Zhu, make opac =0
    @stage_ui.add_loading()
    @transparent = true
    @update_zoom(false,true)
    @stage_ui.remove_loading()

  add_fill: -> # added by Zhu, make opac =0.4
    @stage_ui.add_loading()
    @transparent = false
    @update_zoom(false,true)
    @stage_ui.remove_loading()
