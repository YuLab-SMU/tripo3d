.onLoad <- function(libname, pkgname) {
  op <- options()
  op_tripo3d <- list(
    tripo3d.api_key = Sys.getenv("TRIPO_API_KEY", unset = NA_character_),
    tripo3d.base_url = "https://api.tripo3d.ai",
    tripo3d.timeout = 300,
    tripo3d.max_retries = 3,
    tripo3d.proxy = Sys.getenv("TRIPO_PROXY", unset = NA_character_),
    tripo3d.output_dir = NULL
  )
  toset <- !(names(op_tripo3d) %in% names(op))
  if (any(toset)) options(op_tripo3d[toset])
  invisible()
}

.onAttach <- function(libname, pkgname) {
  if (is.na(getOption("tripo3d.api_key"))) {
    packageStartupMessage(
      "tripo3d: Set your API key with tripo_setup(api_key = \"your-key\")\n",
      "  or set the TRIPO_API_KEY environment variable."
    )
  }
  invisible()
}
