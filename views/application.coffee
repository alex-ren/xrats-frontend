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
    search({
      query:$("#search-input").attr("value"),
      indexes:$('#search-input').attr("data-repos"),
      offset:0
    })

setup_search = () ->
  $("#search-submit").bind "click", (event) =>
    trigger_search()
  $("#close-search").bind "click", (event) =>
    $("#search-results").css "display", "none"
  $("#search-input").bind "keydown", (event) =>
    if event.keyCode is 13
      trigger_search()

get_flags = (name) ->
  if flags = $("##{name}-flags").val()
    return flags.split(" ")
  return []
  end

get_compile_params = () ->
  cflags = get_flags("compile")
  rflags = get_flags("runtime")
  filename = $("#filename").val()
  if !filename
    filename = window.ats.hashcode
  {
    input:code_mirror.getValue(),
    compile_flags:cflags,
    runtime_flags:rflags,
    hashcode:window.ats.hashcode,
    arch:window.ats.arch,
    filename:filename
  }


# Send a command to the compiler.
compile_code = (action,pm,call) ->
  compiler = window.ats.compiler
  params = get_compile_params()
  for k,v of pm
    params[k] = v
  $('#ats-console').html("Waiting for the server...")
  $.post(
    "/#{compiler}/#{action}"
    params
    (res) ->
      res.action = action
      if call
        $('#ats-console').html("")
        call(res)
      else
        display_compile_results(res)
    "json")

display_compile_results = (res) ->
  compiler = window.ats.compiler
  result = if res.status == 0 then 'success' else 'failed'
  window._gaq.push(['_trackEvent',compiler,res.action,result])
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
    ls = $(element).attr("data-line-start")-1
    cs = $(element).attr("data-char-start")-1
    le = $(element).attr("data-line-end")-1
    ce = $(element).attr("data-char-end")-1
    from = {line:ls,ch:cs}
    to = {line:le,ch:ce}
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

input_of_array = (item,values) ->
  inputs = []
  for v in values
    i = $("<input>")
    i.attr("name","#{item}[]")
    i.attr("value",v)
    inputs.push i[0]
  return inputs

input_of_value = (item,value) ->
  i = $("<input>")
  i.attr("name",item)
  i.attr("value",value)
  return i

# First, compile the current code to see if it
# works alright. Then, construct a form and
# submit it to prompt the download.
download_code = () ->
  compile_code "compile",{save:1}, (res) ->
    if res.status != 0
      display_compile_results(res)
      return
    compiler = window.ats.compiler
    form = $("<form>")
    form.attr("action","/#{compiler}/download")
    form.attr("method","post")
    params = get_compile_params()
    params.original_file = res.output
    for item, value of params
      input = switch $.type(value)
              when 'array'
                input_of_array(item,value)
              else
                input_of_value(item,value)
      form.append input
    form.submit()

handle_file = () ->
  if this.files.length == 0
    return
  file = this.files[0]
  file_reader.readAsText(file)

setup_code_mirror = () ->
  window.ats.compiler = $('#ats-info').attr("data-compiler")
  window.ats.hashcode = $('#ats-info').attr("data-hashcode")
  window.ats.arch = $('#ats-info').attr("data-arch")
  buf = $(".code-mirror")

  if buf.length is 0
    return

  jQuery.getScript "/javascripts/codemirror.js", (script,status,xhr) ->
    jQuery.getScript "/javascripts/emacs.js", () ->
      code_mirror = CodeMirror.fromTextArea(buf[0], {
          theme:"ambiance",
          lineNumbers:true,
          keyMap:"emacs",
          matchBrackets:true
      })
      $(code_mirror.getScrollerElement()).height(500)
      code_mirror.refresh();

  $('.atscc-button').bind "click", (event) ->
    compile_code($(this).attr('data-action'))

  $('.download-c').bind "click", (event) ->
    download_code()

  file_reader = new FileReader()
  file_reader.onload = (evnt) ->
    code_mirror.setValue(evnt.target.result)

  attached_file = $('#attached_file')
  attached_file.bind "change", handle_file
  $('.attach_file').bind "click", (e) ->
    if(attached_file)
      attached_file.click()