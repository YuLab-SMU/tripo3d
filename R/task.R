#' Create a 3D model from an image via Tripo API
#'
#' Submit an image to Tripo's image-to-3D pipeline and return a task object
#' for tracking.
#'
#' @param image Path to a local image file, a URL, or a raw vector.
#' @param model_version Tripo model version. One of `"v2.5-20250123"`,
#'   `"v2.0-20240919"`, `"v3.0-20250812"`, `"v3.1-20260211"`,
#'   `"v1.4-20240625"`, `"P1-20260311"`, `"Turbo-v1.0-20250506"`.
#'   Default `"v2.5-20250123"`.
#' @param texture Generate a textured model. Default `TRUE`.
#' @param pbr Generate PBR materials. Default `FALSE`.
#' @param face_limit Maximum face count. Default 50000.
#' @param model_seed Random seed for reproducibility. Default `NULL`.
#'
#' @return A `tripo_task` object.
#' @export
#'
#' @examples
#' \dontrun{
#' task <- create_3d_from_image("photo.jpg")
#' }
create_3d_from_image <- function(image,
                                  model_version = c("v2.5-20250123", "v2.0-20240919",
                                                   "v3.0-20250812", "v3.1-20260211",
                                                   "v1.4-20240625", "P1-20260311",
                                                   "Turbo-v1.0-20250506"),
                                  texture = TRUE,
                                  pbr = FALSE,
                                  face_limit = 50000,
                                  model_seed = NULL) {
  model_version <- match.arg(model_version)

  cli::cli_alert_info("Uploading image to Tripo...")
  file <- tripo_upload_image(image)

  body <- list(
    type = "image_to_model",
    file = file,
    model_version = model_version,
    texture = texture,
    pbr = pbr,
    face_limit = face_limit
  )
  if (!is.null(model_seed)) {
    body$model_seed <- model_seed
  }

  cli::cli_alert_info("Submitting image to Tripo...")

  resp <- tripo_request(
    endpoint = "/v2/openapi/task",
    method = "POST",
    body = body
  )

  if (!identical(resp$code, 0L)) {
    cli::cli_abort(
      "Tripo task creation failed: {.val {resp$message %||% 'unknown error'}}",
      class = "tripo_api_error",
      body = resp
    )
  }

  task <- new_tripo_task(
    task_id = resp$data$task_id,
    status = "pending",
    raw = resp
  )

  cli::cli_alert_success("Task created: {.field {task$task_id}}")
  task
}

#' Poll a Tripo task until completion
#'
#' @param task A `tripo_task` object.
#' @param interval Polling interval in seconds. Default 2.
#' @param max_wait Maximum total wait time in seconds. Default 300.
#'
#' @return An updated `tripo_task` with final status.
#' @export
poll_task <- function(task, interval = 2, max_wait = 300) {
  if (!inherits(task, "tripo_task")) {
    cli::cli_abort("task must be a tripo_task object")
  }

  if (task$status == "succeeded") return(task)
  if (task$status == "failed") {
    cli::cli_abort("Task {.field {task$task_id}} already failed")
  }

  start <- Sys.time()

  cli::cli_progress_bar(
    name = "Tripo task {.field {task$task_id}}",
    type = "tasks",
    total = max_wait,
    clear = FALSE
  )

  repeat {
    elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

    if (elapsed >= max_wait) {
      cli::cli_progress_done()
      cli::cli_abort(
        "Task {.field {task$task_id}} timed out after {max_wait}s",
        class = "tripo_timeout_error"
      )
    }

    resp <- tripo_request(
      endpoint = sprintf("/v2/openapi/task/%s", task$task_id),
      method = "GET"
    )

    status <- resp$data$status
    progress <- resp$data$progress %||% 0L

    cli::cli_progress_update(
      set = progress / 100 * max_wait,
      status = status
    )

    if (status == "success") {
      cli::cli_progress_done()
      task$status <- "succeeded"
      task$model_url <- resp$data$output$model
      task$raw <- resp
      cli::cli_alert_success("Task {.field {task$task_id}} complete")
      return(task)
    }

    if (status == "failed") {
      cli::cli_progress_done()
      task$status <- "failed"
      task$error_message <- resp$data$error_message %||% "unknown error"
      task$raw <- resp
      cli::cli_abort(
        "Task {.field {task$task_id}} failed: {.val {task$error_message}}"
      )
    }

    Sys.sleep(interval)
  }
}

