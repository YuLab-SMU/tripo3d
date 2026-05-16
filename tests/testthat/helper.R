skip_if_no_api_key <- function() {
  if (is.na(getOption("cast3d.api_key"))) {
    testthat::skip("No Tripo API key configured")
  }
}

skip_if_no_network <- function() {
  skip_if_no_api_key()
  con <- tryCatch(
    httr2::request("https://api.tripo3d.ai") |>
      httr2::req_timeout(5) |>
      httr2::req_perform(),
    error = function(e) NULL
  )
  if (is.null(con)) {
    testthat::skip("No network connectivity to Tripo API")
  }
}
