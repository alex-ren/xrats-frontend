$(document).ready () ->
  CodeMirror.connect(window, "resize", () ->
    showing = $(".CodeMirror-fullscreen")[0]
    if(!showing)
      return
    else
      showing.CodeMirror.getScrollerElement().style.height = $(window).height() + "px"
  )

# Some CodeMirror Functionality
set_fullscreen = (cm, full) ->
  wrap = cm.getWrapperElement()
  scroll = cm.getScrollerElement()

  if (full)
    wrap.className += " CodeMirror-fullscreen "
    scroll.style.height = $(window).height() + "px"
    document.documentElement.style.overflow = "hidden"
  else
    wrap.className = wrap.className.replace(" CodeMirror-fullscreen", "")
    scroll.style.height = "500px"
    document.documentElement.style.overflow = ""

  cm.refresh()

is_fullscreen = (cm) ->
  return /\bCodeMirror-fullscreen\b/.test(cm.getWrapperElement().className)

archs = {
  ats: [{id: "i386",  name: "32bit Linux"},
        {id: "x86_64",name: "64bit Linux"}]
}

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
    $("##{ide.id}-ctl #attached_file").click()
  download: (ide) ->
    download_code(ide)
  download_binary: (ide) ->
    download_binary(ide)
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
    $("##{ide.id}-ctl-workspace").append(span)
    $("##{ide.id}-ctl-workspace").append(i)
  run: (ide) ->
    i = $("<input>")
    i.attr("id","runtime-flags")
    i.attr("type","text")
    i.attr("value",ide.runtime_flags.join(" "))
    span = $("<span>")
    span.attr("class","form-label")
    span.html("Runtime Arguments: ")
    $("##{ide.id}-ctl-workspace").append(span)
    $("##{ide.id}-ctl-workspace").append(i)
  download: (ide) ->
    i = $('<input id="download-filename" type="text">')
    i.attr("value",ide.filename)
    span = $("<span>")
    span.attr("class","form-label")
    span.html("Filename: ")
    $("##{ide.id}-ctl-workspace").append(span)
    $("##{ide.id}-ctl-workspace").append(i)
    #Display options
    if archs[ide.compiler]
      span = $("<span>")
      span.attr("class", "form-label")
      span.html("OS: ")
      $("#ctl-workspace").append(span)
      for ar in archs[ide.compiler]
        i = $("<input>")
        i.attr("type","radio")
        i.attr("name","arch")
        i.attr("value",ar.id)
        if ide.arch == ar.id
          i.attr("checked","true")
        $("##{ide.id}-ctl-workspace").append(i)
        $("##{ide.id}-ctl-workspace").append(ar.name)
}

save_handlers = {
  compile: (ide) ->
    ide.compile_flags = get_flags("compile")
  run: (ide) ->
    ide.runtime_flags = get_flags("runtime")
  download: (ide) ->
    ide.filename = $("#download-filename").val()
    if archs[ide.compiler]
      ide.arch = $('input:radio[name=arch]:checked').val()
}

update_handlers = {
  compile: (ide) ->
    $("##{ide.id}-ctl #compile-flags").val(ide.compile_flags.join(" "))
  run: (ide) ->
    $("##{ide.id}-ctl #runtime-flags").val(ide.runtime_flags.join(" "))
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

# Package the ide into a form and send it to
# one of the compiler's endpoints for processing.
post_ide = (ide, action, p) ->
  compiler = ide.compiler
  form = $("<form>")
  form.attr("action", "/#{compiler}/#{action}")
  form.attr("method", "post")
  params = get_compile_params(ide)
  if p
    jQuery.extend(params, p)

  for item, value of params
    input = switch $.type(value)
              when 'array'
                input_of_array(item, value)
              else
                input_of_value(item, value)
      form.append input
  form.submit()

download_code = (ide) ->
  compile_code ide, "compile",{save:1}, (res) ->
    if res.status != 0
      display_compile_results(ide, res)
      return
    post_ide(ide, "download", {original_file: res.output})

download_binary = (ide) ->
  compile_code ide, "compile", {save:1}, (res) ->
    if res.status != 0
      display_compile_results(ide, res)
      return
    post_ide(ide, "download-exe", {original_file: res.output})

handle_file = (input,ide) ->
  if input.files.length == 0
    return
  file = input.files[0]
  ide.file_reader.readAsText(file)

# Populate the ats object with options given in the HTML
# document.
load_ide_options = (id) ->
  return $("##{id} #ats-info").data()

bind_switch_state = (ide) ->
  $("##{ide.id}-ctl .switch-state").bind "click", (event) ->
    label = $(this).html()
    action = $(this).attr("data-action")
    old_action = $("##{ide.id}-ctl #ats-action").data("action")
    $("##{ide.id}-ctl #ats-action").html(label)
    $("##{ide.id}-ctl #ats-action").data("action",action)
    if save = save_handlers[old_action]
      save(ide)
    $("##{ide.id}-ctl-workspace").empty()
    if init = setup_handlers[action]
      init(ide)

make_ats_ide = (id) ->

  ide = load_ide_options(id)
  ide.id = id
  ide.marked_ranges = []

  buf = $("##{id} .code-mirror")

  if buf.length is 0
    return

  ide.code_mirror = CodeMirror.fromTextArea(buf[0], {
            mode: "ats",
            theme:"ambiance",
            lineNumbers:true,
            matchBrackets:true,
            extraKeys: {
              "F11": (cm) ->
                set_fullscreen(cm, !is_fullscreen(cm))
            , "Esc": (cm) ->
                if(is_fullscreen(cm))
                  set_fullscreen(cm, false)
            }
  })

  ide.code_mirror.getScrollerElement().style.height = 500+"px"
  ide.code_mirror.refresh()

  bind_switch_state(ide)

  $("##{ide.id}-ctl #ats-action").bind "click", (event) ->
    action = $(this).data("action")
    if cmd = dispatcher[action]
      if save = save_handlers[action]
        save(ide)
      cmd(ide)

  ide.file_reader = new FileReader()
  ide.file_reader.onload = (evnt) ->
    ide.code_mirror.setValue(evnt.target.result)

  $("##{ide.id}-ctl #attached_file").bind "change", (event) ->
    handle_file(this, ide)

  ide.refresh = () ->
    action = $("##{this.id}-ctl #ats-action").data("action")
    if update = update_handlers[action]
      update(this)

  ide.set_fullscreen = (full) ->
    set_fullscreen(ide.code_mirror, full)

  return ide

# Export the ability to create an ats editor window.
window.ats_ide = make_ats_ide

# Enable adding on to the editor's functionality
window.ats_add_action = (ide, action, save, setup, dispatch) ->
  dispatcher[action] = dispatch
  setup_handlers[action] = setup
  save_handlers[action] = save
  link = $('<a class="switch-state">')
  link.attr('data-action',action)
  link.text(action[0].toUpperCase()+action.slice(1))
  li = $("<li>").append(link)
  $("##{ide.id}-ctl #action-dropdown").append(li)
  bind_switch_state(ide)