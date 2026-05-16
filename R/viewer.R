#' Interactive 3D model viewer
#'
#' Display a Tripo-generated `.glb` model interactively using Three.js.
#' Works in RStudio Viewer, RMarkdown, Shiny apps, and any HTML-capable
#' output.
#'
#' @param model A `cast3d_model` object or path to a `.glb` file.
#' @param background Background color in CSS hex format. Default `"#f0f0f0"`.
#' @param show_grid If `TRUE`, add a reference ground grid to the scene.
#'   Default `FALSE`.
#' @param width Widget width. Default `NULL` (auto).
#' @param height Widget height. Default `NULL` (auto).
#' @param element_id Optional HTML element ID for the widget container.
#' @param ... Additional arguments passed to `htmlwidgets::createWidget()`.
#'
#' @return An `htmlwidget` object (invisibly).
#' @export
#'
#' @examples
#' \dontrun{
#' model <- generate_3d("photo.jpg")
#' view_3d(model)
#'
#' view_3d("path/to/model.glb")
#' }
view_3d <- function(model,
                    background = "#f0f0f0",
                    show_grid = FALSE,
                    width = NULL,
                    height = NULL,
                    element_id = NULL,
                    ...) {
  if (inherits(model, "cast3d_model")) {
    glb_path <- model$local_path
  } else if (is.character(model) && length(model) == 1 && file.exists(model)) {
    glb_path <- model
  } else {
    cli::cli_abort(
      "model must be a cast3d_model or a .glb file path"
    )
  }

  if (!file.exists(glb_path)) {
    cli::cli_abort("Model file not found: {.file {glb_path}}")
  }

  raw <- readBin(glb_path, "raw", file.info(glb_path)$size)
  b64 <- jsonlite::base64_enc(raw)

  x <- list(
    glb_base64 = b64,
    background = background,
    show_grid = show_grid
  )

  htmlwidgets::createWidget(
    name = "glb_viewer",
    x = x,
    width = width,
    height = height,
    package = "cast3d",
    elementId = element_id,
    ...
  )
}

#' Shiny bindings for glb_viewer
#'
#' Output and render functions for using glb_viewer within Shiny
#' applications.
#'
#' @param output_id Output variable to read the value from.
#' @param width Widget width.
#' @param height Widget height.
#' @param expr An expression that generates a glb_viewer widget.
#' @param env The environment in which to evaluate `expr`.
#' @param quoted Is `expr` a quoted expression?
#'
#' @name glb_viewer-shiny
#'
#' @export
glb_viewer_output <- function(output_id, width = "100%", height = "500px") {
  htmlwidgets::shinyWidgetOutput(output_id, "glb_viewer", width, height,
                                 package = "cast3d")
}

#' @rdname glb_viewer-shiny
#' @export
render_glb_viewer <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) expr <- substitute(expr)
  htmlwidgets::shinyRenderWidget(expr, glb_viewer_output, env, quoted = TRUE)
}
