`%||%` <- function(x, y) if (is.null(x)) y else x

tripo_api_error <- function(message, status = NULL, body = NULL, call = NULL) {
  structure(
    list(message = message, status = status, body = body, call = call),
    class = c("tripo_api_error", "error", "condition")
  )
}

tripo_timeout_error <- function(url, timeout, call = NULL) {
  msg <- sprintf("Request to %s timed out after %ss", url, timeout)
  structure(
    list(message = msg, url = url, timeout = timeout, call = call),
    class = c("tripo_timeout_error", "error", "condition")
  )
}

tripo_parse_error <- function(message, body = NULL, call = NULL) {
  structure(
    list(message = message, body = body, call = call),
    class = c("tripo_parse_error", "error", "condition")
  )
}

check_api_key <- function() {
  key <- get_tripo_option("api_key")
  if (is.na(key)) {
    cli::cli_abort(
      c("No API key configured.",
        i = "Call {.fun tripo_setup} first or set {.envvar TRIPO_API_KEY}."),
      class = "tripo_no_auth_error"
    )
  }
  key
}

build_url <- function(endpoint) {
  base <- get_tripo_option("base_url")
  if (endsWith(base, "/") && startsWith(endpoint, "/")) {
    endpoint <- substring(endpoint, 2)
  }
  paste0(base, endpoint)
}

is_tripo_error <- function(resp) {
  if (!inherits(resp, "httr2_response")) return(FALSE)
  status <- httr2::resp_status(resp)
  status >= 400
}

read_image_to_base64 <- function(image) {
  if (is.raw(image)) {
    return(jsonlite::base64_enc(image))
  }
  if (!is.character(image) || length(image) != 1 || !nzchar(image)) {
    cli::cli_abort(
      "image must be a single file path, URL, or raw vector",
      class = "tripo_invalid_input_error"
    )
  }
  if (grepl("^https?://", image)) {
    tmp <- tempfile(fileext = paste0(".", tools::file_ext(image)))
    on.exit(unlink(tmp))
    httr2::request(image) |>
      httr2::req_perform() |>
      httr2::resp_body_raw() -> raw
    return(jsonlite::base64_enc(raw))
  }
  if (file.exists(image)) {
    raw <- readBin(image, "raw", file.info(image)$size)
    return(jsonlite::base64_enc(raw))
  }
  cli::cli_abort(
    "image must be a file path, URL, or raw vector",
    class = "tripo_invalid_input_error"
  )
}

tripo_upload_image <- function(image) {
  ext <- "jpg"
  if (is.character(image) && length(image) == 1 && nzchar(image)) {
    if (grepl("^https?://", image)) {
      return(list(type = "jpg", url = image))
    }
    if (!file.exists(image)) {
      cli::cli_abort(
        "image file not found: {.file {image}}",
        class = "tripo_invalid_input_error"
      )
    }
    path <- image
    file_ext <- tolower(tools::file_ext(image))
    if (file_ext %in% c("png", "jpg", "jpeg", "webp")) {
      ext <- if (file_ext == "jpeg") "jpg" else file_ext
    }
  } else if (is.raw(image)) {
    path <- tempfile(fileext = ".jpg")
    writeBin(image, path)
    on.exit(unlink(path), add = TRUE)
  } else {
    cli::cli_abort(
      "image must be a file path, URL, or raw vector",
      class = "tripo_invalid_input_error"
    )
  }

  api_key <- check_api_key()
  url <- build_url("/v2/openapi/upload")

  raw_file <- readBin(path, "raw", file.info(path)$size)
  filename <- basename(path)
  boundary <- paste0("----", paste(sample(c(letters, 0:9), 24, TRUE), collapse = ""))

  body_parts <- c(
    charToRaw(paste0("--", boundary, "\r\n")),
    charToRaw(paste0(
      "Content-Disposition: form-data; name=\"file\"; filename=\"", filename, "\"\r\n"
    )),
    charToRaw(paste0("Content-Type: image/", ext, "\r\n\r\n")),
    raw_file,
    charToRaw(paste0("\r\n--", boundary, "--\r\n"))
  )
  body_raw <- Reduce(c, body_parts)

  req <- httr2::request(url) |>
    httr2::req_user_agent("tripo3d (R package)") |>
    httr2::req_headers(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = paste0("multipart/form-data; boundary=", boundary)
    ) |>
    httr2::req_body_raw(body_raw) |>
    httr2::req_timeout(get_tripo_option("timeout", 300))

  proxy <- get_tripo_option("proxy")
  if (!is.na(proxy) && nzchar(proxy)) {
    req$options$proxy <- proxy
  }

  resp <- httr2::req_perform(req)
  parsed <- httr2::resp_body_json(resp)

  if (!identical(parsed$code, 0L)) {
    cli::cli_abort(
      "File upload failed: {.val {parsed$message %||% 'unknown error'}}",
      class = "tripo_api_error",
      body = parsed
    )
  }

  token <- parsed$data$image_token
  if (is.null(token)) {
    cli::cli_abort(
      "Upload succeeded but no image token returned",
      class = "tripo_parse_error"
    )
  }

  list(type = ext, file_token = token)
}
