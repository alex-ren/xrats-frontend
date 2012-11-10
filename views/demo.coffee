$(document).ready () ->
    setup()

setup = () ->
  #Get the data
  $.get(
    "/data/trial1.json"
    (res) ->
      run(res, {time: 0.0})
    "json")

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