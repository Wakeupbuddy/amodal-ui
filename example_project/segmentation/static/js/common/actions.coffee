class UndoableEvent
  undo: (ui) -> throw { name: "TODO", message: "Unimplemetned Code" }
  run:  (ui) -> throw { name: "TODO", message: "Unimplemetned Code" }
  redo: (ui) -> @run(ui)
  entry: -> throw { name: "TODO", message: "Unimplemetned Code" }

class UndoRedo
  constructor: (@ui, args) ->
    @btn_undo = if args.btn_undo? then args.btn_undo else '#btn-undo'
    @btn_redo = if args.btn_redo? then args.btn_redo else '#btn-redo'

    @undo_stack = []
    @redo_stack = []

    # map events
    if @btn_undo? then $(@btn_undo).on('click', => @undo())
    if @btn_redo? then $(@btn_redo).on('click', => @redo())
    $(document).bind('keydown.z', => @undo())
    #$(document).bind('keydown.z', => @undo())
    #$(document).bind('keydown.ctrl_y', => @redo())
    $(document).bind('keydown.x', => @redo())

  run: (e) -> if e?
    e.run(@ui)
    @undo_stack.push(e)
    @redo_stack = []
    @ui.s.log.action(e.entry())
    @update_buttons()

  undo: =>
    if @can_undo()
      e = @undo_stack.pop()
      e.undo(@ui)
      @redo_stack.push(e)
      @ui.s.log.action(name: 'UndoRedo.undo')
      @update_buttons()
    else
      @ui.s.log.attempted(name: 'UndoRedo.undo')

  redo: =>
    if @can_redo()
      e = @redo_stack.pop()
      e.redo(@ui)
      @undo_stack.push(e)
      @ui.s.log.action(name: 'UndoRedo.redo', )
      @update_buttons()
    else
      @ui.s.log.attempted(name: 'UndoRedo.redo')

  can_undo: -> @undo_stack.length > 0
  can_redo: -> @redo_stack.length > 0

  update_buttons: ->
    @ui.s.update_buttons()
    if @btn_undo? then set_btn_enabled(@btn_undo, @can_undo())
    if @btn_redo? then set_btn_enabled(@btn_redo, @can_redo())


class ActionLog
  constructor: ->
    @entries = []

  # successfully performed action
  action: (args) =>
    entry = $.extend(true, {time: new Date(), done: true}, args)
    @entries.push(entry)

  # invalid action
  attempted: (args) =>
    entry = $.extend(true, {time: new Date(), done: false}, args)
    @entries.push(entry)

  get_submit_data: =>
    console.log(@entries);
    JSON.stringify(@entries)
