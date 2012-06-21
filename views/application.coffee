$(document).ready ->
  setup_search()
  setup_code_mirror()

code_mirror = 0
file_reader = 0

marked_ranges = []

this.ats = {}
this.ats.compile_code = compile_code

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

compile_code = (action) ->
  compiler = window.ats.compiler
  $('#ats-console').html("Waiting for the server...")
  if cflags = $("#compile-flags").val()
    cflags = cflags.split(" ")
  else
    cflags = []
  if  rflags = $("#runtime-flags").val()
    rflags = rflags.split(" ")
  else
    rflags = []
  $.post(
    "/#{compiler}/#{action}",
    {input:code_mirror.getValue(),compile_flags:cflags,runtime_flags:rflags, hashcode:window.ats.hashcode}
    (res) ->
      result = if res.status == 0 then 'success' else 'failed'
      window._gaq.push(['_trackEvent',compiler,action,result])
      cnt_lines = code_mirror.lineCount()
      for i in [0..cnt_lines]
        code_mirror.setLineClass(i)
      for range in marked_ranges
        range.clear()
      marked_ranges = []
      $("#ats-console").html("<pre>#{res.output}</pre>")
      for element in $(".point-error")
          line = $(element).attr("data-line") - 1
          code_mirror.setLineClass(line,"cm-error","cm-error")
      for element in $(".range-error")
          from = {line:$(element).attr("data-line-start")-1,ch:$(element).attr("data-char-start")-1}
          to = {line:$(element).attr("data-line-end")-1,ch:$(element).attr("data-char-end")-1}
          marked = code_mirror.markText(from,to,"cm-error")
          marked_ranges.push marked
      focus_point = (point) ->
        coords = code_mirror.charCoords(point,"local")
        code_mirror.scrollTo(coords.x,coords.y)
        code_mirror.setCursor(point)
        code_mirror.focus()
      $(".point-error").bind "click", (e) ->
        line = $(this).attr("data-line") - 1
        char = $(this).attr("data-char") - 1
        focus_point({line:line,ch:char})
      $(".range-error").bind "click", (e) ->
        line = $(this).attr("data-line-start") - 1
        char = $(this).attr("data-char-start") - 1
        focus_point({line:line,ch:char})
    "json")

handle_file = () ->
  if this.files.length == 0
    return
  file = this.files[0]
  file_reader.readAsText(file)

setup_code_mirror = () ->
  window.ats.compiler = $('#ats-info').attr("data-compiler")
  window.ats.hashcode = $('#ats-info').attr("data-hashcode")
  buf = $(".code-mirror")
  if buf.length is 0
    return
  jQuery.getScript "/javascripts/codemirror.js", (script,status,xhr) ->
    jQuery.getScript "/javascripts/emacs.js", () ->
      code_mirror = CodeMirror.fromTextArea(buf[0],{theme:"ambiance",lineNumbers:true,keyMap:"emacs",matchBrackets:true})
      $(code_mirror.getScrollerElement()).height(500);
      code_mirror.refresh();
  $('.atscc-button').bind "click", (event) ->
    compile_code($(this).attr('data-action'))
  file_reader = new FileReader()
  file_reader.onload = (evnt) ->
    code_mirror.setValue(evnt.target.result)
  attached_file = $('#attached_file')
  attached_file.bind "change", handle_file
  $('.attach_file').bind "click", (e) ->
    if(attached_file)
      attached_file.click()