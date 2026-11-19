# Classes skipped when collecting numbers

Objects of these classes are not walked when a step's values are
flattened into numbers and element names: model fits, plot objects and
the like are large, and what users read from them is usually reached
through a summary or an accessor. Extend the list for package-specific
classes:
`dossier(..., skip_classes = c(default_skip_classes(), "maihda_model"))`.

## Usage

``` r
default_skip_classes()
```

## Value

A character vector of class names.

## Examples

``` r
default_skip_classes()
#>  [1] "lm"              "glm"             "nls"             "merMod"         
#>  [5] "lmerMod"         "glmerMod"        "brmsfit"         "stanfit"        
#>  [9] "clm"             "clmm"            "gam"             "ggplot"         
#> [13] "gg"              "ggplot2::ggplot" "patchwork"       "gtable"         
#> [17] "grob"            "gTree"           "recordedplot"    "formula"        
#> [21] "family"          "terms"           "data.table"     
```
