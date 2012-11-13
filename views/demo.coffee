$(document).ready () ->
    setup()

state = {
  curr: {time: 0.0}
  events: []
  start: 0.0
  elevator: {
    floor: 1
    dest: -1
    arrival: 0.0
    #pos - a point on the y axis
    # Draw the elevator with its center
    # on this point.
    paint : (pos) ->
      ctx = context()
      ctx.fillStyle = "rgb(0, 0, 0)"
      ctx.fillRect(132, pos-25, 40, 50)
  }
}

context = () ->
  cs = document.getElementById("simulator")
  return cs.getContext("2d")

clear = () ->
  ctx = context()
  ctx.clearRect(0, 0, 300, 500)

draw_building = () ->
  ctx = context()
  #Floors
  for i in [1..10]
    ctx.fillStyle = "rgb(0, 0, 0)"
    ctx.fillRect(0, i*45, 130, 5)
    ctx.fillRect(175, i*45, 130, 5)

point_of_floor = (floor) ->
    return ((10 - floor) * 45) + 25

render_elevator = (time) ->
  #Elevator is moving
  if state.elevator.dest > 0
    #find the elevator's current position along its path
    #1 floor/second 45 pixels/floor = 45 pixels/second
    el = state.elevator
    tta = (state.elevator.arrival - time)/1000
    diff = Math.abs(el.dest - el.floor)
    distance_to_go =
      if !diff || tta < 0
        0
      else
        tta*45
    dest = point_of_floor(el.dest)
    cntr =
      if el.dest > el.floor
        dest + distance_to_go
      else
        dest - distance_to_go
    state.elevator.paint(cntr)
  else
    pt = point_of_floor(state.elevator.floor)
    state.elevator.paint(pt)

render_scene = (time) ->
  clear()
  draw_building()
  render_elevator(time)

run = (time) ->
  if state.events.length == 0
    return 0

  time = time - state.start

  #Get next event
  if time >= state.events[0].time
    next = state.events.shift()
    state.curr = next
    state.curr.flr = parseInt(state.curr.flr)
    switch state.curr.tag
      when "arrive"
        state.elevator.dest = -1
        state.elevator.floor = state.curr.flr
      when "move"
        find_arrive = (events) ->
          for i,e of events
            if e.tag == "arrive"
              return e
          return {flr: state.elevator.floor}
        nxt = find_arrive(state.events)
        console.log(nxt.flr)
        state.elevator.dest = nxt.flr
        state.elevator.arrival = nxt.time
  
  render_scene(time)
  window.requestAnimationFrame(run)

setup = () ->
  requestAnimationFrame = window.requestAnimationFrame \
    || window.mozRequestAnimationFrame                 \
    || window.webkitRequestAnimationFrame              \
    || window.msRequestAnimationFrame

  window.requestAnimationFrame = requestAnimationFrame

  #Get the data
  $.get(
    "/data/trial1.json"
    (res) ->
      start = new Date()
      state.events = res
      state.start = start.getTime()
      window.requestAnimationFrame(run)
    "json")

#Map floors to the number of passengers
#requesting them.
requests = {}

#a container of div elements to reuse.
passengers = []