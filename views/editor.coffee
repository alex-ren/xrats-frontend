dispatcher = {
  typecheck: (ide) ->
    compile_code(ide,"typecheck")
  save: (ide) ->
    compile_code(ide,"save")
  compile: (ide) ->
    compile_code(ide,"compile")
  run: (ide) ->
    compile_code(ide,"run")
  upload: (ide) ->
    $('#attached_file').click()
  download: (ide) ->
    download_code(ide)
}

setup_handlers = {
  compile: (ide) ->
    i = $("<input>")
    i.attr("id","compile-flags")
    i.attr("type","text")
    i.attr("value",ide.compile_flags.join(" "))
    span = $("<span>")
    span.attr("class","form-label")
    span.html("Compiler Flags: ")
    $("#ctl-workspace").append(span)
    $("#ctl-workspace").append(i)
  run: (ide) ->
    i = $("<input>")
    i.attr("id","runtime-flags")
    i.attr("type","text")
    i.attr("value",ide.runtime_flags.join(" "))
    span = $("<span>")
    span.attr("class","form-label")
    span.html("Runtime Arguments: ")
    $("#ctl-workspace").append(span)
    $("#ctl-workspace").append(i)
  download: (ide) ->
    i = $('<input id="download-filename" type="text">')
    i.attr("value",ide.filename)
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
    if ide.arch == "x86_64"
      i.attr("checked","true")
    $("#ctl-workspace").append(i)
    $("#ctl-workspace").append("64bit Linux")
    i = $("<input>")
    i.attr("type","radio")
    i.attr("name","arch")
    i.attr("value","i386")
    if ide.arch == "i386"
      i.attr("checked","true")
    $("#ctl-workspace").append(i)
    $("#ctl-workspace").append("32bit Linux")
}

save_handlers = {
  compile: (ide) ->
    ide.compile_flags = get_flags("compile")
  run: (ide) ->
    ide.runtime_flags = get_flags("runtime")
  download: (ide) ->
    ide.filename = $("#download-filename").val()
    ide.arch = $('input:radio[name=arch]:checked').val()
}

get_flags = (name) ->
  if flags = $("##{name}-flags").val()
    return flags.split(" ")
  return []
  end

get_compile_params = (ide) ->
  filename = ide.filename
  if !filename
    filename = ide.hashcode
  {
    input: ide.code_mirror.getValue(),
    compile_flags: ide.compile_flags,
    runtime_flags: ide.runtime_flags,
    hashcode: ide.hashcode,
    arch: ide.arch,
    filename: filename
  }

display_compile_results = (ide, res) ->
  compiler = ide.compiler
  result = if res.status == 0 then 'success' else 'failed'
  window._gaq.push(['_trackEvent',compiler,res.action,result])
  cnt_lines = ide.code_mirror.lineCount()
  for i in [0..cnt_lines]
    ide.code_mirror.setLineClass(i)
  for range in ide.marked_ranges
    range.clear()
  ide.marked_ranges = []
  $("#ats-console").html("<pre>#{res.output}</pre>")
  for element in $(".point-error")
    line = $(element).attr("data-line") - 1
    ide.code_mirror.setLineClass(line,"cm-error","cm-error")
  for element in $(".range-error")
    ls = $(element).attr("data-line-start")-1
    cs = $(element).attr("data-char-start")-1
    le = $(element).attr("data-line-end")-1
    ce = $(element).attr("data-char-end")-1
    from = {line:ls,ch:cs}
    to = {line:le,ch:ce}
    marked = ide.code_mirror.markText(from,to,"cm-error")
    ide.marked_ranges.push marked

  focus_point = (point) ->
    coords = ide.code_mirror.charCoords(point,"local")
    ide.code_mirror.scrollTo(coords.x,coords.y)
    ide.code_mirror.setCursor(point)
    ide.code_mirror.focus()

  $(".point-error").bind "click", (e) ->
    line = $(this).attr("data-line") - 1
    char = $(this).attr("data-char") - 1
    focus_point({line:line,ch:char})
  $(".range-error").bind "click", (e) ->
    line = $(this).attr("data-line-start") - 1
    char = $(this).attr("data-char-start") - 1
    focus_point({line:line,ch:char})

# Send a command to the compiler.
compile_code = (ide, action, pm, call) ->
  compiler = ide.compiler
  params = get_compile_params(ide)
  for k,v of pm
    params[k] = v
  $('#ats-console').html("Waiting for the server...")
  $.post(
    "/#{compiler}/#{action}"
    params
    (res) ->
      res.action = action
      if call
        $('#ats-console').empty()
        call(res)
      else
        display_compile_results(ide,res)
    "json")

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
download_code = (ide) ->
  compile_code ide, "compile",{save:1}, (res) ->
    if res.status != 0
      display_compile_results(ide,res)
      return
    compiler = ide.compiler
    form = $("<form>")
    form.attr("action","/#{compiler}/download")
    form.attr("method","post")
    params = get_compile_params(ide)
    params.original_file = res.output
    for item, value of params
      input = switch $.type(value)
              when 'array'
                input_of_array(item,value)
              else
                input_of_value(item,value)
      form.append input
    form.submit()

handle_file = (input,ide) ->
  if input.files.length == 0
    return
  file = input.files[0]
  ide.file_reader.readAsText(file)

# Populate the ats object with options given in the HTML
# document.
load_ide_options = (id) ->
  ide = $("##{id} #ats-info").data()
  ide.compile_flags = ide.compileFlags || []
  ide.runtime_flags = ide.runtimeFlags || []
  return ide

make_ats_ide = (id) ->

  ide = load_ide_options(id)
  ide.id = id
  ide.marked_ranges = []

  buf = $("##{id} .code-mirror")

  if buf.length is 0
    return

  ide.code_mirror = CodeMirror.fromTextArea(buf[0], {
            theme:"ambiance",
            lineNumbers:true,
            keyMap:"emacs",
            matchBrackets:true
  })
  $(ide.code_mirror.getScrollerElement()).height(500)
  ide.code_mirror.refresh()

  $("##{id} .switch-state").bind "click", (event) ->
    label = $(this).html()
    action = $(this).attr("data-action")
    old_action = $("#ats-action").data("action")
    $("##{id} #ats-action").html(label)
    $("##{id} #ats-action").data("action",action)
    if save = save_handlers[old_action]
      save(ide)
    $("##{id} #ctl-workspace").empty()
    if init = setup_handlers[action]
      init(ide)

  $('#ats-action').bind "click", (event) ->
    action = $(this).data("action")
    if cmd = dispatcher[action]
      if save = save_handlers[action]
        save(ide)
      cmd(ide)

  ide.file_reader = new FileReader()
  ide.file_reader.onload = (evnt) ->
    ide.code_mirror.setValue(evnt.target.result)

  $('#attached_file').bind "change", (event) ->
    handle_file(this,ide)

  return ide

# Export the ability to create an ats editor window.
window.ats_ide = make_ats_ide