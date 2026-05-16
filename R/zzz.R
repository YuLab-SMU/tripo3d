.onLoad <- function(libname, pkgname) {
  op <- options()
  op_cast3d <- list(
    cast3d.api_key = Sys.getenv("TRIPO_API_KEY", unset = NA_character_),
    cast3d.base_url = "https://api.tripo3d.ai",
    cast3d.timeout = 300,
    cast3d.max_retries = 3,
    cast3d.proxy = Sys.getenv("CAST3D_PROXY", unset = NA_character_),
    cast3d.output_dir = NULL
  )
  toset <- !(names(op_cast3d) %in% names(op))
  if (any(toset)) options(op_cast3d[toset])
  invisible()
}

.onAttach <- function(libname, pkgname) {
  if (is.na(getOption("cast3d.api_key"))) {
    packageStartupMessage(
      "cast3d: Set your API key with cast3d_setup(api_key = \"your-key\")\n",
      "  or set the TRIPO_API_KEY environment variable."
    )
  }
  invisible()
}
