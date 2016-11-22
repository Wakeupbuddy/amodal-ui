# Control encapsulated into UndoableEvent objects
class UEToggleMode extends UndoableEvent
  constructor: ->
    @open_points = null
    @sel_poly_id = null

  run: (ui) ->
    if ui.s.draw_mode
      if ui.s.open_poly?
        @open_points = ui.s.open_poly.poly.clone_points()
    else
      @sel_poly_id = ui.s.sel_poly?.id
    ui.s.toggle_mode()
    ui.s.update_buttons()

  redo: (ui) ->
    ui.s.toggle_mode()
    ui.s.update_buttons()

  undo: (ui) ->
    ui.s.toggle_mode()
    if ui.s.draw_mode
      if @open_points?
        ui.s.create_poly(@open_points)?.update(ui, true, ui.s.transparent)
    else
      if @sel_poly_id?
        ui.s.select_poly(ui, @sel_poly_id)?.update(ui, true, ui.s.transparent)

  entry: -> { name: "UEToggleMode" }

class UERemoveOpenPoly extends UndoableEvent
  constructor: ->
    @open_points = null

  run: (ui) ->
    if ui.s.open_poly?
      @open_points = ui.s.open_poly.poly.clone_points()
    ui.s.remove_open_poly()
    ui.s.update_buttons()
    ui.update_shared_lines()

  redo: (ui) ->
    ui.s.remove_open_poly()
    ui.s.update_buttons()
    ui.update_shared_lines()

  undo: (ui) ->
    if @open_points?
      ui.s.create_poly(@open_points)?.update(ui, true, ui.s.transparent)
      ui.s.resort()
    ui.update_shared_lines()

  entry: -> { name: "UERemoveOpenPoly" }

class UEPushPoint extends UndoableEvent
  constructor: (p) -> @p = clone_pt(p)
  run: (ui) ->
      ui.s.push_point(@p)?.update(ui, true, ui.s.transparent)
      ui.update_shared_lines()
  undo: (ui) ->
      ui.s.pop_point()?.update(ui, true, ui.s.transparent)
      ui.update_shared_lines()
  entry: -> { name: "UEPushPoint", args: { p: @p } }

class UEPushClosestPoint_toLine extends UndoableEvent  # added by Zhu
  constructor: (p) -> @p = clone_pt(p)
  run: (ui) ->
      data = ui.s.push_closest_point_toLine(@p)
      if data.poly
        @data = data
        if data.closestPoly
            @index_in_closed = data.closestPoly.poly.add_new_point(data.point, {skipCheckIntersect : true})
            @index_data_in_open = ui.s.share_edge(data.closestPoly)
            data.closestPoly.update(ui, true, ui.s.transparent)
        ui.update_shared_lines()
        data.poly.update(ui, true, ui.s.transparent)
      else
        console.warn('can not snap here')
        
  undo: (ui) ->
      ui.s.pop_point()?.update(ui, true, ui.s.transparent)
      if @data and @index and @data.closestPoly
         @data.closestPoly.poly.remove_point_from_index(@index)
         @data.closestPoly.update(ui, true, ui.s.transparent)
      if @index_data_in_open
        from = @index_data_in_open.fromIndex
        to = from + @index_data_in_open.pointsNumber
        for i in [to..from]
            @data.poly.poly.remove_point_from_index(i)
        @data.poly.update(ui, true, ui.s.transparent)
      ui.update_shared_lines()
         
  entry: -> { name: "UEPushClosestPoint_toLine", args: { p: @p } }

class UEPushClosestPoint_toCorner extends UndoableEvent  # added by Zhu
  constructor: (p) -> @p = clone_pt(p)
  run: (ui) ->
      @data = ui.s.push_closest_point_toCorner(@p)
      if @data?.closestPoly
        @index_data_in_open = ui.s.share_edge(@data.closestPoly)
        @data.poly.update(ui, true, ui.s.transparent)
        
  undo: (ui) ->
      ui.s.pop_point()?.update(ui, true, ui.s.transparent)
      if @index_data_in_open
        from = @index_data_in_open.fromIndex
        to = from + @index_data_in_open.pointsNumber
        for i in [to..from]
            @data.poly.poly.remove_point_from_index(i)
            @data.poly.update(ui, true, ui.s.transparent)
            
  entry: -> { name: "UEPushClosestPoint_toCorner", args: { p: @p } }

class UECreatePolygon extends UndoableEvent
  constructor: (p) -> @p = clone_pt(p)
  run: (ui) ->
      ui.s.create_poly([@p])?.update(ui, true, ui.s.transparent)
      ui.s.resort()
      ui.update_shared_lines()
  undo: (ui) ->
      ui.s.remove_open_poly()?.update(ui, true, ui.s.transparent)
      ui.s.resort()
      ui.update_shared_lines()
  entry: -> { name: "UECreatePolygon", args: { p: @p } }

