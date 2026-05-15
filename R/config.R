#' Configure Tripo API settings
#'
#' Set the Tripo API key, base URL, and other global options for the session.
#'
#' @param api_key Tripo API key. If `"env"` (default), reads from the
#'   `TRIPO_API_KEY` environment variable.
#' @param base_url API base URL. Defaults to `"https://api.tripo3d.ai"`.
#' @param timeout Request timeout in seconds. Default 300.
#' @param max_retries Maximum number of retries for failed requests. Default 3.
#' @param proxy HTTP proxy URL (e.g. `"http://127.0.0.1:7897"`). Default `NULL`.
#'   Also reads the `TRIPO_PROXY` environment variable.
#' @param output_dir Directory for downloaded model files. Default uses
#'   `tools::R_user_dir("tripo3d", "data")`.
#'
#' @return Invisibly returns a list of current settings.
#' @export
#'
#' @examples
#' \dontrun{
#' tripo_setup(api_key = "your-api-key")
#' }
tripo_setup <- function(api_key = "env",
                        base_url = "https://api.tripo3d.ai",
                        timeout = 300,
                        max_retries = 3,
                        proxy = NULL,
                        output_dir = NULL) {
  if (identical(api_key, "env")) {
    api_key <- Sys.getenv("TRIPO_API_KEY", unset = NA_character_)
    if (is.na(api_key)) {
      cli::cli_abort(
        c("No API key found.",
          i = "Set it with {.code tripo_setup(api_key = \"your-key\")}",
          i = "Or set the {.envvar TRIPO_API_KEY} environment variable.")
      )
    }
  }

  if (api_key == "your-api-key" || nchar(api_key) < 10) {
    cli::cli_warn("API key looks like a placeholder. Replace it with a real key.")
  }

  options(
    tripo3d.api_key = api_key,
    tripo3d.base_url = base_url,
    tripo3d.timeout = timeout,
    tripo3d.max_retries = max_retries,
    tripo3d.proxy = proxy,
    tripo3d.output_dir = output_dir
  )

  invisible(get_tripo_options())
}

get_tripo_option <- function(name, default = NULL) {
  getOption(paste0("tripo3d.", name), default)
}

get_tripo_options <- function() {
  list(
    api_key = get_tripo_option("api_key"),
    base_url = get_tripo_option("base_url"),
    timeout = get_tripo_option("timeout"),
    max_retries = get_tripo_option("max_retries"),
    proxy = get_tripo_option("proxy"),
    output_dir = get_tripo_option("output_dir")
  )
}

get_output_dir <- function() {
  dir <- get_tripo_option("output_dir")
  if (is.null(dir)) {
    dir <- file.path(tools::R_user_dir("tripo3d", "data"))
  }
  if (!dir.exists(dir)) {
    fs::dir_create(dir, recurse = TRUE)
  }
  dir
}
