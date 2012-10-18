$(document).ready () ->
  setup()
  if location.href.indexOf("#") < 0
    showlast()
  else
    show(slidenumber_of_url(location.href))

  document.onkeydown = page_up_down

editor = null
slides = []

slide = null
slidenum = 0

$(window).unload () ->
  if !supports_html5_storage()
    return
  savelast(slidenum)
  save(slidenum)

setup = () ->

  editor = ats_ide("ats-ide")



  ats_add_action(editor,"reset",
    (ide)->
      0
  , (ide)->
      0
  , (ide)->
      s = $(slide)
      s.data("code", s.data("original"))
      ide.code_mirror.setValue(s.data("code"))
      ide.compile_flags = s.data("original_compile_flags")
      ide.refresh()
      save(slidenum)
  )

  ats_add_action(editor,"fullscreen",
    (ide)->
      0
  , (ide)->
      0
  , (ide)->
      ide.set_fullscreen(true)
  )


  index = $("#index").hide()

  $("#toggle-index").bind "click", () ->
    if $("#index").is(":visible")
      hide_index()
    else
      show_index()

  slides = $("div.slide")
  slides.each (i,slide) ->
    s = $(slide).hide()
    sdiv = s.find("div")
    if !s.hasClass("nocode") && sdiv.length > 0
      code = sdiv.last()
      code.remove()
      s.data("index",i)
      s.data("code",code.text().trim())
      s.data("original", code.text().trim())
      s.data("original_compile_flags", code.data("compile_flags")||[])
      s.data("compile_flags", code.data("compile_flags")||[])

    content = $('<div class="content">')
    content.html(s.html())
    s.empty().append(content)

    h2 = content.find("h2").first()
    nav
    if h2.length > 0
      $("<div/>").addClass("cl").insertAfter(h2)
      nav = $("<div/>").addClass("btn-group").addClass("pull-right")
      if i > 0
        btn = $('<button class="btn">').bind("click", () ->
          show(i-1)
        ).text("PREV").addClass("prev")
        nav.append(btn)
      if i+1 < slides.length
        btn = $('<button class="btn">').bind("click", () ->
          show(i+1)
        ).text("NEXT").addClass("next")
        nav.append(btn)
      nav.insertBefore(h2)
      curr_i = i
      entry = $("<li>").append($('<a/>').text(h2.text())).bind "click", () ->
        hide_index()
        show(curr_i)
      index.append(entry)

show = (i) ->
  if i < 0 || i >= slides.length
    return

  if slide != null
    oldslide = $(slide).hide()
    if !oldslide.hasClass("nocode")
      save(oldslide.data("index")) ||
      oldslide.data("code",editor.code_mirror.getValue())

  slidenum = i
  slide = slides[i]
  s = $(slide).show()

  if s.hasClass("nocode")
    $("#ats-ide, #ats-ide-ctl, #ats-ide-ctl-workspace").hide()
    $("#content").attr("class","span12")
  else
    $("#ats-ide, #ats-ide-ctl, #ats-ide-ctl-workspace").show()
    $("#ats-console").empty()
    $("#content").attr("class","span6")
    state = load(i) || s.data()

    editor.code_mirror.setValue(state.code)
    editor.compile_flags = state.compile_flags || []
    editor.runtime_flags = state.runtime_flags || []
    editor.code_mirror.focus()
    editor.refresh()

  url = location.href
  j = url.indexOf("#")
  if j >= 0
    url = url.substr(0,j)
  url += "#"+(slidenum+1).toString()
  location.href = url

hide_index = () ->
  $("#index").hide()
  $("#ats-ide, #content, #ats-ide-ctl, #ats-ide-ctl-workspace").show()
  $("#toggle-index").text("INDEX")

show_index = () ->
  $("#index").show()
  $("#ats-ide, #content, #ats-ide-ctl, #ats-ide-ctl-workspace").hide()
  $("#toggle-index").text("SLIDES")

save = (page) ->
  if !supports_html5_storage()
    return
  localStorage["data"+page] = JSON.stringify {
      code: editor.code_mirror.getValue(),
      compile_flags: editor.compile_flags,
      runtime_flags: editor.runtime_flags
  }

savelast = () ->
  if !supports_html5_storage()
    return
  localStorage["last"] = slidenum

showlast = () ->
  if !( supports_html5_storage() && ( 'last' in localStorage) )
    show(0)
    return

  show(parseInt(localStorage['last']))

load = (page) ->
  if !supports_html5_storage()
    return

  if stored = localStorage["data"+page]
    return JSON.parse(stored)

reset = () ->

slidenumber_of_url = (url) ->
  i = url.indexOf("#")
  if(i < 0)
    return 0;
  frag = unescape(url.substr(i+1))
  if /\d+$/.test(frag)
    i = parseInt(frag)
    id = i - 1
    if (id) < 0 || (id) > slides.length
      return 0
    return id
  return 0

page_up_down = (event) ->
  e = window.event || event
  if e.keyCode == 33 #Page up
    e.preventDefault()
    show(slidenum-1)
    return false
  if e.keyCode == 34 #Page down
    e.preventDefault()
    show(slidenum+1)
    return false
  return true

supports_html5_storage = () ->
	try
		return `'localStorage' in window && window['localStorage'] != null`
	catch e
		return false