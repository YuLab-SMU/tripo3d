test_that("create_3d_from_image validates inputs", {
  skip_if_no_api_key()
  skip_on_cran()
  skip_on_ci()

  expect_error(create_3d_from_image(character(0)), "path")
})

test_that("create_3d_from_image works with a file", {
  skip_if_no_network()
  skip_on_cran()
  skip_on_ci()

  tmp <- tempfile(fileext = ".png")
  png(tmp, width = 64, height = 64)
  par(mar = c(0, 0, 0, 0))
  image(matrix(runif(64), 8, 8), col = gray(0:8/8), axes = FALSE)
  dev.off()
  on.exit(unlink(tmp))

  task <- create_3d_from_image(tmp)
  expect_s3_class(task, "tripo_task")
})

test_that("generate_3d returns a tripo_model", {
  skip_if_no_network()
  skip_on_cran()
  skip_on_ci()

  tmp <- tempfile(fileext = ".png")
  png(tmp, width = 64, height = 64)
  par(mar = c(0, 0, 0, 0))
  image(matrix(runif(64), 8, 8), col = gray(0:8/8), axes = FALSE)
  dev.off()
  on.exit(unlink(tmp))

  model <- generate_3d(tmp, max_wait = 180)
  expect_s3_class(model, "tripo_model")
  expect_true(file.exists(model$local_path))
})
