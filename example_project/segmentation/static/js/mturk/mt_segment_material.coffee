$( ->
  template_args.width = $('#mt-container').width() - 4
  template_args.height = $(window).height() - $('#mt-top-nohover').height() - 16
 # console.log("template_args.width ")
 # console.log template_args.width 
 # console.log("template_args.height ")
 # console.log template_args.height 
  template_args.container_id = 'mt-container'
  $('#poly-container').width(template_args.width).height(template_args.height)
  window.controller_ui = new ControllerUI(template_args)
)

btn_submit = ->
  if window.controller_ui.s.closed_polys?.length > 0
    window.mt_submit(window.controller_ui.get_submit_data)
  else
    #redirect to next random page
    window.location.href = window.location.origin
  
btn_finalize = ->
  window.mt_finalize(window.controller_ui.get_submit_data)
  
btn_save = ->
  window.mt_save(window.controller_ui.get_submit_data, 'in-progress')
  
btn_approve = ->
  window.mt_save(window.controller_ui.get_submit_data, 'approved')
  
btn_reject = ->
  window.mt_save(window.controller_ui.get_submit_data, 'reject')

# wait for everything to load before allowing submit
$(window).on('load', ->
  $('#btn-submit').on('click', btn_submit)
  $('#btn-approve').on('click', btn_approve)
  $('#btn-reject').on('click', btn_reject)
)

# wait for everything to load before allowing submit
$(window).on('load', ->
  $('#btn-finalize').on('click', btn_finalize)
)

# wait for everything to load before allowing submit
$(window).on('load', ->
  $('#btn-save').on('click', btn_save)
)