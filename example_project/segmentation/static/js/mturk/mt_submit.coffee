# Handles submitting of tasks for mturk tasks
# Required scripts:
#   get_url_params.coffee
# Required templates:
#   modal_loading.html
#   modal_error.html

window.load_start = Date.now()
$(window).on('load', ->
  window.time_load_ms = +(Date.now() - window.load_start)
)

$( ->
  mt_submit_ready = false

  # Ready to submit with the provided data
  window.mt_submit_ready = (data_callback) ->
    if not mt_submit_ready
      mt_submit_ready = true
      btn = $('#btn-submit').removeAttr('disabled')
      if data_callback?
        btn.on('click', window.mt_submit(data_callback))

  # No longer ready to submit
  window.mt_submit_not_ready = (disable=true) ->
    if mt_submit_ready
      mt_submit_ready = false
      if disable then $('#btn-submit').attr('disabled', 'disabled').off('click')

  # Submit from javascript
  window.mt_submit = (data_callback, isFinalize=false) ->
#    console.log('isFinalize', isFinalize)
    
    mt_submit_ready = true
    do_submit = mt_submit_impl(data_callback, isFinalize)

    if (window.ask_for_feedback == true and window.show_modal_feedback? and window.feedback_bonus?)
      window.show_modal_feedback(
        'Thank you!',
        ("<p>We will give a bonus of #{window.feedback_bonus} if you help us improve " +
        'the task and answer these questions.</p>' +
        '<p>If you don\'t want to answer, just click "Submit".</p>'),
        do_submit
      )
    else
      do_submit()
      
  # Submit from javascript
  window.mt_save = (data_callback, status="in-progress") ->
    
    mt_submit_ready = true
    isFinalize = false
    isSave = true
    do_submit = mt_submit_impl(data_callback, isFinalize, isSave, status)
    do_submit()
      
  check = ->
      #console.log($('segmented-checkbox').prop("checked"), $('order-checkbox').prop("checked"), $('segmented-checkbox').prop("checked") and $('order-checkbox').prop("checked"))
      if $('#segmented-checkbox').prop("checked") and $('#order-checkbox').prop("checked")
        $("#modal-areyousure-yes").prop('disabled', false)
      else
        $("#modal-areyousure-yes").prop('disabled', true)
      
  window.mt_finalize = (data_callback) ->
    mt_submit_ready = true
    show_modal_areyousure
        label : 'Check everything'
        message : "<div class='checkbox'>
                <label>
                  <input type='checkbox' id='segmented-checkbox'> Are you sure that all object segmented?
                </label>
              </div>
              <div class='checkbox'>
                <label>
                  <input type='checkbox' id='order-checkbox'> Did you ouble check the depth orders are correct?
                </label>
              </div>"
        yes_text : "Submit",
        yes : mt_submit_impl(data_callback, true, false, 'completed')
        no_text: "Cancel"
        no: -> $("#modal-areyousure-yes").prop('disabled', false)
        
    $("#modal-areyousure-yes").prop('disabled', true)
    $('#segmented-checkbox').on 'change', check
    $('#order-checkbox').on 'change', check
    

  # Submit a partially completed task
  window.mt_submit_partial = (data) ->
    console.log "partial submit data:"
#    console.log data
    $.ajax(
      type: 'POST'
      url: window.location.href
      data: $.extend(true, {
        partial: true,
        screen_width: screen.width,
        screen_height: screen.height,
        time_load_ms: window.time_load_ms
        display_width: window.controller_ui.s.stage_ui.size.width;
        display_height: window.controller_ui.s.stage_ui.size.height;
      }, data)
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8'
      dataType: 'json'
      success: (data, status, jqxhr) ->
#        console.log "partial submit success: data:"
#        console.log data
      error: ->
        console.log "partial submit error"
    )

  # ===== private methods =====

  mt_submit_error = (msg) ->
    hide_modal_loading( -> window.show_modal_error(msg) )

  mt_submit_impl = (data_callback, isFinalize, isSave, status='in-progress') -> ->
    if not mt_submit_ready then return

    data = data_callback()
    feedback = window.get_modal_feedback?() if window.ask_for_feedback
    if feedback? and not $.isEmptyObject(feedback)
      data.feedback = JSON.stringify(feedback)

    #console.log "submit data:"
    #console.log data

    if data.errors.length
        window.show_modal_error(data.errors.join('<br>'), 'Error')
        return
    
    window.show_modal_loading("Submitting...", 0)
    
    data.status = status
    if status is 'reject'
        data.status = 'reject'
    $.ajax(
      type: 'POST'
      url: window.location.href
      data: $.extend(true, {
        screen_width: screen.width
        screen_height: screen.height
        time_load_ms: window.time_load_ms
        display_width: window.controller_ui.s.stage_ui.size.width;
        display_height: window.controller_ui.s.stage_ui.size.height;
      }, data)
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8'
      dataType: 'json'
      success: (data, status_, jqxhr) ->
#        console.log "success: data:"
#        console.log data

        host = decodeURIComponent($(document).getUrlParam('turkSubmitTo'))
        console.log "host: #{host}"

        if data.result == "success"
          if not isSave
            new_url = "#{host}/mturk/externalSubmit#{window.location.search}"
            console.log "success: redirecting to #{new_url}"
            window.location.href = window.location.origin
          else
            hide_modal_loading()
          if status is 'reject' || status is 'approved'
            next_image_url = $('#next-user-image')[0].href
            window.location.href = next_image_url
          
        else if data.result == "error"
          mt_submit_error("There was an error contacting the server; try submitting again after a few seconds... (#{data.message})")
        else
          mt_submit_error("There was an error contacting the server; try submitting again after a few seconds...")

      error: ->
        mt_submit_error("Could not connect to the server; try submitting again after a few seconds...")
    )
        
    #})
    
    
)
