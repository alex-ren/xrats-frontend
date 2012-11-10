$(document).ready () ->
    setup()

setup = () ->
  #Get the data
  $.get(
    "/data/trial1.json"
    (res) ->
      run(res, {time: 0.0})
    "json")

#Maps floors to the number of passengers
#requesting them.
requests = {}

#a container of div elements to reuse.
passengers = []

make_passenger = () ->
  if passengers.length == 0
    tmp = $("<div>")
    tmp.attr("class", "stickman")
    tmp
  else
    passengers.pop()

render_event = (e, future) ->
  tag = e.tag
  switch tag
    when "move"
      curr = e.from
      diff = 0
      find_arrive = (events) ->
        for i,e of events
          if e.tag == "arrive"
            return e
        return {flr: curr}
      nxt = find_arrive(future)
      diff = nxt.flr - e.from
      dist = (diff * 50)
      time = Math.abs(diff * 1000) #one second per floor
      cmd =
        if dist > 0
          "-=#{Math.abs(dist)}"
        else
          "+=#{Math.abs(dist)}"
      $("#elevator").animate({
         top:cmd
      }, time,
      () ->
        null
      )
    when "service"
      pass = make_passenger()
      $("#floor-#{e.flr}").append(pass)
    when "arrive"
      $("#floor-#{e.flr} .stickman").animate({
          "margin-left":"130px"
      }, 1000,
        () ->
          $("#floor-#{e.flr} .stickman").remove()
      )
      if requests[e.flr] > 0
        pass = make_passenger()
        $("#floor-#{e.flr} .fr").append(pass)
        $("#floor-#{e.flr} .fr .stickman").animate({
          "margin-left":"130px"
        }, 1000,
        () ->
          $("#floor-#{e.flr} .fr .stickman").remove()
        )
        requests[e.flr] = 0
    when "request"
      if !requests[e.flr]
        requests[e.flr] = 0
      requests[e.flr] += 1

run = (events, curr) ->
  if events.length == 0
    console.log "Done"
    return 0
  next = events.shift()
  dtime = next.time - curr.time
  setTimeout( () ->
    render_event(next, events)
    run(events, next)
  , dtime)