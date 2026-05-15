#' Low-level Tripo API request
#'
#' Send an HTTP request to the Tripo API with automatic retry and error handling.
#'
#' @param endpoint API endpoint path, e.g. `"/v2/openapi/task"`.
#' @param method HTTP method. One of `"GET"`, `"POST"`.
#' @param body Request body as a list (will be JSON-encoded).
#' @param query Query parameters as a list.
#' @param timeout Request timeout in seconds. Defaults to the global option.
#' @param max_retries Maximum retries on failure. Defaults to the global option.
#'
#' @return A parsed list from the JSON response.
#' @keywords internal
tripo_request <- function(endpoint,
                          method = c("POST", "GET"),
                          body = NULL,
                          query = NULL,
                          timeout = NULL,
                          max_retries = NULL) {
  method <- match.arg(method)
  api_key <- check_api_key()
  url <- build_url(endpoint)

  timeout <- timeout %||% get_tripo_option("timeout", 300)
  max_retries <- max_retries %||% get_tripo_option("max_retries", 3)

  req <- httr2::request(url) |>
    httr2::req_user_agent("tripo3d (R package)") |>
    httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
    httr2::req_retry(
      max_tries = max_retries,
      backoff = ~ 2^.x,
      is_transient = function(resp) {
        status <- httr2::resp_status(resp)
        status %in% c(429, 502, 503) || status >= 500
      }
    ) |>
    httr2::req_timeout(timeout)

  if (method == "POST" && !is.null(body)) {
    req <- httr2::req_body_json(req, body, auto_unbox = TRUE)
  }
  if (!is.null(query)) {
    req <- httr2::req_url_query(req, !!!query)
  }

  apply_proxy()

  resp <- tryCatch(
    httr2::req_perform(req),
    httr2_failure = function(e) {
      cli::cli_abort(
        "Tripo API request failed: {e$message}",
        class = "tripo_network_error",
        parent = e
      )
    },
    httr2_timeout = function(e) {
      cli::cli_abort(
        "Tripo API request timed out after {timeout}s",
        class = "tripo_timeout_error",
        parent = e
      )
    }
  )

  parsed <- tryCatch(
    httr2::resp_body_json(resp),
    error = function(e) {
      cli::cli_abort(
        "Failed to parse Tripo API response",
        class = "tripo_parse_error",
        parent = e
      )
    }
  )

  if (is_tripo_error(resp)) {
    err_msg <- parsed$message %||% parsed$error %||%
      sprintf("HTTP %d", httr2::resp_status(resp))
    cli::cli_abort(
      err_msg,
      class = "tripo_api_error",
      status = httr2::resp_status(resp),
      body = parsed
    )
  }

  parsed
}
