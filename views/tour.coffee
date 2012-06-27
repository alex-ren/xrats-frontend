$(document).ready () ->
  setup()
  show(0)

slides = []

slide = null
slidenum = 0

setup = () ->
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

    content = $('<div class="content">')
    content.html(s.html())
    s.empty().append(content)

    h2 = content.find("h2").first()
    nav
    if h2.length > 0
      $("<div/>").addClass("cl").insertAfter(h2)
      nav = $("<div/>").addClass("tour-nav")
      if i+1 < slides.length
        btn = $("<button>").bind("click", () ->
          show(i+1)
        ).text("NEXT").addClass("next").addClass("pull-right")
        nav.append(btn)
      if i > 0
        btn = $("<button>").bind("click", () ->
          show(i-1)
        ).text("PREV").addClass("prev").addClass("pull-right")
        nav.append(btn)
      nav.insertBefore(h2)
      curr_i = i
      entry = $("<li>").text(h2.text()).bind "click", () ->
        hide_index()
        show(curr_i)
      index.append(entry)

show = (i) ->
  if i < 0 || i >= slides.length
    return

  if slide != null
    oldslide = $(slide).hide()
    if !oldslide.hasClass("nocode")
      save(oldslide.data("index")) || oldslide.data("code",window.ats.code_mirror.getValue())

  slidenum = i
  slide = slides[i]
  s = $(slide).show()

  if s.hasClass("nocode")
    $("#ats-ide").hide()
    $("content").attr("class","span12")
  else
    $("#ats-ide").show()
    $("#ats-console").empty()
    console.log(s.data("code"))
    window.ats.code_mirror.setValue(load(i) || s.data("code") )
    window.ats.code_mirror.focus()

  url = location.href
  j = url.indexOf("#")
  if j >= 0
    url = url.substr(0,j)
  url += "#"+(slidenum+1).toString()
  location.href = url

hide_index = () ->
  $("#index").hide()
  $("#ats-ide, #content").show()
  $("#toggle-index").text("INDEX")

show_index = () ->
  $("#index").show()
  $("#ats-ide, #content").hide()
  $("#toggle-index").text("SLIDES")

save = (page) ->
  if !supports_html5_storage()
    return
  localStorage["page"+page] = window.ats.code_mirror.getValue()

savelast = () ->
  if !supports_html5_storage()
    return
  localStorage["lastpage"] = slidenum

load = (page) ->
  if !supports_html5_storage()
    return
  return localStorage["page"+page]

supports_html5_storage = () ->
	try
		return 'localStorage' in window && window['localStorage'] != null
	catch e
		return false