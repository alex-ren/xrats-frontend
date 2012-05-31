$(document).ready ->
  setup_search()

search = (params) ->
  $.get(
    "/search"
    params
    (res) ->
      $("#search-listing").html(res)
      $('.paginate').bind "click", (event) ->
        params.offset = $(this).attr("data-offset")
        search(params)
    "html"
  )

setup_search = () ->
  $("#search-submit").bind "click", (event) =>
    $("#search-results").css "display", "inline"
    search({query:$("#search-input").attr("value"),indexes:$('#search-input').attr("data-repos")})
  $("#close-search").bind "click", (event) =>
    $("#search-results").css "display", "none"