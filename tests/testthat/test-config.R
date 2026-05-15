test_that("tripo_setup stores options", {
  op <- options()
  on.exit(options(op))

  tripo_setup(
    api_key = "sk-test-key-1234567890",
    base_url = "https://api.example.com",
    timeout = 60,
    max_retries = 5
  )

  expect_equal(getOption("tripo3d.api_key"), "sk-test-key-1234567890")
  expect_equal(getOption("tripo3d.base_url"), "https://api.example.com")
  expect_equal(getOption("tripo3d.timeout"), 60)
  expect_equal(getOption("tripo3d.max_retries"), 5)
})

test_that("tripo_setup with api_key='env' errors when TRIPO_API_KEY not set", {
  op <- options()
  on.exit(options(op))

  cur <- Sys.getenv("TRIPO_API_KEY")
  Sys.unsetenv("TRIPO_API_KEY")
  on.exit(Sys.setenv(TRIPO_API_KEY = cur), add = TRUE)

  options(tripo3d.api_key = NULL)
  expect_error(tripo_setup(api_key = "env"), "No API key found")
})

test_that("tripo_setup warns on placeholder key", {
  op <- options()
  on.exit(options(op))

  expect_warning(
    tripo_setup(api_key = "your-api-key"),
    "placeholder"
  )
})

test_that("get_tripo_option retrieves option", {
  op <- options(tripo3d.testopt = "hello")
  on.exit(options(op))

  expect_equal(get_tripo_option("testopt"), "hello")
  expect_null(get_tripo_option("nonexistent"))
  expect_equal(get_tripo_option("nonexistent", 42), 42)
})

test_that("get_tripo_options returns a named list", {
  opts <- get_tripo_options()
  expect_named(opts, c("api_key", "base_url", "timeout", "max_retries", "proxy", "output_dir"))
})

test_that("get_output_dir returns a valid path", {
  dir <- get_output_dir()
  expect_type(dir, "character")
  expect_true(dir.exists(dir))
})
