# Wrapper for Konva.Stae
class StageUI
  constructor: (ui, args) ->
    # maximum possible size
    @bbox = {width: args.width, height: args.height}
    # actual size
    @size = {width: args.width, height: args.height}
    @photo_size = 
    # zoom information
    @origin = {x: 0, y: 0}
    @zoom_exp = 0
    @zoom_exp_max = 7

    @stage = new Konva.Stage(
      container: args.container_id,
      width: @size.width,
      height: @size.height)
    @layer = new Konva.Layer()
    @anchorLayer = new Konva.Layer()
    @photo_layer = new Konva.Layer()
    
    @photo_group = new Konva.Group();
    @photo_layer.add(@photo_group)
    
    @stage.add(@photo_layer)
    @stage.add(@layer)
    @layer.canvas._canvas.style.opacity = '0.6'
    @stage.add(@anchorLayer)

    @stage.on('mouseout', => @layer.draw())
    @stage.on('mousemove', ->
      if not ui.s.panning
        ui.update()
    )

  add: (o, opacity=1.0, duration=0.4, layer=@layer) ->
    layer.add(o)
    if duration > 0
      o.setOpacity(0)
      o.add_trans = o.to(opacity:opacity, duration:duration)
    else
      o.setOpacity(opacity)

  remove: (o, duration=0.4) -> if o?
    o.add_trans?.stop()
    if duration > 0
      o.removing = true
      o.to(
        opacity: 0
        duration: duration
        onFinish: do (o) -> -> o.remove()
      )
    else
      o.remove()

  draw: ->
      @layer.batchDraw()
      @anchorLayer.batchDraw()

  mouse_pos: ->
    p = @stage.getPointerPosition()
    if not p?
      p
    else
      scale = Math.pow(2, -@zoom_exp)
      x: Math.min(Math.max(0, p.x * scale + @origin.x), @size.width)
      y: Math.min(Math.max(0, p.y * scale + @origin.y), @size.height)

  zoom_reset: (redraw=true) ->
    @zoom_exp = 0
    @origin = {x: 0, y: 0}
    @stage.setOffset({x : @origin.x, y :@origin.y})
    @stage.setScale({x : 1.0, y : 1})
    if redraw
      @stage.batchDraw()

  # zoom in/out by delta (in log_2 units)
  zoom_delta: (delta, p=@stage.getPointerPosition()) ->
    if delta?
      @zoom_set(@zoom_exp + delta * 0.001, p)

  get_zoom_factor: ->
    Math.pow(2, @zoom_exp)

  # set the zoom level (in log_2 units)
  zoom_set: (new_zoom_exp, p=@stage.getPointerPosition()) ->
    if @k_loading? or not new_zoom_exp? or not p? then return
    old_scale = Math.pow(2, @zoom_exp)
    @zoom_exp = Math.min(@zoom_exp_max, new_zoom_exp)
    if @zoom_exp <= 0
      @zoom_reset()
    else
      new_scale = Math.pow(2, @zoom_exp)
      f = (1.0 / old_scale - 1.0 / new_scale)
      @origin.x += f * p.x
      @origin.y += f * p.y
      @stage.setOffset({x:@origin.x, y:@origin.y})
      @stage.setScale({x: new_scale, y: new_scale})
      @stage.batchDraw()

  # zoom to focus on a box
  zoom_box: (aabb) ->
    min = {x: aabb.min.x - 50, y: aabb.min.y - 50}
    max = {x: aabb.max.x + 50, y: aabb.max.y + 50}
    obj = {width: max.x - min.x, height: max.y - min.y}
    b = compute_dimensions(obj, @bbox, INF)
    @zoom_exp = Math.max(0, Math.min(@zoom_exp_max,
      Math.log(b.scale) / Math.log(2)))
    if @zoom_exp <= 0
      @zoom_reset()
    else
      @origin = min
      @stage.setOffset({x : @origin.x, y : @origin.y})
      @stage.setScale({x : Math.pow(2, @zoom_exp), y: Math.pow(2, @zoom_exp)})
      @stage.batchDraw()

  # translate the zoomed in view by some amount
  translate_delta: (x, y, transition=true) ->
    if not @k_loading
      @origin.x += x
      @origin.y += y
      p = clone_pt(@origin)
      if transition
        @stage.to(
          offsetX: p.x
          offsetY: p.y
          duration: 0.1
        )
      else
        @stage.setOffset({x:@origin.x, y:@origin.y})
      @stage.batchDraw()

  # translate the view if near the edge
  translate_mouse_click: ->
    if @zoom_exp > 0 and not @k_loading
      p = @stage.getPointerPosition()
      p =
        x: p.x / @stage.getWidth()
        y: p.y / @stage.getHeight()
      #console.log 'p:', p
      delta = { x: 0, y: 0 }
      factor = @get_zoom_factor()
      if p.x < 0.05
        delta.x = -200 / @get_zoom_factor()
      else if p.x > 0.95
        delta.x = 200 / @get_zoom_factor()
      if p.y < 0.05
        delta.y = -200 / @get_zoom_factor()
      else if p.y > 0.95
        delta.y = 200 / @get_zoom_factor()
      if delta.x != 0 or delta.y != 0
        @translate_delta(delta.x, delta.y)

  toFlatArray: (points) ->		
      flat = [];		
      points.forEach (point) ->		
          flat.push(point.x)		
          flat.push(point.y)		
      return flat

  error_line: (p1, p2) ->
    el = new Konva.Line(
      points: @toFlatArray([clone_pt(p1), clone_pt(p2)]), opacity: 0.5,
      strokeHitEnabled : false,
      closed : true,
      stroke: "#F00", strokeWidth: 10 / @get_zoom_factor(),
      lineCap: "round")
    @layer.add(el)
    @remove(el)

  add_loading: -> if not @k_loading?
    @k_loading = new Konva.Text(
      x: 30, y: 30, text: "Loading...", align: "left",
      fontSize: 32, fontFamily: "Helvetica,Verdana,Ariel",
      textFill: "#000")
    @add(@k_loading)
    @draw()

  remove_loading: -> if @k_loading?
    @remove(@k_loading)
    @k_loading = null
    @draw()

  set_photo: (photo_url, polygon_data, list_activetime, namelist, ui, on_load) ->
    @add_loading()
    @photo_obj = new Image()
    @photo_obj.src = photo_url
    @photo_obj.onload = do() => =>
      @remove_loading()
      @size = compute_dimensions(@photo_obj, @bbox)
      #@stage.setWidth(@size.width)
      #@stage.setHeight(@size.height)
      @photo = new Konva.Image(
        x: 0, y: 0, image: @photo_obj,
        width: @size.width, height:@size.height)
      if polygon_data? then ui.set_polygons(polygon_data, list_activetime, namelist)
      @photo_group.add(@photo)
      @photo.moveToBottom()
      @photo.getLayer().batchDraw()
      @ready = true
      
      # adding new point for adjust mode
      $(@stage.content).on 'mousedown', (e) =>
        if ui.s.sel_poly and e.which is 3
            ui.s.addPoint(@photo.getStage().getPointerPosition())
            @stage.batchDraw()

      # deselect polygon on left click
      @photo.on 'mousedown', (e) =>
        if e.evt.which is 1 and not ui.s.panning
          ui.unselect_poly()

      on_load?()

  remove_photo: ->
    @add_loading()
    @photo_group.hide()
    @remove_loading()

  add_photo: ->
    @add_loading()
    @photo_group.show()
    @remove_loading()



