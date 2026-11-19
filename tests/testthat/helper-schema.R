# A validator for the part of JSON Schema that inst/schema/dossier.schema.json uses:
# type, const, enum, required, properties, additionalProperties, items and local
# $ref. `doc` and `schema` are parsed with jsonlite::fromJSON(simplifyVector = FALSE).
# Returns the problems found, as "path: problem" strings.
validate_json <- function(doc, schema, root = schema, path = "") {
  ref <- schema[["$ref"]]
  if (!is.null(ref)) return(validate_json(doc, root[["$defs"]][[sub("^#/\\$defs/", "", ref)]], root, path))
  where <- if (nzchar(path)) path else "/"
  if (!is.null(schema[["const"]]) && !identical(doc, schema[["const"]])) {
    return(sprintf("%s: is not %s", where, schema[["const"]]))
  }
  if (!is.null(schema[["enum"]]) && !any(vapply(schema[["enum"]], identical, logical(1), doc))) {
    return(sprintf("%s: %s is not an allowed value", where, format(doc)))
  }
  types <- unlist(schema[["type"]])
  if (length(types) && !any(vapply(types, json_type_is, logical(1), x = doc))) {
    return(sprintf("%s: is not of type %s", where, paste(types, collapse = " or ")))
  }
  errs <- character()
  if (json_type_is("object", doc)) {
    for (r in unlist(schema[["required"]])) {
      if (!r %in% names(doc)) errs <- c(errs, sprintf("%s: lacks %s", where, r))
    }
    for (nm in names(doc)) {
      sub <- schema[["properties"]][[nm]]
      if (is.null(sub)) sub <- schema[["additionalProperties"]]
      if (is.list(sub)) errs <- c(errs, validate_json(doc[[nm]], sub, root, paste0(path, "/", nm)))
    }
  } else if (json_type_is("array", doc) && is.list(schema[["items"]])) {
    for (i in seq_along(doc)) {
      errs <- c(errs, validate_json(doc[[i]], schema[["items"]], root, paste0(path, "/", i - 1L)))
    }
  }
  errs
}

json_type_is <- function(type, x) {
  switch(type,
    null = is.null(x),
    string = is.character(x) && length(x) == 1L,
    number = is.numeric(x) && length(x) == 1L,
    integer = is.numeric(x) && length(x) == 1L && !is.na(x) && x == round(x),
    boolean = is.logical(x) && length(x) == 1L && !is.na(x),
    object = is.list(x) && !is.null(names(x)),
    array = is.list(x) && is.null(names(x)),
    FALSE
  )
}

dossier_schema <- function() {
  jsonlite::fromJSON(system.file("schema", "dossier.schema.json", package = "pkgdossier"),
                     simplifyVector = FALSE)
}