class UEClosePolygon extends UndoableEvent
  run: (ui) -> 
    ui.s.close_poly()?.update(ui, true, ui.s.transparent)
    ui.s.resort()
    ui.update_polygon_dropdown()
    ui.update_order_sortable()
    ui.update_shared_lines()
  undo: (ui) -> 
    ui.s.unclose_poly()?.update(ui, true, ui.s.transparent)
    ui.s.resort()
    ui.update_polygon_dropdown()
    ui.update_order_sortable()
    ui.update_shared_lines()
  entry: -> { name: "UEClosePolygon" }

class UESelectPolygon extends UndoableEvent
  constructor: (@id) ->
  run: (ui) ->
    @sel_poly_id = ui.s.sel_poly?.id
    ui.s.select_poly(ui, @id)
  undo: (ui) ->
    if @sel_poly_id?
      ui.s.select_poly(ui, @sel_poly_id)
    else
      ui.s.unselect_poly()
  redo: (ui) ->
    ui.s.select_poly(ui, @id)
  entry: -> { name: "UESelectPolygon", args: { id: @id } }

class UEUnselectPolygon extends UndoableEvent
  constructor: () ->
  run: (ui) ->
    @sel_poly_id = ui.s.sel_poly?.id
    ui.s.unselect_poly()
  undo: (ui) ->
    if @sel_poly_id?
      ui.s.select_poly(ui, @sel_poly_id)
  redo: (ui) ->
    ui.s.unselect_poly()
  entry: -> { name: "UEUnselectPolygon" }

class UEDeletePolygon extends UndoableEvent
  run: (ui) ->
    @points = ui.s.sel_poly.poly.clone_points()
    @time_ms = ui.s.sel_poly.time_ms
    @time_active_ms = ui.s.sel_poly.time_active_ms
    @sel_poly_id = ui.s.sel_poly.id
    @poly_order = ui.s.sel_poly.order
    @poly_name = ui.s.sel_poly.name
    ui.s.delete_sel_poly()
    for p,i in ui.s.closed_polys
      #p.id = i
      p.update(ui, true, ui.s.transparent)
    ui.update_polygon_dropdown()
    ui.update_order_sortable()
    ui.s.resort()
    ui.update_shared_lines()
  undo: (ui) ->
    poly = ui.s.insert_closed_poly(@points, @sel_poly_id, @poly_order,
      @time_ms, @time_active_ms)
    poly.name = @poly_name
    for p,i in ui.s.closed_polys
      #p.id = i
      p.update(ui, true, ui.s.transparent)
    ui.s.select_poly(ui, @sel_poly_id)
    ui.s.resort()
    ui.update_polygon_dropdown()
    ui.update_order_sortable()
    ui.update_shared_lines()
  entry: -> { name: "UEDeletePolygon" }

class UEDragVertex extends UndoableEvent
  constructor: (@i, p0, p1) ->
    @p0 = clone_pt(p0)
    @p1 = clone_pt(p1)
  run: (ui) ->
    sp = ui.s.sel_poly
    sp.poly.set_point(@i, @p1)
    sp.anchors[@i].setPosition({x:@p1.x, y:@p1.y})
    sp.update(ui, true, ui.s.transparent)
    ui.update_shared_lines()
  undo: (ui) ->
    sp = ui.s.sel_poly
    sp.poly.set_point(@i, @p0)
    sp.anchors[@i].setPosition({x:@p0.x, y:@p0.y})
    sp.update(ui, true, ui.s.transparent)
    ui.update_shared_lines()
  entry: -> { name: "UEDragVertex", args: { i: @i, p0: @p0, p1: @p1 } }
  
  
class UERemoveAnchor extends UndoableEvent
  constructor: (@anchor, @polygon_ui) ->
      @point = @anchor.point
  run: (ui) ->
      poly_ui = ui.s.sel_poly
      @index = poly_ui.poly.remove_point(@point)
      
      poly_ui.add_anchors(ui, ui.s.transparent)
      poly_ui.update(ui, true, ui.s.transparent)
      ui.update_shared_lines()
  undo: (ui) ->
      poly_ui = ui.s.sel_poly
      poly_ui.poly.add_point_to_index(@point, @index)
      
      
      poly_ui.add_anchors(ui, ui.s.transparent)
      poly_ui.update(ui, true, ui.s.transparent)
      ui.update_shared_lines()
  entry: -> { name: "UERemoveAnchor", args: { i: @index, poly_id: @polygon_ui.id } }
  
  
class UEAddPoint extends UndoableEvent
  constructor: (@point) ->
  run: (ui) ->
      poly_ui = ui.s.sel_poly
      
      @index = poly_ui.poly.add_new_point(@point)
      
      poly_ui.add_anchors(ui, ui.s.transparent)
      poly_ui.update(ui, true, ui.s.transparent)
      ui.update_shared_lines()
  undo: (ui) ->
      if !@index
        return
      poly_ui = ui.s.sel_poly
      poly_ui.poly.remove_point_from_index(@index)
      

      poly_ui.add_anchors(ui, ui.s.transparent)
      poly_ui.update(ui, true, ui.s.transparent)
      ui.update_shared_lines()
      
  entry: -> { name: "UEAddPoint", args: { i: @index, point: @point } }
