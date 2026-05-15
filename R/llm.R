#' Describe an image for 3D generation via LLM
#'
#' Uses a vision-capable LLM (via aisdk) to analyze an image and produce
#' a structured description optimized as input for Tripo's `text_to_model`
#' endpoint. This can produce better 3D results than direct `image_to_model`
#' when the image contains complex or subtle details.
#'
#' @param image Path to a local image file or a URL.
#' @param model A language model object from aisdk (e.g.
#'   `aisdk::create_openai()$language_model("gpt-4o")`), or a
#'   `"provider:model"` string like `"openai:gpt-4o"`. Defaults to the
#'   aisdk package-wide default model (see `aisdk::set_model()`),
#'   falling back to `"openai:gpt-4o"`.
#' @param style Optional Tripo style hint (e.g. `"person:person2cartoon"`,
#'   `"object:clay"`, `"gold"`).
#' @param mode Description mode. `"auto"` (default) auto-detects from image
#'   content; `"object"` for photographs or natural objects; `"data_viz"`
#'   for statistical charts, plots, heatmaps, and other data visualizations —
#'   this produces data-sculpture-style descriptions optimized for text-to-3D.
#' @param ... Additional arguments passed to `aisdk::analyze_image()`.
#'
#' @return A character string with a 3D-optimized description.
#' @export
#'
#' @examples
#' \dontrun{
#' library(aisdk)
#' desc <- describe_image_for_3d("photo.jpg")
#' cat(desc)
#'
#' desc_viz <- describe_image_for_3d("umap_plot.png", mode = "data_viz")
#' cat(desc_viz)
#' }
describe_image_for_3d <- function(image, model = NULL, style = NULL,
                                   mode = c("auto", "object", "data_viz"), ...) {
  if (!requireNamespace("aisdk", quietly = TRUE)) {
    cli::cli_abort(
      "aisdk is required for LLM image description.",
      i = "Install with {.code remotes::install_github(\"yulab-github/aisdk\")}."
    )
  }

  if (is.null(model)) {
    model <- getOption("tripo3d.llm_model")
    if (is.null(model)) {
      model <- aisdk::get_model()
    }
  }

  mode <- match.arg(mode)
  prompts <- build_3d_description_prompts(mode, style)

  cli::cli_alert_info("Analyzing image with LLM (mode: {.val {mode}})...")

  result <- aisdk::analyze_image(
    model = model,
    image = image,
    prompt = prompts$user,
    system = prompts$system,
    ...
  )

  desc <- result$text %||% result$content
  if (is.null(desc) || !nzchar(desc)) {
    cli::cli_abort("LLM returned an empty description")
  }

  if (nchar(desc) > 1024) {
    desc <- substr(desc, 1, 1021)
    desc <- paste0(desc, "...")
  }

  cli::cli_alert_success("Description generated ({nchar(desc)} chars)")
  desc
}

