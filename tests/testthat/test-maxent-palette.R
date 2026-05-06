test_that("maxent_color_ramp returns correct length and type", {
    pal <- maxent_color_ramp(1020)
    expect_length(pal, 1020)
    expect_true(is.character(pal))
    expect_true(all(grepl("^#[0-9A-F]{6}$", pal)))
})

test_that("maxent_color_ramp first element is red (max value)", {
    pal <- maxent_color_ramp(1020)
    expect_equal(pal[1], "#FF0000")
})

test_that("maxent_color_ramp last element is blue (min value)", {
    pal <- maxent_color_ramp(1020)
    expect_equal(pal[1020], "#0000FF")
})

test_that("maxent_color_ramp mid-point is near green", {
    pal <- maxent_color_ramp(1020)
    # Around index 510 the ramp passes through green (#00FF00)
    rgb_mid <- grDevices::col2rgb(pal[510])
    expect_true(rgb_mid["green", 1] > 200)
})

test_that("maxent_color_ramp custom n works", {
    pal <- maxent_color_ramp(100)
    expect_length(pal, 100)
})

test_that("maxent_color_ramp blackandwhite mode", {
    pal <- maxent_color_ramp(100, mode = "blackandwhite")
    expect_length(pal, 100)
    # First should be whitest, last should be darkest (or vice versa)
    rgb_first <- grDevices::col2rgb(pal[1])
    rgb_last  <- grDevices::col2rgb(pal[100])
    # In blackandwhite: first = white (high), last = black (low)
    # The ramp builds low → high then reverses, so [1] should be whiter
    expect_true(mean(rgb_first) > mean(rgb_last))
})

test_that("maxent_color_ramp redandyellow mode", {
    pal <- maxent_color_ramp(10, mode = "redandyellow")
    expect_length(pal, 10)
    expect_true(all(grepl("^#[0-9A-F]{6}$", pal)))
})

test_that("maxent_color_ramp log mode produces valid colors", {
    pal <- maxent_color_ramp(50, mode = "log")
    expect_length(pal, 50)
    expect_true(all(grepl("^#[0-9A-F]{6}$", pal)))
})

test_that("maxent_color_ramp n=1 does not error", {
    pal <- maxent_color_ramp(1)
    expect_length(pal, 1)
})

test_that("maxent_color_ramp errors on n < 1", {
    expect_error(maxent_color_ramp(0))
})
