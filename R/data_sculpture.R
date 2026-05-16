#' Build 3D data sculptures from R data
#'
#' Construct precise 3D data sculptures directly from numeric data using
#' \pkg{rgl} mesh primitives, export as GLB, and return a \code{cast3d_model}
#' compatible with \code{\link{view_3d}()}. No AI generation — every point,
#' bar, or surface cell maps exactly to a physical 3D element.
#'
#' \code{data_sculpture()} does not depend on \pkg{rgl2gltf}; it writes
#' minimal GLB files directly.
#'
#' @param x Numeric vector. X-axis values.
#' @param y Numeric vector. Y-axis values.
#' @param z Optional numeric vector. Z-axis values (height). If \code{NULL},
#'   heights default to 1 for pins/bars.
#' @param type Geometry type. \code{"pin"} (default) creates raised cylindrical
#'   pins; \code{"bar"} creates rectangular extrusions; \code{"terrain"}
#'   creates a 2D grid as stepped terrain.
#' @param radius Pin/bar half-width. Default auto-scaled to 2\% of coordinate
#'   span.
#' @param color Pin/bar/cell colors. Recycled to match data length.
#'   Default \code{"steelblue"}.
#' @param base_height Base plate thickness below data elements. Default 0.1.
#' @param base_color Base plate color. Default \code{"#e8e8e8"}.
#' @param wall If \code{TRUE}, add a thin border wall. Default \code{FALSE}.
#' @param output_dir Directory to save the GLB file. Default uses the package
#'   cache.
#' @param filename Output filename. Default auto-generated.
#' @param ... Additional arguments (reserved for future use).
#'
#' @return A \code{cast3d_model} object.
#' @export
#'
#' @examples
#' \dontrun{
#' data(mtcars)
#' m <- data_sculpture(mtcars$wt, mtcars$mpg, mtcars$hp / 10,
#'                      type = "pin", radius = 0.08,
#'                      color = hcl.colors(32, "Viridis"))
#' view_3d(m)
#'
#' m <- data_sculpture(1:5, rep(0, 5), c(3, 5, 2, 4, 6),
#'                      type = "bar", color = "coral")
#' view_3d(m)
#' }
data_sculpture <- function(x,
                           y,
                           z = NULL,
                           type = c("pin", "bar", "terrain"),
                           radius = NULL,
                           color = "steelblue",
                           base_height = 0.1,
                           base_color = "#e8e8e8",
                           wall = FALSE,
                           output_dir = NULL,
                           filename = NULL,
                           ...) {
  if (!requireNamespace("rgl", quietly = TRUE)) {
    cli::cli_abort(
      "rgl is required for data_sculpture().",
      i = "Install with {.code install.packages(\"rgl\")}."
    )
  }

  type <- match.arg(type)
  n <- length(x)
  if (length(y) != n)
    cli::cli_abort("x and y must have the same length")
  if (is.null(z)) z <- rep(1, n)
  else if (length(z) != n)
    cli::cli_abort("z must have the same length as x and y")

  color <- rep(color, length.out = n)
  rx <- range(x); ry <- range(y)
  span_x <- diff(rx); span_y <- diff(ry)
  span_max <- max(span_x, span_y, 1)
  if (is.null(radius)) radius <- span_max * 0.02

  meshes <- list()

  switch(type,
    pin = {
      for (i in seq_along(x)) {
        if (z[i] <= 0) next
        cyl <- rgl::cylinder3d(
          center = cbind(c(x[i], x[i]), c(0, z[i]), c(y[i], y[i])),
          radius = radius, sides = 8, closed = -2
        )
        cyl$material$color <- color[[i]]
        meshes <- c(meshes, list(cyl))
      }
    },
    bar = {
      for (i in seq_along(x)) {
        if (z[i] <= 0) next
        bar <- rgl::translate3d(
          rgl::scale3d(rgl::cube3d(), radius, z[i] / 2, radius),
          x[i], z[i] / 2, y[i]
        )
        bar$material$color <- color[[i]]
        meshes <- c(meshes, list(bar))
      }
    },
    terrain = sculpt_terrain_meshes(x, y, z, radius, color)
  )

  x_off <- (rx[1] + rx[2]) / 2
  z_off <- (ry[1] + ry[2]) / 2
  base_w <- span_x * 1.15; base_d <- span_y * 1.15
  base <- rgl::translate3d(
    rgl::scale3d(rgl::cube3d(), base_w / 2, base_height / 2, base_d / 2),
    x_off, -base_height / 2, z_off
  )
  base$material$color <- base_color
  meshes <- c(meshes, list(base))

  glb_path <- file.path(
    output_dir %||% get_output_dir(),
    filename %||% paste0("sculpture_", paste(sample(letters, 8), collapse = ""), ".glb")
  )
  write_meshes_glb(meshes, glb_path)

  cli::cli_alert_success("Sculpture saved: {.file {glb_path}}")

  new_cast3d_model(
    local_path = glb_path, task_id = "data_sculpture",
    metadata = list(
      format = "GLB", size_bytes = file.info(glb_path)$size,
      vertices = NA_integer_, faces = NA_integer_
    )
  )
}

