# UI for one polygon
class PolygonUI
  constructor: (@id, @poly, @stage) ->
    # @stage is an instance of StageUI
    @line = null
    @fill = null
    @text = null
    @hover_line = null
    @hover_fill = null
    @anchors = null
    @stroke_scale = 1.0 / @stage.get_zoom_factor()
    @group = new Konva.Group()

  # update stroke scale
  update_zoom: (ui, inv_zoom_factor, redraw=true, transparent, permutate=false) ->
    @stroke_scale = inv_zoom_factor
    @update(ui, redraw, transparent, permutate)

  # update UI elements
  update: (ui, redraw=true, transparent=true, permutate=false) ->
    if @poly.open
      @remove_fill()
      @remove_text()
      @add_line()
      p = @stage.mouse_pos()
      if p? and not @poly.empty()
        @add_hover(p)
      else
        @remove_hover()
    else
      @remove_hover()
      @remove_line()
      if transparent
        @add_fill(ui, 0, permutate)
      else
        @add_fill(ui, 1, permutate)
      @add_line2()
      @add_text()
    @stage.draw()

  # remove UI elements
  remove_line: -> @stage.remove(@line); @line = null
  remove_fill: -> @stage.remove(@fill); @fill = null
  remove_text: -> @stage.remove(@text); @text = null
  remove_hover: ->
    @stage.remove(@hover_fill); @hover_fill = null
    @stage.remove(@hover_line); @hover_line = null
  remove_anchors: -> if @anchors?
    if @anchors.length < 8
      for a in @anchors
        @stage.remove(a, 0.4)
    else
      for a in @anchors
        @stage.remove(a, 0)
    @anchors = null
    @stage.draw()
  remove_all: ->
    @remove_line()
    @remove_fill()
    @remove_text()
    @remove_hover()
    @remove_anchors()

  toFlatArray: (points) ->		
    flat = [];		
    points.forEach (point) ->		
      flat.push(point.x)		
      flat.push(point.y)		
    return flat

  # add polygon fill
  add_fill: (ui, opac, permutate=false)->
    if @fill?
      if permutate
        rand_id=Math.random()*(POLYGON_COLORS.length)
        rand_id=Math.round(rand_id)
        #console.log("rand id: ", rand_id)
        #console.log("color is ", POLYGON_COLORS[rand_id % POLYGON_COLORS.length])
        @fill.setFill(POLYGON_COLORS[rand_id % POLYGON_COLORS.length])
      @fill.setPoints(@toFlatArray(@poly.points))
      @fill.setStrokeWidth(2 * @stroke_scale)
      @fill.setOpacity(opac)
    else
      @fill = new Konva.Line(
        points: @toFlatArray(@poly.points),
        fill: POLYGON_COLORS[@id % POLYGON_COLORS.length],
        closed : true, strokeHitEnabled : false,
        stroke: '#007', strokeWidth: 2 * @stroke_scale,
        lineJoin: 'round')
      @fill.on 'click', (e) =>
        # select only on left click (which = 1)
        if e.evt.which is 1 and not ui.s.panning
          ui.select_poly(@id)

      @add(@fill, opac)

  add: (o, opacity=1.0, duration=0.4)->
    if not @group.parent
      @stage.layer.add(@group)
    @group.add(o)
    if duration > 0
      o.setOpacity(0)
      o.add_trans = o.to(opacity:opacity, duration:duration)
    else
      o.setOpacity(opacity)
      
  update_text: () ->
    label = String((@order + 1))
    @text?.setText(label)
    
    # update text position
    cen = @poly.labelpos()
    pos =
      x: cen.x - 5 * label.length * @stroke_scale
      y: cen.y - 5 * @stroke_scale
    @text?.setPosition(pos)
    @text?.getLayer().batchDraw()
    
  # add text label
  add_text: ->
    if @text?
      @text.setFontSize(10 * @stroke_scale)
    else
      @text = new Konva.Text(
        text: '', fill: '#000',
        align: 'left',
        fontSize: 10 * @stroke_scale,
        listening : false,
        fontFamily: 'Verdana', fontStyle: 'bold')
      @add(@text, 1.0)
    @update_text()

  add_line: ->
    if @line?
      @line.setPoints(@toFlatArray(@poly.points))
      @line.closed(not @poly.open)
      @line.setStrokeWidth(3 * @stroke_scale)
    else
      @line = new Konva.Line(
        points: @toFlatArray(@poly.points), opacity: 0, stroke: "yellow",
        strokeHitEnabled : false, closed: not @poly.open
        strokeWidth: 3 * @stroke_scale, lineJoin: "round")
      @add(@line, 0.5)

  add_line2: ->
    pp = clone_pt(@poly.points[0])
    pplist = @poly.points.concat(pp)
    if @line?
      @line.setPoints(@toFlatArray(pplist))
      @line.closed(not @poly.open)
      @line.setStrokeWidth(3 * @stroke_scale)
    else
      @line = new Konva.Line(
        points: @toFlatArray(pplist), opacity: 0, stroke: "#00F",
        listening: false, closed: not @poly.open
        strokeWidth: 3 * @stroke_scale, lineJoin: "round")
      @add(@line, 0.5)

  add_hover: (p) ->
    @add_hover_fill(p)
    @add_hover_line(p)

  add_hover_fill: (p) ->
    hover_points = @poly.points.concat([clone_pt p])
    if @hover_fill?
      @hover_fill.setPoints(@toFlatArray(hover_points))
    else
      @hover_fill = new Konva.Line(
        points: @toFlatArray(hover_points), opacity: 0, fill: "#00F"
        closed : true, strokeHitEnabled : false
      )
      @add(@hover_fill, 0.15)

  add_hover_line: (p) ->
    hover_points = [clone_pt(p), @poly.points[@poly.num_points() - 1]]
    if @hover_line?
      @hover_line.setPoints(@toFlatArray(hover_points))
      @hover_line.setStrokeWidth(3 * @stroke_scale)
    else
      @hover_line = new Konva.Line(
        points: @toFlatArray(hover_points), opacity: 0, stroke: "yellow",
        strokeHitEnabled : false,
        strokeWidth: 3 * @stroke_scale, lineCap: "round")
      @add(@hover_line, 0.5)

    if @poly.can_push_point(p)
      @hover_line.setStroke("#00F")
      @hover_line.setStrokeWidth(3 * @stroke_scale)
    else
      @hover_line.setStroke("#00F")
      @hover_line.setStrokeWidth(3 * @stroke_scale)

  get_area: ->  # added by Zhu
    tt = @poly.area()
    console("tt here: ")
    console(tt)
    tt

  add_anchors: (ui, transparent) ->
    if ui.s.draw_mode then return

    if @anchors?
      if @anchors.length == @poly.points.length
        for p, i in @poly.points
          @anchors[i].setPosition({x: p.x, y : p.y})
          @anchors[i].setStrokeWidth(2 * @stroke_scale)
          @anchors[i].setRadius(10 * @stroke_scale)
        return
      console.log('removing anchors')
      @remove_anchors()

    @anchors = []
    for p, i in @poly.points
      v = new Konva.Circle(
        x: p.x, y: p.y,
        radius: 10 * @stroke_scale,
        strokeWidth: 2 * @stroke_scale,
        stroke: "#666", fill: "#ddd",
        name : 'anchor',
        strokeHitEnabled : false,
        opacity: 0, draggable: true)
      v.point = p

      v.on('mouseenter', do (v) => =>
        if v.removing != true
          $('canvas').css('cursor', 'pointer')
          v.setStrokeWidth(4 * @stroke_scale)
          @stage.draw()
      )
      v.on('mouseleave',  do (v) => =>
        if v.removing != true
          $('canvas').css('cursor', 'default')
          v.setStrokeWidth(2 * @stroke_scale)
          @stage.draw()
      )
      v.on('mousedown', do (i) => =>
        if v.removing != true
          ui.start_drag_point(i)
      )

      v.on('dragmove', do (i) => =>
        p = @anchors[i].getPosition()
        @poly.set_point(i, p)
        @fill.setPoints(@toFlatArray(@poly.points))
        @line.setPoints(@toFlatArray(@poly.points))
        if @fill
          if ui.drag_valid(i)
            @line.setStrokeWidth(2 * @stroke_scale)		
            @line.setStroke("#007")
            @fill.setStrokeWidth(2 * @stroke_scale)
            @fill.setStroke("#007")
          else
            @line.setStrokeWidth(10 * @stroke_scale)
            @line.setStroke("#F00")
            @fill.setStrokeWidth(2 * @stroke_scale)
            @fill.setStroke("#007")
        ui.progress_drag_point(i, p)
      )
      v.on 'dragstart', ->
        ui.update_shared_lines()
        
      v.on('dragend', do (i) => =>
        if ui.drag_valid(i)
          ui.finish_drag_point(i, @anchors[i].getPosition())
        else
          ps = ui.revert_drag_point(i)
          console.log(ps)
          if ps? then @anchors[i].setPosition({x:ps.x, y:ps.y})
        @fill.setStrokeWidth(2 * @stroke_scale)
        @fill.setStroke("#007")
        setTimeout =>
          pos = @stage.stage.getPointerPosition() || {x : 0, y :0}
          if @stage.stage.getIntersection(pos)?.getName() is 'anchor'
            $('canvas').css('cursor', 'pointer')
      )

      if @poly.points.length < 8
        @stage.add(v, 0.5, 0.4, @stage.anchorLayer)
      else
        @stage.add(v, 0.5, 0, @stage.anchorLayer)
      @anchors.push(v)
    @stage.anchorLayer.batchDraw()
    setTimeout =>
      pos = @stage.stage.getPointerPosition() || {x : 0, y :0}
      if @stage.stage.getIntersection(pos)?.getName() is 'anchor'
        $('canvas').css('cursor', 'pointer')
      
