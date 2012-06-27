$(document).ready ->
  setup_search()
  setup_ide()

file_reader = 0

marked_ranges = []

this.ats = {}
this.ats.compile_code = compile_code
this.ats.code_mirror = 0

this.ats.dispatcher = {
  typecheck: () ->
    compile_code("typecheck")
  save: () ->
    compile_code("save")
  compile: () ->
    compile_code("compile")
  run: () ->
    compile_code("run")
  upload: () ->
    $('#attached_file').click()
  download: () ->
    download_code()
}


this.ats.setup = {
  compile: () ->
    i = $("<input>")
    i.attr("id","compile-flags")
    i.attr("type","text")
    i.attr("value",window.ats.compile_flags.join(" "))
    span = $("<span>")
    span.attr("class","form-label")
    span.html("Compiler Flags: ")
    $("#ctl-workspace").append(span)
    $("#ctl-workspace").append(i)
  run: () ->
    i = $("<input>")
    i.attr("id","runtime-flags")
    i.attr("type","text")
    i.attr("value",window.ats.runtime_flags.join(" "))
    span = $("<span>")
    span.attr("class","form-label")
    span.html("Runtime Arguments: ")
    $("#ctl-workspace").append(span)
    $("#ctl-workspace").append(i)
  download: () ->
    i = $('<input id="download-filename" type="text">')
    i.attr("value",window.ats.filename)
    span = $("<span>")
    span.attr("class","form-label")
    span.html("Filename: ")
    $("#ctl-workspace").append(span)
    $("#ctl-workspace").append(i)
    span = $("<span>")
    span.attr("class","form-label")
    span.html("OS: ")
    $("#ctl-workspace").append(span)
    i = $("<input>")
    i.attr("type","radio")
    i.attr("name","arch")
    i.attr("value","x86_64")
    if window.ats.arch == "x86_64"
      i.attr("checked","true")
    $("#ctl-workspace").append(i)
    $("#ctl-workspace").append("64bit Linux")
    i = $("<input>")
    i.attr("type","radio")
    i.attr("name","arch")
    i.attr("value","i386")
    if window.ats.arch == "i386"
      i.attr("checked","true")
    $("#ctl-workspace").append(i)
    $("#ctl-workspace").append("32bit Linux")
}

this.ats.save = {
  compile: () ->
    window.ats.compile_flags = get_flags("compile")
  run: () ->
    window.ats.runtime_flags = get_flags("runtime")
  download: () ->
    window.ats.filename = $("#download-filename").val()
    window.ats.arch = $('input:radio[name=arch]:checked').val()
}

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
  filename = window.ats.filename
  if !filename
    filename = window.ats.hashcode
  {
    input: window.ats.code_mirror.getValue(),
    compile_flags: window.ats.compile_flags,
    runtime_flags: window.ats.runtime_flags,
    hashcode: window.ats.hashcode,
    arch: window.ats.arch,
    filename: filename
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
  cnt_lines = window.ats.code_mirror.lineCount()
  for i in [0..cnt_lines]
    window.ats.code_mirror.setLineClass(i)
  for range in marked_ranges
    range.clear()
  marked_ranges = []
  $("#ats-console").html("<pre>#{res.output}</pre>")
  for element in $(".point-error")
    line = $(element).attr("data-line") - 1
    window.ats.code_mirror.setLineClass(line,"cm-error","cm-error")
  for element in $(".range-error")
    ls = $(element).attr("data-line-start")-1
    cs = $(element).attr("data-char-start")-1
    le = $(element).attr("data-line-end")-1
    ce = $(element).attr("data-char-end")-1
    from = {line:ls,ch:cs}
    to = {line:le,ch:ce}
    marked = window.ats.code_mirror.markText(from,to,"cm-error")
    marked_ranges.push marked

  focus_point = (point) ->
    coords = window.ats.code_mirror.charCoords(point,"local")
    window.ats.code_mirror.scrollTo(coords.x,coords.y)
    window.ats.code_mirror.setCursor(point)
    window.ats.code_mirror.focus()
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

# Populate the ats object with options given in the HTML
# document.
load_ide_options = () ->
  window.ats.compiler = $('#ats-info').attr("data-compiler")
  window.ats.hashcode = $('#ats-info').attr("data-hashcode")
  window.ats.arch = $('#ats-info').attr("data-arch")
  compile_flags = $('#ats-info').attr("data-compile-flags")
  runtime_flags = $('#ats-info').attr("data-runtime-flags")
  window.ats.filename = $('#ats-info').attr("data-export-file")
  window.ats.compile_flags = jQuery.parseJSON(compile_flags)
  window.ats.runtime_flags = jQuery.parseJSON(runtime_flags)

setup_ide = () ->

  load_ide_options()

  buf = $(".code-mirror")

  if buf.length is 0
    return

  jQuery.getScript "/javascripts/codemirror.js", (script,status,xhr) ->
    jQuery.getScript "/javascripts/emacs.js", () ->
      window.ats.code_mirror = CodeMirror.fromTextArea(buf[0], {
          theme:"ambiance",
          lineNumbers:true,
          keyMap:"emacs",
          matchBrackets:true
      })
      $(window.ats.code_mirror.getScrollerElement()).height(500)
      window.ats.code_mirror.refresh();

  $('.switch-state').bind "click", (event) ->
    label = $(this).html()
    action = $(this).attr("data-action")
    old_action = $("#ats-action").attr("data-action")
    $("#ats-action").html(label)
    $("#ats-action").attr("data-action",action)
    if save = window.ats.save[old_action]
      save()
    $("#ctl-workspace").html("")
    if init = window.ats.setup[action]
      init()

  $('#ats-action').bind "click", (event) ->
    action = $(this).attr("data-action")
    if cmd = window.ats.dispatcher[action]
      if save = window.ats.save[action]
        save()
      cmd()

  file_reader = new FileReader()
  file_reader.onload = (evnt) ->
    window.ats.code_mirror.setValue(evnt.target.result)

  $('#attached_file').bind "change", handle_file