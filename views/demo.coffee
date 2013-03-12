#Chrome's requestAnimationFrame gives a weird
# timestamp.
chrome_start = null

$(document).ready () ->
    chrome_start = (new Date()).getTime()
    setup()

#The drawing contexts that we'll use for the demo.
contexts = {}

state = {
  curr: {time: 0.0}
  events: []
  start: 0.0
  elevator: {
    floor: 1
    dest: -1
    arrival: 0.0
    # pos - a point on the y axis
    # Draw the elevator with its center
    # on this point.
    paint : (pos) ->
      ctx = contexts.elevator
      ctx.fillStyle = "rgb(0, 0, 0)"
      ctx.fillRect(132, pos-25, 40, 50)
  }
  direction: 0
  #Passengers waiting for service
  passengers: {}
  #Passengers onboard the elevator
  onboard: 0
  requests: {}
  #Passengers leaving
  leaving: {}
  passenger: new Image()
  up: new Image()
  down: new Image()
}


clear = (ctx) ->
  ctx.clearRect(0, 0, 300, 500)

draw_building = () ->
  ctx = contexts.elevator
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
    tta = (state.elevator.arrival - time)/1000.0
    diff = Math.abs(el.dest - el.floor)
    distance_to_go =
      if !diff || tta < 0
        0.0
      else
        tta*45.0
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

draw_passenger = (x, y, direction) ->
  ctx = contexts.elevator
  ctx.drawImage(state.passenger, x, y)
  if direction
    arrow = if direction == 'u' then state.up else state.down
    ctx.drawImage(arrow, x+17, y+15)

render_passengers = (time) ->
  ctx = contexts.elevator
  for floor,folks of state.passengers
    i = 0
    for id, info of folks
      draw_passenger(30*i, ((10-floor)*45) + 5, info.dir)
      i += 1

  #Draw Passengers leaving
  for id, info of state.leaving
    t = (time - info.left)/1000.0
    if t > 1
      delete state.leaving[id]
    #130 pixels/second
    pos = 130*t
    draw_passenger(175.0+pos, ((10-info.floor)*45.0) + 5.0)

draw_onboard = () ->
  ctx = contexts.onboard
  ctx.moveTo(0,0)
  ctx.lineWidth = 5
  ctx.strokeRect(0,0,300,100)
  ctx.lineWidth = 1
  if state.onboard > 0
    for i in [0 .. state.onboard  - 1]
      ctx.drawImage(state.passenger, 10 + i*30, 50)

draw_requests = () ->
  ctx = contexts.requests
  ctx.font = "bold 1.6em Helvetica"
  for i in [1 .. 10]
    x = 10 + (i-1) * 27
    y = 50
    if state.requests[i]
      ctx.fillStyle = "rgb(0,0,0)"
      ctx.beginPath()
      ctx.arc(x+ 6, y- 6, 12, 0, 2 * Math.PI)
      ctx.fill()
      ctx.fillStyle = "rgb(255,255,255)"
    else
      ctx.fillStyle = "rgb(0,0,0)"

    ctx.fillText(i.toString(), x, y)

render_scene = (time) ->
  clear(contexts.elevator)
  draw_building()
  render_elevator(time)
  render_passengers(time)
  clear(contexts.onboard)
  draw_onboard()
  clear(contexts.requests)
  draw_requests()

# Log an event for the user.
log = (message, time) ->
  li = $("<li>")
  li.html(message)
  li.appendTo $("#events")

run = (time) ->
  if state.events.length == 0
    #Just keep redrawing the buffer, animations
    #may need to finish after events stop.
    state.events.push({time: Infinity})

  #Firefox and Chrome give a different timestamp...
  if window.mozAnimationStartTime
    time = time - state.start
  else
    time = time - (state.start - chrome_start)

  #Get next event
  if time >= state.events[0].time
    next = state.events.shift()
    state.curr = next
    switch state.curr.tag
      when "arrive"
        state.elevator.dest = -1
        state.elevator.floor = state.curr.flr
        log("Arrived at floor #{state.curr.flr}")
      when "move"
        find_arrive = (events) ->
          for i,e of events
            if e.tag == "arrive"
              return e
          return {flr: state.elevator.floor}
        nxt = find_arrive(state.events)
        state.elevator.dest = nxt.flr
        state.elevator.arrival = nxt.time
        log("Moving from floor #{state.elevator.floor} to #{nxt.flr}")
      when "service"
        curr = state.curr
        if !state.passengers[curr.flr]
          state.passengers[curr.flr] = {}
        state.passengers[curr.flr][curr.id] = {
          dir: curr.dir
        }
        log("Passenger needs elevator at floor #{curr.flr}")
      when "request"
        curr = state.curr
        delete state.passengers[state.elevator.floor][curr.id]
        state.onboard++
        state.requests[curr.flr] = true
        log("Passenger #{curr.id} wants to go to floor #{curr.flr}")
      when "exit"
        curr = state.curr
        state.leaving[curr.id] = {
          left: time
          floor: curr.flr
        }
        state.onboard--
        state.requests[curr.flr] = false
        log("Passenger #{curr.id} left the elevator at floor #{curr.flr}")
  render_scene(time)
  window.requestAnimationFrame(run)

run_json = (res) ->
  start = new Date()
  state.events = res
  state.start = start.getTime()
  state.elevator.floor = 1
  state.elevator.destination = 0
  state.passengers = {}
  state.leaving = {}
  state.onboard = []
  window.requestAnimationFrame(run)

run_file = (input) ->
  if input.files.length == 0
    return
  file = input.files[0]
  trial_reader = new FileReader()
  trial_reader.onload = (evnt) ->
    res = JSON.parse(evnt.target.result)
    run_json(res)
    $(input).remove()

  trial_reader.readAsText(file)

get_context = (id) ->
  cs = document.getElementById(id)
  cs.getContext("2d")

setup = () ->
  requestAnimationFrame = window.requestAnimationFrame \
    || window.mozRequestAnimationFrame                 \
    || window.webkitRequestAnimationFrame              \
    || window.msRequestAnimationFrame

  window.requestAnimationFrame = requestAnimationFrame

  contexts.elevator = get_context("simulator")
  contexts.onboard = get_context("onboard")
  contexts.requests = get_context("requests")

  #Setup the sprites used.
  state.passenger.src = "/data/stick.png"
  state.up.src = "/data/up.png"
  state.down.src = "/data/down.png"

  $(".upload").on "click", () ->
    upload_elt = $("<input type='file' style='display:none'>")
    upload_elt.appendTo("<body>")
    upload_elt.on "change", (event) ->
      run_file(this)

    upload_elt.click()

  $(".trial").bind "click", () ->
    $.get(
      "/trial/#{$(this).attr("id")}.json"
      (res) ->
        run_json(res)
      "json")