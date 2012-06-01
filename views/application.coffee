$(document).ready ->
  setup_search()
  setup_code_mirror()

search = (params) ->
  $.get(
    "/search"
    params
    (res) ->
      $("#search-listing").html(res)
      $('.paginate').bind "click", (event) ->
        params.offset = $(this).attr("data-offset")
        search(params)
    "html"
  )

trigger_search = () ->
    $("#search-results").css "display", "inline"
    search({query:$("#search-input").attr("value"),indexes:$('#search-input').attr("data-repos"),offset:0})

setup_search = () ->
  $("#search-submit").bind "click", (event) =>
    trigger_search()
  $("#close-search").bind "click", (event) =>
    $("#search-results").css "display", "none"
  $("#search-input").bind "keydown", (event) =>
    if event.keyCode is 13 then trigger_search()

setup_code_mirror = () ->
  code_mirror = 0
  buf = $(".code-mirror")
  if buf.length is 0
    return
  jQuery.getScript "/javascripts/codemirror.js", (script,status,xhr) ->
    jQuery.getScript "/javascripts/emacs.js", () ->
      code_mirror = CodeMirror.fromTextArea(buf[0],{theme:"ambiance",lineNumbers:true,keyMap:"emacs"})
  $('.atscc-button').bind "click", (event) ->
    $('#ats-console').html("Waiting for the server...")
    $.post(
      "/atscc/#{$(this).attr('data-action')}",
      {input:code_mirror.getValue()}
      (res) ->
        $("#ats-console").html("<pre>#{res.output}</pre>")
      "json")