sculpt_terrain_meshes <- function(x, y, z, radius, color) {
  n_grid <- max(round(sqrt(length(x))), 12)
  gx <- seq(min(x), max(x), length.out = n_grid)
  gy <- seq(min(y), max(y), length.out = n_grid)
  gz <- interp_grid_values(x, y, z, gx, gy)

  cell_w <- (max(gx) - min(gx)) / (n_grid - 1) * 0.45
  cell_d <- (max(gy) - min(gy)) / (n_grid - 1) * 0.45
  col <- grDevices::colorRampPalette(c("#ffffff", color[1]))(20)

  meshes <- list()
  for (i in seq_len(n_grid)) {
    for (j in seq_len(n_grid)) {
      h <- gz[i, j]
      if (is.na(h) || h <= 0) next
      col_idx <- min(max(round(h / max(gz, na.rm = TRUE) * 19) + 1, 1), 20)
      cell <- rgl::translate3d(
        rgl::scale3d(rgl::cube3d(), cell_w, h / 2, cell_d),
        gx[i], h / 2, gy[j]
      )
      cell$material$color <- col[col_idx]
      meshes <- c(meshes, list(cell))
    }
  }
  meshes
}

interp_grid_values <- function(x, y, z, gx, gy) {
  nx <- length(gx); ny <- length(gy)
  z_out <- matrix(NA_real_, nx, ny)
  for (i in seq_len(nx)) {
    for (j in seq_len(ny)) {
      d <- sqrt((x - gx[i])^2 + (y - gy[j])^2)
      w <- 1 / pmax(d, 1e-8)
      z_out[i, j] <- sum(z * w) / sum(w)
    }
  }
  z_out
}

