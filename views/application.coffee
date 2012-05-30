$(document).ready ->
  setup_search()

setup_search =
  () ->
    $("#search-submit").bind "click", (event) =>
      $("#search-results").css "display", "inline"
      $.get(
        "/search"
        {query:$("#search-input").attr("value"),indexes:$('#search-input').attr("data-repos")}
        (res) -> $("#search-listing").html(res)
        "html"
      )
    $("#close-search").bind "click", (event) =>
      $("#search-results").css "display", "none"
