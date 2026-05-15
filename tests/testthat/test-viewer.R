test_that("view_3d rejects invalid input", {
  expect_error(
    view_3d(character(0)),
    "must be a tripo_model or a .glb file path"
  )
  expect_error(
    view_3d("/no/such/model.glb"),
    "must be a tripo_model or a .glb file path"
  )
})

test_that("view_3d creates htmlwidget with tripo_model", {
  m <- structure(
    list(local_path = tempfile(fileext = ".glb")),
    class = "tripo_model"
  )
  # Write minimal GLB: magic + version + totalLength
  minimal_glb <- function(path) {
    header <- as.raw(c(0x67, 0x6C, 0x54, 0x46,  # magic "glTF"
                       0x02, 0x00, 0x00, 0x00,  # version 2
                       0x0C, 0x00, 0x00, 0x00)) # totalLength 12
    writeBin(header, path)
    path
  }
  on.exit(unlink(m$local_path))
  minimal_glb(m$local_path)
  w <- view_3d(m)
  expect_s3_class(w, "htmlwidget")
  expect_s3_class(w, "glb_viewer")
})

test_that("view_3d errors on missing file", {
  m <- structure(
    list(local_path = "/no/such/file.glb"),
    class = "tripo_model"
  )
  expect_error(view_3d(m), "not found")
})
