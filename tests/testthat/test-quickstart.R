## Runs the quickstart example script as part of the package test suite.
## This ensures the complete end-to-end workflow stays in sync with the
## bundled data and exported API.

test_that("quickstart example runs without errors", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_proj()

    script <- system.file("examples", "quickstart.R",
                          package = "maxentcpp")
    expect_true(nchar(script) > 0, info = "quickstart.R not found in package")

    # Run the script in a clean environment so it does not pollute the test
    # namespace, and capture any messages/warnings via tryCatch.
    env <- new.env(parent = globalenv())
    expect_no_error(source(script, local = env))
})
