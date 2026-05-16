test_that("new_cast3d_task creates correct class", {
  task <- new_cast3d_task(
    task_id = "task-123",
    status = "success",
    created_at = "2024-01-01T00:00:00Z",
    model_url = "https://api.tripo3d.ai/v2/models/model-456.glb",
    error_message = NULL,
    raw = list()
  )
  expect_s3_class(task, "cast3d_task")
  expect_equal(task$task_id, "task-123")
  expect_equal(task$status, "success")
})

test_that("new_cast3d_task handles running status", {
  task <- new_cast3d_task(
    task_id = "task-456",
    status = "running",
    created_at = "2024-01-01T00:00:00Z",
    model_url = NULL,
    error_message = NULL,
    raw = list()
  )
  expect_s3_class(task, "cast3d_task")
  expect_null(task$model_url)
})

test_that("new_cast3d_task handles error status", {
  task <- new_cast3d_task(
    task_id = "task-fail",
    status = "error",
    created_at = "2024-01-01T00:00:00Z",
    model_url = NULL,
    error_message = "Something went wrong",
    raw = list()
  )
  expect_s3_class(task, "cast3d_task")
  expect_equal(task$error_message, "Something went wrong")
})

test_that("print.cast3d_task does not error", {
  task <- new_cast3d_task("task-1", "success", Sys.time(),
                         model_url = "https://api.tripo3d.ai/models/model.glb",
                         error_message = NULL, raw = list())
  expect_no_error(print(task))
})

test_that("new_cast3d_model creates correct class", {
  model <- new_cast3d_model(
    local_path = "/path/to/model.glb",
    task_id = "task-123",
    metadata = list(format = "glb", vertices = 1000, faces = 2000)
  )
  expect_s3_class(model, "cast3d_model")
  expect_equal(model$local_path, "/path/to/model.glb")
  expect_equal(model$task_id, "task-123")
})

test_that("print.cast3d_model does not error", {
  model <- new_cast3d_model("/tmp/test.glb", "task-1",
                           metadata = list(format = "glb"))
  expect_no_error(print(model))
})
