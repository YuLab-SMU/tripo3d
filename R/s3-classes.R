#' An asynchronous Tripo 3D generation task
#'
#' @description
#' A `cast3d_task` represents a 3D generation job submitted to the Tripo API.
#' It tracks the task ID, status, and—once complete—the URL of the generated
#' model.
#'
#' @param task_id Character. The unique task identifier assigned by Tripo.
#' @param status Character. One of `"pending"`, `"processing"`,
#'   `"succeeded"`, or `"failed"`.
#' @param created_at POSIXct. When the task was created.
#' @param model_url Character. URL to download the GLB model (only when
#'   status is `"succeeded"`).
#' @param error_message Character. Error details if status is `"failed"`.
#' @param raw list. The raw API response for debugging.
#'
#' @export
#' @name cast3d_task
new_cast3d_task <- function(task_id = character(),
                           status = "pending",
                           created_at = Sys.time(),
                           model_url = character(),
                           error_message = character(),
                           raw = list()) {
  structure(
    list(
      task_id = task_id,
      status = status,
      created_at = created_at,
      model_url = model_url,
      error_message = error_message,
      raw = raw
    ),
    class = "cast3d_task"
  )
}

#' @export
print.cast3d_task <- function(x, ...) {
  cli::cli_h1("Tripo 3D Task")
  created_display <- if (inherits(x$created_at, "POSIXt")) {
    format(x$created_at, "%Y-%m-%d %H:%M:%S")
  } else {
    as.character(x$created_at)
  }
  cli::cli_bullets(c(
    "*" = "Task ID: {.field {x$task_id}}",
    "*" = "Status:  {.val {x$status}}",
    "*" = "Created: {.val {created_display}}"
  ))
  if (!is.null(x$error_message) && nzchar(x$error_message)) {
    cli::cli_bullets(c(
      "x" = "Error: {.val {x$error_message}}"
    ))
  }
  if (!is.null(x$model_url) && nzchar(x$model_url)) {
    cli::cli_bullets(c(
      "*" = "Model: {.url {x$model_url}}"
    ))
  }
  invisible(x)
}

#' A downloaded Tripo 3D model
#'
#' @description
#' A `cast3d_model` represents a 3D model that has been downloaded from
#' the Tripo API and stored locally.
#'
#' @param local_path Character. Path to the local `.glb` file.
#' @param task_id Character. The originating task ID.
#' @param metadata list. Model metadata (vertices, faces, format, etc.).
#'
#' @export
#' @name cast3d_model
new_cast3d_model <- function(local_path = character(),
                            task_id = character(),
                            metadata = list()) {
  structure(
    list(
      local_path = local_path,
      task_id = task_id,
      metadata = metadata
    ),
    class = "cast3d_model"
  )
}

#' @export
print.cast3d_model <- function(x, ...) {
  cli::cli_h1("Tripo 3D Model")
  cli::cli_bullets(c(
    "*" = "Path:   {.file {x$local_path}}",
    "*" = "Task:   {.field {x$task_id}}",
    "*" = "Format: {.val {x$metadata$format %||% 'GLB'}}"
  ))
  if (!is.null(x$metadata$vertices)) {
    cli::cli_bullets(c(
      "*" = "Vertices: {.val {x$metadata$vertices}}",
      "*" = "Faces:    {.val {x$metadata$faces}}"
    ))
  }
  if (!is.null(x$metadata$size_bytes)) {
    size_mb <- round(x$metadata$size_bytes / 1e6, 2)
    cli::cli_bullets(c(
      "*" = "Size: {.val {size_mb}} MB"
    ))
  }
  invisible(x)
}