build_3d_description_prompts <- function(mode, style = NULL) {
  style_hint <- if (!is.null(style)) {
    paste0("Apply the style '", style, "' to the final description. ")
  } else {
    ""
  }

  if (mode == "data_viz") {
    data_viz_system <- paste0(
      "You are a data sculptor who translates statistical graphics into ",
      "physical 3D data sculptures. Analyze this data visualization and ",
      "produce a concise, geometric description optimized for the Tripo ",
      "text-to-3D API. ",
      "Map visual elements to physical geometry: ",
      "scatter points become raised cylindrical pins whose heights reflect ",
      "local density; lines become raised tubular ridges; bars become ",
      "rectangular extrusions; clusters become colored convex hull blocks; ",
      "heatmaps become stepped terrain grids; axes become border frame ",
      "markings; legends become inset label plaques. ",
      "The background becomes a flat rectangular base plate 0.5mm thick. ",
      "Keep the description under 800 characters. ",
      "Avoid subjective language. ",
      "Write as if giving precise CNC fabrication instructions ",
      "for a wall-mounted data relief panel. ",
      style_hint
    )

    data_viz_user <- paste0(
      "Describe this data visualization as a 3D data sculpture specification:\n\n",
      "- Identify chart type (scatter, bar, heatmap, line, etc.)\n",
      "- Dimensions of the base plate\n",
      "- Number, height, color, and spatial arrangement of raised elements\n",
      "- How each data variable maps to a physical dimension (X, Y, Z, color)\n",
      "- Legend and annotation elements as inset plaques\n",
      "- Overall material: matte white plastic with color-coded regions\n",
      "- Suggested style: ",
      style %||% "clean data sculpture"
    )

    return(list(system = data_viz_system, user = data_viz_user))
  }

  object_system <- paste0(
    "You are an expert at describing objects for 3D model generation. ",
    "Analyze the image and produce a concise, factual description optimized ",
    "for the Tripo text-to-3D API. ",
    "Focus on: physical shape, proportions, structural geometry, ",
    "surface materials (matte/glossy/metallic/transparent), ",
    "key distinguishing features, and spatial relationships between parts. ",
    "Keep the description under 800 characters. ",
    "Avoid subjective language, emotional descriptions, or background context. ",
    "Write as if describing a physical 3D object for a sculptor to recreate. ",
    style_hint
  )

  object_user <- paste0(
    "Describe this image as a 3D object specification:\n\n",
    "- Overall shape and silhouette\n",
    "- Key structural features and proportions\n",
    "- Surface materials and texture hints\n",
    "- Any fine details that must be preserved\n",
    "- Suggested style: ",
    style %||% "realistic"
  )

  list(system = object_system, user = object_user)
}

#' Generate a 3D model from an image via LLM description
#'
#' Full pipeline: describe the image with a vision LLM (aisdk), then
#' generate a 3D model from the text description via Tripo's
#' `text_to_model` endpoint.
#'
#' @param image Path to a local image file or a URL.
#' @param model A language model object from aisdk, or `"provider:model"` string.
#' @param negative_prompt What to avoid in generation. Default `NULL`.
#' @param model_version Tripo model version.
#' @param texture Generate texture. Default `TRUE`.
#' @param face_limit Maximum faces. Default 50000.
#' @param wait Wait for completion. If `FALSE`, returns a `tripo_task`.
#' @param style Optional Tripo style hint for the LLM description.
#' @param mode Description mode passed to `describe_image_for_3d()`.
#' @param ... Additional arguments passed to `describe_image_for_3d()`.
#'
#' @return A `tripo_model` if `wait = TRUE`, otherwise a `tripo_task`.
#' @export
#'
#' @examples
#' \dontrun{
#' library(aisdk)
#' result <- generate_3d_via_llm("cat.jpg")
#' view_3d(result)
#'
#' result_viz <- generate_3d_via_llm("umap.png", mode = "data_viz")
#' view_3d(result_viz)
#' }
generate_3d_via_llm <- function(image,
                                 model = NULL,
                                 negative_prompt = NULL,
                                 model_version = c("v2.5-20250123", "v2.0-20240919",
                                                  "v3.0-20250812", "v3.1-20260211",
                                                  "v1.4-20240625", "P1-20260311",
                                                  "Turbo-v1.0-20250506"),
                                 texture = TRUE,
                                 face_limit = 50000,
                                 wait = TRUE,
                                 style = NULL,
                                 mode = c("auto", "object", "data_viz"),
                                 ...) {
  model_version <- match.arg(model_version)
  mode <- match.arg(mode)

  desc <- describe_image_for_3d(
    image = image,
    model = model,
    style = style,
    mode = mode,
    ...
  )

  cli::cli_alert_info("Generating 3D model from description...")

  task <- create_3d_from_text(
    prompt = desc,
    negative_prompt = negative_prompt,
    model_version = model_version,
    texture = texture,
    face_limit = face_limit
  )

  if (!wait) return(task)

  task <- poll_task(task)
  download_model(task)
}
