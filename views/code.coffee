$(document).ready () ->
  editor = ats_ide("ats-ide")

  ats_add_action(editor, "fullscreen",
    (ide) ->
      0
    , (ide) ->
      0
    , (ide) ->
      ide.set_fullscreen(true)
  )