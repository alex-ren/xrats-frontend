$(document).ready () ->
  bind_all_code()

bind_all_code = () ->
  domain = $("#ats-info").data("domain") # data-domain="xrats.com"
  $(".patsyntax").each (i, el) ->
    name = $(this).data("name")
    button = $("<button>").text("Typecheck") <button>Try it Yourself</button>
    button.attr("style","margin-top:-38px; float:right;")
    cb = $('<div style="clear:both;">')
    button.insertAfter($(this))
    cb.insertAfter(button)
    button.bind "click", () =>
      content = $(this).data("input")
      form = $("<form target='_blank' name='open-editor' method='post'>")
      form.attr "action",
        "http://www.ats-lang.org/TRYIT/#{name}")
      method = $('<input type="hidden" name="_method" value="put" />')
      form.append(method)
      code = $('<textarea name="input">')
      code.text(content)
      form.append(code)
      $("body").append(form)
      form.submit()

