#' Download a 3D model from a completed Tripo task
#'
#' @param task A `cast3d_task` with status `"succeeded"`.
#' @param output_dir Directory to save the `.glb` file. Default uses the
#'   package cache directory.
#' @param overwrite If `TRUE`, overwrite existing files. Default `FALSE`.
#' @param filename Output filename. Default auto-generated from task ID.
#'
#' @return A `cast3d_model` object.
#' @export
download_model <- function(task,
                          output_dir = NULL,
                          overwrite = FALSE,
                          filename = NULL) {
  if (!inherits(task, "cast3d_task")) {
    cli::cli_abort("task must be a cast3d_task object")
  }
  if (task$status != "succeeded") {
    cli::cli_abort(
      "task not complete (status: {.val {task$status}}).",
      i = "Call {.fun poll_task} first."
    )
  }
  if (is.null(task$model_url) || !nzchar(task$model_url)) {
    cli::cli_abort("No model URL in task output")
  }

  output_dir <- output_dir %||% get_output_dir()
  filename <- filename %||% paste0(task$task_id, ".glb")
  local_path <- file.path(output_dir, filename)

  if (file.exists(local_path) && !overwrite) {
    cli::cli_alert_info("Model already cached at {.file {local_path}}")
    return(read_cached_model(local_path, task$task_id))
  }

  cli::cli_alert_info("Downloading model...")
  resp <- httr2::request(task$model_url) |>
    httr2::req_timeout(get_cast3d_option("timeout", 300)) |>
    httr2::req_perform()

  writeBin(httr2::resp_body_raw(resp), local_path)

  size <- file.info(local_path)$size

  cli::cli_alert_success(
    "Model saved to {.file {local_path}} ({round(size / 1e6, 2)} MB)"
  )

  metadata <- list(format = "GLB", size_bytes = size)

  model <- new_cast3d_model(
    local_path = local_path,
    task_id = task$task_id,
    metadata = metadata
  )

  cache_path <- model_cache_path(task$task_id)
  saveRDS(model, cache_path)

  model
}

read_cached_model <- function(local_path, task_id) {
  cache_path <- model_cache_path(task_id)
  if (file.exists(cache_path)) {
    return(readRDS(cache_path))
  }
  model <- new_cast3d_model(
    local_path = local_path,
    task_id = task_id,
    metadata = list(format = "GLB", size_bytes = file.info(local_path)$size)
  )
  saveRDS(model, cache_path)
  model
}

model_cache_path <- function(task_id) {
  file.path(get_output_dir(), paste0(task_id, ".rds"))
}

#' Display model metadata
#'
#' @param model A `cast3d_model` object or path to a `.glb` file.
#'
#' @return A list with `format`, `size_bytes`, and optionally `vertices`,
#'   `faces` if `rgl2gltf` is installed.
#' @export
model_info <- function(model) {
  if (inherits(model, "cast3d_model")) {
    if (requireNamespace("rgl2gltf", quietly = TRUE)) {
      tryCatch({
        mesh <- rgl2gltf::readGLB(model$local_path)
        rgl_mesh <- rgl2gltf::as.mesh3d(mesh)
        model$metadata$vertices <- ncol(rgl_mesh$vb)
        model$metadata$faces <- ncol(rgl_mesh$ib) %||% ncol(rgl_mesh$it) %||% 0L
      }, error = function(e) {
        cli::cli_alert_info("Could not extract geometry: {e$message}")
      })
    }
    return(model$metadata)
  }

  if (is.character(model) && file.exists(model)) {
    info <- list(
      path = model,
      format = "GLB",
      size_bytes = file.info(model)$size
    )
    if (requireNamespace("rgl2gltf", quietly = TRUE)) {
      tryCatch({
        mesh <- rgl2gltf::readGLB(model)
        rgl_mesh <- rgl2gltf::as.mesh3d(mesh)
        info$vertices <- ncol(rgl_mesh$vb)
        info$faces <- ncol(rgl_mesh$ib) %||% ncol(rgl_mesh$it) %||% 0L
      }, error = function(e) NULL)
    }
    return(info)
  }

  cli::cli_abort("model must be a cast3d_model or a .glb file path")
}
