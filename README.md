
<!-- README.md is generated from README.Rmd. Please edit that file -->

# populate

Draft for discussion.

This issue was closed : <https://github.com/tidyverse/dplyr/issues/6547>

Is this extension package useful ?

{populate} provides stricter wrappers around `dplyr::mutate()`:

- `populate()` makes sure the input’s ptype is preserved
  - no column type change
  - no column addition
  - no column deletion (`mutate()` can delete with `NULL`)
  - cast by default, assert optionally
- `collate()` only creates new columns

Do we need more or should we keep it simple?

- `abrogate()` to remove columns ?
- `sublimate()` like `populate()` but allow ptype change (doesn’t allow
  new col creation) ?
- `summarize()` variants ?

Is it better to use a subclass of data frame (as in linked github issue)
so we can make safe versions of everything including functions like
`count()`, `unnest()`, joins …

We’d lose autocomplete of new args, maybe more confusing than having new
verbs ?

## Installation

You can install the development version of populate like so:

``` r
devtools::install_github("cynkra/populate")
```

## Examples

``` r
library(populate)

data <- tibble::tibble(
  a = letters[1:2],
  b = c(1,2), 
  c = factor(letters[1:2]), 
  d = as.Date(c("2022-01-01", "2022-01-02")), 
  e = vctrs::list_of(cars)
)

# can't create a column if it exists
collate(data, a = 1) 
#> Error in `collate()`:
#> ! `collate()` can't override existing columns.
#> ℹ Found in data: `a`.
#> ℹ Do you need `populate()`?

# but we can create new columns
collate(data, ee = 1) 
#> # A tibble: 2 × 6
#>   a         b c     d                       e    ee
#>   <chr> <dbl> <fct> <date>     <list<df[,2]>> <dbl>
#> 1 a         1 a     2022-01-01       [50 × 2]     1
#> 2 b         2 b     2022-01-02       [50 × 2]     1

# we can't create a new column with populate()
populate(data, ee = 1) 
#> Error in `populate()`:
#> ! `populate()` can't create new columns.
#> ✖ Not found in data: `ee`.
#> ℹ Did you need mispell `e`?
#> ℹ Do you need `collate()`?

 # can't cast double to character
populate(data, a = 1)
#> Error in `populate()`:
#> ! Can't `populate()` the data.
#> Caused by error in `dplyr::mutate()` at ]8;line = 55:col = 2;file:///Users/Antoine/git/populate/R/populate.Rpopulate/R/populate.R:55:2]8;;:
#> ℹ In argument: `a = vctrs::vec_cast(1, vctrs::vec_ptype(a))`.
#> Caused by error:
#> ! Can't convert `1` <double> to <character>.

# casting integer to double
populate(data, b = 3:4) 
#> # A tibble: 2 × 5
#>   a         b c     d                       e
#>   <chr> <dbl> <fct> <date>     <list<df[,2]>>
#> 1 a         3 a     2022-01-01       [50 × 2]
#> 2 b         4 b     2022-01-02       [50 × 2]

# doesn't work if `.strict` is `TRUE`
populate(data, b = 3:4, .strict = TRUE) 
#> Error in `populate()`:
#> ! Can't `populate()` the data.
#> Caused by error in `dplyr::mutate()` at ]8;line = 55:col = 2;file:///Users/Antoine/git/populate/R/populate.Rpopulate/R/populate.R:55:2]8;;:
#> ℹ In argument: `b = vctrs::vec_assert(3:4, vctrs::vec_ptype(b))`.
#> Caused by error:
#> ! `3:4` must be a vector with type <double>.
#> Instead, it has type <integer>.

# casting character to factor with allowed levels
populate(data, c = c("b", "b")) 
#> # A tibble: 2 × 5
#>   a         b c     d                       e
#>   <chr> <dbl> <fct> <date>     <list<df[,2]>>
#> 1 a         1 b     2022-01-01       [50 × 2]
#> 2 b         2 b     2022-01-02       [50 × 2]

# can't cast because wrong levels
populate(data, c = c("b", "d")) 
#> Error in `populate()`:
#> ! Can't `populate()` the data.
#> Caused by error in `dplyr::mutate()` at ]8;line = 55:col = 2;file:///Users/Antoine/git/populate/R/populate.Rpopulate/R/populate.R:55:2]8;;:
#> ℹ In argument: `c = vctrs::vec_cast(c("b", "d"), vctrs::vec_ptype(c))`.
#> Caused by error:
#> ! Can't convert from `c("b", "d")` <character> to <factor<38051>> due to loss of generality.
#> • Locations: 2

# datetimes are casted to date
populate(data, d = lubridate::as_datetime(c("2022-01-01", "2022-01-02"))) 
#> # A tibble: 2 × 5
#>   a         b c     d                       e
#>   <chr> <dbl> <fct> <date>     <list<df[,2]>>
#> 1 a         1 a     2022-01-01       [50 × 2]
#> 2 b         2 b     2022-01-02       [50 × 2]

 # characters can't be casted to date
populate(data, d = c("2022-01-01", "2022-01-02"))
#> Error in `populate()`:
#> ! Can't `populate()` the data.
#> Caused by error in `dplyr::mutate()` at ]8;line = 55:col = 2;file:///Users/Antoine/git/populate/R/populate.Rpopulate/R/populate.R:55:2]8;;:
#> ℹ In argument: `d = vctrs::vec_cast(c("2022-01-01", "2022-01-02"),
#>   vctrs::vec_ptype(d))`.
#> Caused by error:
#> ! Can't convert `c("2022-01-01", "2022-01-02")` <character> to <date>.

# using list_of allowed us to prevent corrupting our data silently
populate(data, e = list(iris)) 
#> Error in `populate()`:
#> ! Can't `populate()` the data.
#> Caused by error in `dplyr::mutate()` at ]8;line = 55:col = 2;file:///Users/Antoine/git/populate/R/populate.Rpopulate/R/populate.R:55:2]8;;:
#> ℹ In argument: `e = vctrs::vec_cast(list(iris), vctrs::vec_ptype(e))`.
#> Caused by error:
#> ! Can't convert from `..1` <data.frame<
#>   Sepal.Length: double
#>   Sepal.Width : double
#>   Petal.Length: double
#>   Petal.Width : double
#>   Species     : factor<fb977>
#> >> to <data.frame<
#>   speed: double
#>   dist : double
#> >> due to loss of precision.

# and we don't have to bother with list_of anymore if we feed the right format
populate(data, e = list(head(cars))) 
#> # A tibble: 2 × 5
#>   a         b c     d                       e
#>   <chr> <dbl> <fct> <date>     <list<df[,2]>>
#> 1 a         1 a     2022-01-01        [6 × 2]
#> 2 b         2 b     2022-01-02        [6 × 2]
```
