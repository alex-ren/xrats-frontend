$(document).ready () ->
  bind_all_code()

bind_all_code = () ->
  domain = $("#ats-info").data("domain")
  $(".patsyntax").each (i, el) ->
    button = $("<button>").text("Typecheck")
    button.attr("style","margin-top:-38px; float:right;")
    cb = $('<div style="clear:both;">')
    button.insertAfter($(this))
    cb.insertAfter(button)
    button.bind "click", () =>
      content = $(this).data("input")
      form = $("<form target='_blank' name='open-editor' method='post'>")
      form.attr "action",
        "http://#{domain}/code/patsopt"
      method = $('<input type="hidden" name="_method" value="put" />')
      form.append(method)
      code = $('<textarea name="input">')
      code.text(content)
      form.append(code)
      $("body").append(form)
      form.submit()