write_meshes_glb <- function(mesh_list, file) {
  all_vb <- list(); all_col <- list()
  all_ibuf <- list()
  mesh_tri_counts <- integer(0)
  mesh_has_tri <- logical(0)
  vb_offset <- 0L

  for (m in mesh_list) {
    vb <- m$vb[1:3, , drop = FALSE]
    it <- if (!is.null(m$it)) m$it - 1L else matrix(integer(0), 3, 0)
    nv <- ncol(vb); nt <- ncol(it)

    all_vb <- c(all_vb, list(vb))
    if (nt > 0) {
      it_offset <- it + vb_offset
      ib <- writeBin(as.vector(it_offset), raw(), size = 4, endian = "little")
      r <- length(ib) %% 4
      if (r > 0) ib <- c(ib, raw(4 - r))
      all_ibuf <- c(all_ibuf, list(ib))
      mesh_tri_counts <- c(mesh_tri_counts, nt)
      mesh_has_tri <- c(mesh_has_tri, TRUE)
    } else {
      mesh_has_tri <- c(mesh_has_tri, FALSE)
    }
    vb_offset <- vb_offset + nv

    col_hex <- m$material$color %||% "#808080"
    col_rgb <- grDevices::col2rgb(col_hex)[, 1] / 255
    all_col <- c(all_col, list(matrix(col_rgb, nrow = 3, ncol = nv)))
  }

  pad4 <- function(x) {
    r <- length(x) %% 4
    if (r > 0) c(x, raw(4 - r)) else x
  }

  vb_all <- do.call(cbind, all_vb)
  col_all <- do.call(cbind, all_col)
  n_verts <- ncol(vb_all)

  vbuf <- pad4(writeBin(as.vector(vb_all), raw(), size = 4, endian = "little"))
  cbuf <- pad4(writeBin(as.vector(col_all), raw(), size = 4, endian = "little"))

  bv_offset <- 0L
  bc_offset <- length(vbuf)

  bin_parts <- list(vbuf, cbuf)
  buffer_views <- list(
    list(buffer = 0L, byteOffset = bv_offset, byteLength = length(vbuf),
         target = 34962L),
    list(buffer = 0L, byteOffset = bc_offset, byteLength = length(cbuf),
         target = 34962L)
  )
  accessors <- list(
    list(bufferView = 0L, componentType = 5126L, count = n_verts,
         type = "VEC3", max = as.list(apply(vb_all, 1, max)),
         min = as.list(apply(vb_all, 1, min))),
    list(bufferView = 1L, componentType = 5126L, count = n_verts,
         type = "VEC3")
  )

  byte_cursor <- bc_offset + length(cbuf)
  primitives <- list()
  ibuf_idx <- 1L

  for (idx in seq_along(mesh_list)) {
    if (!mesh_has_tri[idx]) {
      primitives <- c(primitives, list(list(
        attributes = list(POSITION = 0L, COLOR_0 = 1L),
        material = 0L,
        mode = 0L
      )))
      next
    }

    ib <- if (ibuf_idx <= length(all_ibuf)) all_ibuf[[ibuf_idx]] else raw()
    nt <- if (ibuf_idx <= length(mesh_tri_counts)) mesh_tri_counts[[ibuf_idx]] else 0L
    ibuf_idx <- ibuf_idx + 1L
    bin_parts <- c(bin_parts, list(ib))

    bv_idx <- length(buffer_views)
    acc_idx <- length(accessors)

    buffer_views <- c(buffer_views, list(list(
      buffer = 0L, byteOffset = byte_cursor, byteLength = length(ib),
      target = 34963L
    )))
    accessors <- c(accessors, list(list(
      bufferView = bv_idx, componentType = 5125L,
      count = as.integer(nt * 3), type = "SCALAR"
    )))

    primitives <- c(primitives, list(list(
      attributes = list(POSITION = 0L, COLOR_0 = 1L),
      indices = acc_idx,
      material = 0L,
      mode = 4L
    )))

    byte_cursor <- byte_cursor + length(ib)
  }

  bin_data <- Reduce(c, bin_parts)
  total_bin <- length(bin_data)

  gltf <- list(
    asset = list(version = "2.0"),
    scene = 0L,
    scenes = list(list(nodes = list(0L))),
    nodes = list(list(mesh = 0L)),
    meshes = list(list(primitives = primitives)),
    accessors = accessors,
    bufferViews = buffer_views,
    buffers = list(list(byteLength = total_bin)),
    materials = list(list(
      pbrMetallicRoughness = list(
        baseColorFactor = list(1.0, 1.0, 1.0, 1.0),
        metallicFactor = 0.0, roughnessFactor = 1.0
      ),
      doubleSided = TRUE
    ))
  )

  json_str <- jsonlite::toJSON(gltf, auto_unbox = TRUE, digits = 8)
  json_raw <- charToRaw(json_str)
  jpad <- (4 - length(json_raw) %% 4) %% 4
  json_padded_len <- length(json_raw) + jpad

  header <- writeBin(c(0x46546C67L, 2L, 0L), raw(), size = 4, endian = "little")
  json_chunk_header <- writeBin(c(as.integer(json_padded_len), as.integer(0x4E4F534A)), raw(), size = 4, endian = "little")
  bin_chunk_header <- writeBin(c(as.integer(total_bin), as.integer(0x004E4942)), raw(), size = 4, endian = "little")
  total_length <- 12L + 8L + as.integer(json_padded_len) + 8L + as.integer(total_bin)
  header[9:12] <- writeBin(as.integer(total_length), raw(), size = 4, endian = "little")

  con <- file(file, "wb")
  on.exit(close(con))
  writeBin(header, con)
  writeBin(json_chunk_header, con)
  writeBin(json_raw, con)
  if (jpad > 0)
    writeBin(as.raw(rep(0x20, jpad)), con)
  writeBin(bin_chunk_header, con)
  writeBin(bin_data, con)
  invisible(file)
}
