#' @importFrom utils adist
NULL

#' Populate a data frame
#'
#' A wrapper around `dplyr::mutate()` that enforces ptype stability, i.e. we
#'   guarantee that the `vctrs::vec_ptype()` of the output is `vctrs::vec_ptype(.data)`.
#' New columns cannot be created with `populate()`, use `collate()` for this purpose.
#'
#' @inheritParams dplyr::mutate
#' @param .strict Boolean. If `FALSE` (default), we attempt to cast the input
#'   tot he fitting type using `vctrs::vec_cast()`, if `TRUE` we perform a strict
#'   check using `vctrs::vec_assert()`
#'
#' @export
#' @seealso collate
#' @examples
#' \dontrun{
#' data <- tibble::tibble(
#'   a = letters[1:2],
#'   b = c(1,2),
#'   c = factor(letters[1:2]),
#'   d = as.Date(c("2022-01-01", "2022-01-02")),
#'   e = vctrs::list_of(cars)
#' )
#'
#' # can't create a column if it exists
#' collate(data, a = 1)
#'
#' # but we can create new columns
#' collate(data, ee = 1)
#'
#' # we can't create a new column with populate()
#' populate(data, ee = 1)
#'
#' # can't cast double to character
#' populate(data, a = 1)
#'
#' # casting integer to double
#' populate(data, b = 3:4)
#'
#' # doesn't work if `.strict` is `TRUE`
#' populate(data, b = 3:4, .strict = TRUE)
#'
#' # casting character to factor with allowed levels
#' populate(data, c = c("b", "b"))
#'
#' # can't cast because wrong levels
#' populate(data, c = c("b", "d"))
#'
#' # datetimes are casted to date
#' populate(data, d = lubridate::as_datetime(c("2022-01-01", "2022-01-02")))
#'
#' # characters can't be casted to date
#' populate(data, d = c("2022-01-01", "2022-01-02"))
#'
#' # using list_of allowed us to prevent corrupting our data silently
#' populate(data, e = list(iris))
#'
#' # and we don't have to bother with list_of anymore if we feed the right format
#' populate(data, e = list(head(cars)))
#' }
populate <- function(.data, ..., .strict = FALSE) {
  # convert dots to quosures so we can manipulate the expressions
  dots <- rlang::enquos(...)
  if(!all(names(dots) %in% names(.data))) {
    new_nms <- setdiff(names(dots), names(.data))
    dists <- adist(new_nms, names(.data))
    min_dists <- apply(dists, 1, which.min)
    candidates <- unique(names(.data)[min_dists])
    msg <- "`populate()` can't create new columns."
    info1 <- sprintf("Not found in data: %s.", toString(paste0("`", new_nms, "`")))
    info2 <- sprintf("Did you mispell %s?", toString(paste0("`", candidates, "`")))
    info3 <- "Do you need `collate()`?"
    rlang::abort(c(msg, x = info1, i = info2, i = info3))
  }
  # edit the expressions, wrapping them into `vctrs::vec_cast()`
  dots <- purrr::imap(dots, ~ {
    # `arg = fun(my_expr)` becomes `arg = vctrs::vec_cast(fun(my_expr), ptype(arg))`
    if (.strict) {
      new_expr <- dplyr::expr(vctrs::vec_assert(!!rlang::quo_squash(.x), vctrs::vec_ptype(!!rlang::sym(.y))))
    } else {
      new_expr <- dplyr::expr(vctrs::vec_cast(!!rlang::quo_squash(.x), vctrs::vec_ptype(!!rlang::sym(.y))))
    }

    # if arg is a constant env is empty, we set to baseenv(so we can fetch `::`)
    env <- rlang::quo_get_env(.x)
    if (identical(env, emptyenv())) .x <- rlang::quo_set_env(.x, baseenv())
    rlang::quo_set_expr(.x, new_expr)
  })
  out <- rlang::try_fetch(
    dplyr::mutate(.data, !!!dots, .keep = "all", .before = NULL, .after = NULL),
    error = function(cnd) {
      msg <- "Can't `populate()` the data."
      # info <- "Do you need `sublimate()`"
      rlang::abort(msg, parent = cnd)
    }
  )
  # FIXME: can we do this more elegantly ? `quo_is_null()` is not reliable, maybe we need `vec_cast()`/ `vec_assert()` wrappers
  if (!identical(names(out), names(.data))) {
    msg <- "`populate()` can't remove columns"
    info <- sprintf("Atempted to remove: %s", toString(paste0("`", setdiff(names(.data), names(out)), "`")))
    rlang::abort(c(msg, x = info))
  }
  out
}

#' Add columns to a data frame
#'
#' A wrapper around `dplyr::mutate()` that restricts the scope to the creation of
#'  new columns. It can be seen as a data masking variant of `dplyr::bind_cols()`.
#'
#' @inheritParams dplyr::mutate
#' @return A data frame
#' @seealso populate
#' @export
collate <- function(.data, ..., .before = NULL, .after = NULL) {
  dots <- rlang::enquos(...)
  if(any(names(dots) %in% names(.data))) {
    conflicting_nms <- intersect(names(dots), names(.data))
    msg <- "`collate()` can't override existing columns."
    info1 <- sprintf("Found in data: %s.", toString(paste0("`", conflicting_nms, "`")))
    info2 <- "Do you need `populate()`?"
    rlang::abort(c(msg, i = info1, i = info2))
  }
  rlang::try_fetch(
    dplyr::mutate(.data, ..., .keep = "all", .before = NULL, .after = NULL),
    error = function(cnd) rlang::abort("Can't `collate()` the data.", parent = cnd)
  )
}
