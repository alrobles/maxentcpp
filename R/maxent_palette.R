#' Generate the Maxent Canonical Color Ramp
#'
#' Produces a vector of hex color strings matching the color ramp used by the
#' Java Maxent software (\code{density/Display.java::showColor()}).  The
#' default palette cycles Red → Yellow → Green → Cyan → Blue across 1020
#' steps, with higher values rendered as red and lower values as blue.
#'
#' @param n Integer: number of colors to generate (default 1020, matching the
#'   Java implementation).
#' @param mode Character: one of \code{"plain"} (default),
#'   \code{"log"} (logarithmic spacing), \code{"blackandwhite"}
#'   (greyscale, white = high, black = low), or \code{"redandyellow"}
#'   (red–yellow ramp).
#' @return Character vector of \code{n} hex color strings of the form
#'   \code{"#RRGGBB"}.
#' @export
#' @examples
#' pal <- maxent_color_ramp(1020)
#' pal[1]     # "#FF0000"  (max value → red)
#' pal[510]   # near "#00FF00" (mid-point → green)
#' pal[1020]  # "#0000FF"  (min value → blue)
maxent_color_ramp <- function(n = 1020L, mode = "plain") {
    n <- as.integer(n)
    if (n < 1L) stop("'n' must be >= 1")

    mode <- match.arg(mode, c("plain", "log", "blackandwhite", "redandyellow"))

    if (mode == "blackandwhite") {
        # White (high, index 1) → Black (low, index n)
        vals <- seq(255, 0, length.out = n)
        v    <- as.integer(round(vals))
        return(sprintf("#%02X%02X%02X", v, v, v))
    }

    if (mode == "redandyellow") {
        # Red (low) → Yellow (high)
        vals <- seq(0, 1, length.out = n)
        r    <- as.integer(255L)
        g    <- as.integer(round(vals * 255))
        b    <- as.integer(0L)
        return(sprintf("#%02X%02X%02X", r, g, b))
    }

    # Positions in [0, 1]: index 1 = max (red), index n = min (blue).
    # Replicate Java logic:  show_color divides [0, 255*4) into 4 bands.
    #   Band 0 (255..192): R=255,  G=0..255,  B=0
    #   Band 1 (192..128): R=255..0, G=255, B=0
    #   Band 2 (128..64):  R=0,   G=255, B=0..255
    #   Band 3 (64..0):    R=0,   G=255..0, B=255
    # frac=0 (index 1) → band 0 → red (high); frac=1 (index n) → band 3 → blue (low).

    # Fractional position from 0 (index 1, red/max) to 1 (index n, blue/min)
    frac <- if (mode == "log") {
        # log spacing: more resolution near low values
        log_pos <- seq(0, 1, length.out = n)
        (exp(log_pos) - 1) / (exp(1) - 1)
    } else {
        seq(0, 1, length.out = n)
    }

    # v in [0, n-1]: 0 = max (red), n-1 = min (blue)
    v    <- frac * (n - 1L)
    band <- floor(v / (n / 4))
    pos  <- (v %% (n / 4)) / (n / 4 - 1L)    # 0..1 within band
    pos  <- pmin(pmax(pos, 0), 1)

    r <- g <- b <- integer(n)

    # Band 0: R=255 G=0→255 B=0
    sel <- band == 0
    r[sel] <- 255L; g[sel] <- as.integer(round(pos[sel] * 255)); b[sel] <- 0L

    # Band 1: R=255→0 G=255 B=0
    sel <- band == 1
    r[sel] <- as.integer(round((1 - pos[sel]) * 255)); g[sel] <- 255L; b[sel] <- 0L

    # Band 2: R=0 G=255 B=0→255
    sel <- band == 2
    r[sel] <- 0L; g[sel] <- 255L; b[sel] <- as.integer(round(pos[sel] * 255))

    # Band 3 (and overflow): R=0 G=255→0 B=255
    sel <- band >= 3
    r[sel] <- 0L; g[sel] <- as.integer(round((1 - pos[sel]) * 255)); b[sel] <- 255L

    # Clamp
    r <- pmin(pmax(r, 0L), 255L)
    g <- pmin(pmax(g, 0L), 255L)
    b <- pmin(pmax(b, 0L), 255L)

    # Index 1 = max (red), index n = min (blue)
    sprintf("#%02X%02X%02X", r, g, b)
}
