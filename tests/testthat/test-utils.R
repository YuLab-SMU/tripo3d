test_that("%||% returns left when not NULL", {
  expect_equal("a" %||% "b", "a")
  expect_equal(0L %||% 1L, 0L)
  expect_equal(FALSE %||% TRUE, FALSE)
})

test_that("%||% returns right when left is NULL", {
  expect_equal(NULL %||% "b", "b")
  expect_equal(NULL %||% 42, 42)
})

test_that("build_url concatenates correctly", {
  op <- options(tripo3d.base_url = "https://api.tripo3d.ai")
  on.exit(options(op))
  result <- build_url("/v2/openapi/task/abc")
  expect_equal(result, "https://api.tripo3d.ai/v2/openapi/task/abc")
})

test_that("build_url removes duplicate slashes", {
  op <- options(tripo3d.base_url = "https://api.tripo3d.ai/")
  on.exit(options(op))
  result <- build_url("/v2/openapi/status")
  expect_equal(result, "https://api.tripo3d.ai/v2/openapi/status")
})

test_that("check_api_key returns key on valid config", {
  op <- options(tripo3d.api_key = "sk-test-key-12345678")
  on.exit(options(op))
  expect_type(check_api_key(), "character")
})

test_that("check_api_key errors when API key is not set", {
  op <- options(tripo3d.api_key = NA_character_)
  on.exit(options(op))
  expect_error(check_api_key(), class = "tripo_no_auth_error")
})

test_that("read_image_to_base64 works with raw input", {
  img <- as.raw(c(0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46))
  b64 <- read_image_to_base64(img)
  expect_type(b64, "character")
  expect_match(b64, "^/9j/")
})

test_that("read_image_to_base64 errors on missing file", {
  expect_error(
    read_image_to_base64("/no/such/image.jpg"),
    "file path"
  )
})

test_that("is_tripo_error detects httr2 error responses", {
  e <- simpleError("nope")
  expect_false(is_tripo_error(e))
  rlang_null <- if (requireNamespace("rlang", quietly = TRUE)) rlang::zap() else NULL
  expect_false(is_tripo_error(rlang_null))
})
