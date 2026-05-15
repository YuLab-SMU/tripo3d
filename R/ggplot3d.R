#' Convert a ggplot2 plot to a 3D model via Tripo
#'
#' Renders a ggplot object as a high-resolution PNG, then submits it
#' to Tripo's `image_to_model` pipeline. The resulting 3D model can be
#' interactively viewed with `view_3d()`.
#'
#' Direct `image_to_model` works well for photographs and objects but
#' may produce poor results for data visualizations. Set `via_llm = TRUE`
#' to route through a vision LLM that translates the plot into a
#' data-sculpture description optimized for text-to-3D generation.
#'
#' @param p A ggplot object.
#' @param width Image width in pixels. Default 1200.
#' @param height Image height in pixels. Default 800.
#' @param dpi Resolution in dots per inch. Default 150.
#' @param wait If `TRUE` (default), poll until completion and return a
#'   `tripo_model`. If `FALSE`, return a `tripo_task`.
#' @param via_llm If `TRUE`, route through `generate_3d_via_llm()` with
#'   `mode = "data_viz"` instead of direct `image_to_model`. Requires
#'   aisdk. Default `TRUE` (data visualizations benefit from LLM routing).
#' @param model Optional LLM model passed to `describe_image_for_3d()`
#'   when `via_llm = TRUE`.
#' @param ... Additional arguments passed to `generate_3d()` (direct mode)
#'   or `generate_3d_via_llm()` (LLM mode).
#'
#' @return A `tripo_model` if `wait = TRUE`, otherwise a `tripo_task`.
#' @export
#'
#' @examples
#' \dontrun{
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(wt, mpg, size = hp, color = cyl)) +
#'   geom_point() +
#'   theme_minimal()
#'
#' model <- ggplot_to_3d(p)
#' view_3d(model)
#'
#' model_llm <- ggplot_to_3d(p, via_llm = TRUE)
#' view_3d(model_llm)
#' }
ggplot_to_3d <- function(p,
                         width = 1200,
                         height = 800,
                         dpi = 150,
                         wait = TRUE,
                         via_llm = TRUE,
                         model = NULL,
                         ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(
      "ggplot2 is required for ggplot_to_3d().",
      i = "Install with {.code install.packages(\"ggplot2\")}."
    )
  }

  if (!inherits(p, "gg")) {
    cli::cli_abort("p must be a ggplot object")
  }

  tmp <- tempfile(fileext = ".png")
  on.exit(unlink(tmp), add = TRUE)

  ggplot2::ggsave(
    filename = tmp,
    plot = p,
    width = width / dpi,
    height = height / dpi,
    dpi = dpi,
    bg = "white"
  )

  cli::cli_alert_info("Rendered ggplot to {width}x{height} PNG")

  if (via_llm) {
    generate_3d_via_llm(
      tmp, model = model,
      mode = "data_viz", wait = wait, ...
    )
  } else {
    generate_3d(tmp, wait = wait, ...)
  }
}

#' Convert a plot expression to a 3D model via Tripo
#'
#' Evaluates a plot expression, captures its output as a PNG, and
#' generates a 3D model. Works with both base R graphics and grid-based
#' plots.
#'
#' Direct `image_to_model` works well for photographs and objects but
#' may produce poor results for data visualizations. Set `via_llm = TRUE`
#' to route through a vision LLM.
#'
#' @param expr An expression that produces a plot (e.g. `plot(cars)`).
#' @param width Image width in pixels. Default 1200.
#' @param height Image height in pixels. Default 800.
#' @param dpi Resolution in dots per inch. Default 150.
#' @param wait If `TRUE` (default), poll until completion.
#' @param via_llm If `TRUE`, route through `generate_3d_via_llm()` with
#'   `mode = "data_viz"` instead of direct `image_to_model`. Default `TRUE`.
#' @param model Optional LLM model when `via_llm = TRUE`.
#' @param ... Additional arguments passed to `generate_3d()` (direct mode)
#'   or `generate_3d_via_llm()` (LLM mode).
#'
#' @return A `tripo_model` if `wait = TRUE`, otherwise a `tripo_task`.
#' @export
#'
#' @examples
#' \dontrun{
#' model <- plot_to_3d({
#'   plot(mtcars$wt, mtcars$mpg,
#'        pch = 19, col = "steelblue",
#'        xlab = "Weight", ylab = "MPG")
#' })
#' view_3d(model)
#' }
plot_to_3d <- function(expr,
                       width = 1200,
                       height = 800,
                       dpi = 150,
                       wait = TRUE,
                       via_llm = TRUE,
                       model = NULL,
                       ...) {
  tmp <- tempfile(fileext = ".png")
  png(tmp, width = width, height = height, res = dpi, bg = "white")
  tryCatch(
    force(expr),
    finally = grDevices::dev.off()
  )
  on.exit(unlink(tmp), add = TRUE)

  cli::cli_alert_info("Captured plot as {width}x{height} PNG")

  if (via_llm) {
    generate_3d_via_llm(
      tmp, model = model,
      mode = "data_viz", wait = wait, ...
    )
  } else {
    generate_3d(tmp, wait = wait, ...)
  }
}