#' Generate a 3D model from an image in one step
#'
#' Convenience wrapper that calls `create_3d_from_image()`,
#' `poll_task()`, and `download_model()` in sequence.
#'
#' @param image Image file path, URL, or raw vector.
#' @param model_version Tripo model version.
#' @param texture Generate texture. Default `TRUE`.
#' @param face_limit Maximum faces. Default 50000.
#' @param wait Wait for completion. If `FALSE`, returns the task immediately.
#' @param ... Additional arguments passed to `poll_task()`.
#'
#' @return A `tripo_model` if `wait = TRUE`, otherwise a `tripo_task`.
#' @export
generate_3d <- function(image,
                        model_version = c("v2.5-20250123", "v2.0-20240919",
                                         "v3.0-20250812", "v3.1-20260211",
                                         "v1.4-20240625", "P1-20260311",
                                         "Turbo-v1.0-20250506"),
                        texture = TRUE,
                        face_limit = 50000,
                        wait = TRUE,
                        ...) {
  model_version <- match.arg(model_version)

  task <- create_3d_from_image(
    image = image,
    model_version = model_version,
    texture = texture,
    face_limit = face_limit
  )

  if (!wait) return(task)

  task <- poll_task(task, ...)
  download_model(task)
}

#' Create a 3D model from a text prompt via Tripo API
#'
#' Submit a text description to Tripo's text-to-3D pipeline and return
#' a task object for tracking. This is the programmatic counterpart to
#' `create_3d_from_image()` for text-based generation.
#'
#' @param prompt Text description of the desired 3D model. Max 1024 characters.
#' @param negative_prompt Text description of what to avoid. Default `NULL`.
#' @param model_version Tripo model version.
#' @param texture Generate a textured model. Default `TRUE`.
#' @param pbr Generate PBR materials. Default `FALSE`.
#' @param face_limit Maximum face count. Default 50000.
#' @param model_seed Random seed for reproducibility. Default `NULL`.
#'
#' @return A `tripo_task` object.
#' @export
#'
#' @examples
#' \dontrun{
#' task <- create_3d_from_text("a cute cartoon cat with big eyes")
#' }
create_3d_from_text <- function(prompt,
                                 negative_prompt = NULL,
                                 model_version = c("v2.5-20250123", "v2.0-20240919",
                                                  "v3.0-20250812", "v3.1-20260211",
                                                  "v1.4-20240625", "P1-20260311",
                                                  "Turbo-v1.0-20250506"),
                                 texture = TRUE,
                                 pbr = FALSE,
                                 face_limit = 50000,
                                 model_seed = NULL) {
  model_version <- match.arg(model_version)

  body <- list(
    type = "text_to_model",
    prompt = prompt,
    model_version = model_version,
    texture = texture,
    pbr = pbr,
    face_limit = face_limit
  )
  if (!is.null(negative_prompt)) {
    body$negative_prompt <- negative_prompt
  }
  if (!is.null(model_seed)) {
    body$model_seed <- model_seed
  }

  cli::cli_alert_info("Submitting text prompt to Tripo...")

  resp <- tripo_request(
    endpoint = "/v2/openapi/task",
    method = "POST",
    body = body
  )

  if (!identical(resp$code, 0L)) {
    cli::cli_abort(
      "Tripo task creation failed: {.val {resp$message %||% 'unknown error'}}",
      class = "tripo_api_error",
      body = resp
    )
  }

  task <- new_tripo_task(
    task_id = resp$data$task_id,
    status = "pending",
    raw = resp
  )

  cli::cli_alert_success("Task created: {.field {task$task_id}}")
  task
}

#' Generate a 3D model from a text prompt in one step
#'
#' Convenience wrapper that calls `create_3d_from_text()`,
#' `poll_task()`, and `download_model()` in sequence.
#'
#' @param prompt Text description of the desired 3D model.
#' @param negative_prompt What to avoid in generation.
#' @param model_version Tripo model version.
#' @param texture Generate texture. Default `TRUE`.
#' @param face_limit Maximum faces. Default 50000.
#' @param wait Wait for completion. If `FALSE`, returns the task immediately.
#' @param ... Additional arguments passed to `poll_task()`.
#'
#' @return A `tripo_model` if `wait = TRUE`, otherwise a `tripo_task`.
#' @export
generate_3d_from_text <- function(prompt,
                                   negative_prompt = NULL,
                                   model_version = c("v2.5-20250123", "v2.0-20240919",
                                                    "v3.0-20250812", "v3.1-20260211",
                                                    "v1.4-20240625", "P1-20260311",
                                                    "Turbo-v1.0-20250506"),
                                   texture = TRUE,
                                   face_limit = 50000,
                                   wait = TRUE,
                                   ...) {
  model_version <- match.arg(model_version)

  task <- create_3d_from_text(
    prompt = prompt,
    negative_prompt = negative_prompt,
    model_version = model_version,
    texture = texture,
    face_limit = face_limit
  )

  if (!wait) return(task)

  task <- poll_task(task, ...)
  download_model(task)
}
