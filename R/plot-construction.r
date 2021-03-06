#' Add components to a plot
#'
#' `+` is the key to constructing sophisticated ggplot2 graphics. It
#' allows you to start simple, then get more and more complex, checking your
#' work at each step.
#'
#' @section What can you add?:
#' You can add any of the following types of objects:
#'
#'   - An [aes()] object replaces the default aesthetics.
#'   - A layer created by a `geom_` or `stat_` function adds a
#'     new layer.
#'   - A `scale` overrides the existing scale.
#'   - A [theme()] modifies the current theme.
#'   - A `coord` overrides the current coordinate system.
#'   - A `facet` specification overrides the current faceting.
#'
#' To replace the current default data frame, you must use `%+%`,
#' due to S3 method precedence issues. I
#'
#' From R 4.1, if using the base pipe, `|>`, you must use `%+%`.
#'
#' You can also supply a list, in which case each element of the list will
#' be added in turn.
#'
#' @param e1
#' An object of class [ggplot()] or a [theme()], or potentially a
#' data.frame-like object in the ternary use of `%+%`.
#'
#' @param e2 A plot component, as described below, or potentially a
#' chain of ggplot functions in the ternary use of `%+%`.
#' @seealso [theme()]
#' @export
#' @method + gg
#' @rdname gg-add
#' @examples
#' base <-
#'  ggplot(mpg, aes(displ, hwy)) +
#'  geom_point()
#' base + geom_smooth()
#'
#' # To override the data, you must use %+%
#' base %+% subset(mpg, fl == "p")
#'
#' # Alternatively, you can add multiple components with a list.
#' # This can be useful to return from a function.
#' base + list(subset(mpg, fl == "p"), geom_smooth())
#'
#' \dontrun{
#' #Compatible with R 4.1+ only
#' mpg |>
#'   ggplot(aes(displ,hw)) %+%
#'   geom_point()
#'
#' mpg |>
#'   ggplot() %+%
#'   aes(displ,hw) %+%
#'   geom_point() %+%
#'   geom_path()
#' }
#'
"+.gg" <- function(e1, e2) {
  if (missing(e2)) {
    abort("Cannot use `+.gg()` with a single argument. Did you accidentally put + on a new line?")
  }

  # Get the name of what was passed in as e2, and pass along so that it
  # can be displayed in error messages
  e2name <- deparse(substitute(e2))

  if      (is.theme(e1))  add_theme(e1, e2, e2name)
  else if (is.ggplot(e1)) add_ggplot(e1, e2, e2name)
  else if (is.ggproto(e1)) {
    abort("Cannot add ggproto objects together. Did you forget to add this object to a ggplot object?")
  }
}


#' @rdname gg-add
#' @param e3 A plot component, as described below (only used in `%+%`)
#' @usage `\%+\%`(e1,e2,e3)
#' @export
`%+%` <- function(e1,e2,e3){
  if(missing(e3)){
    `+.gg`(e1,e2)
  } else {
    `+.gg`(insert_data_into_ggplot(e1,e2),e3)
  }
}


insert_data_into_ggplot <- function(data,gg_chain){
  if(is_gg_add(gg_chain)){
    dep <- 2
    while(is_gg_add(gg_chain[[dep]])){
      dep <- c(dep,2)
    }
    first_piece <- gg_chain[[dep]]
    len_fp <- length(first_piece)
    if(len_fp > 1){
      first_piece[2:len_fp + 1] <- first_piece[2:len_fp]
    }
    first_piece[[2]] <- data

    gg_chain[[dep]] <- first_piece

  } else {
    len_gg <- length(gg_chain)

    if(len_gg > 1){
      gg_chain[2:len_gg + 1] <- gg_chain[2:len_gg]
    }
    gg_chain[[2]] <- data

  }
  eval(gg_chain,envir = parent.frame())
}

is_gg_add <- function(x){
  is.call(x) && identical(x[[1]],quote(`%+%`))
}


add_ggplot <- function(p, object, objectname) {
  if (is.null(object)) return(p)

  p <- plot_clone(p)
  p <- ggplot_add(object, p, objectname)
  set_last_plot(p)
  p
}
#' Add custom objects to ggplot
#'
#' This generic allows you to add your own methods for adding custom objects to
#' a ggplot with [+.gg].
#'
#' @param object An object to add to the plot
#' @param plot The ggplot object to add `object` to
#' @param object_name The name of the object to add
#'
#' @return A modified ggplot object
#'
#' @keywords internal
#' @export
ggplot_add <- function(object, plot, object_name) {
  UseMethod("ggplot_add")
}
#' @export
ggplot_add.default <- function(object, plot, object_name) {
  abort(glue("Can't add `{object_name}` to a ggplot object."))
}
#' @export
ggplot_add.NULL <- function(object, plot, object_name) {
  plot
}
#' @export
ggplot_add.data.frame <- function(object, plot, object_name) {
  plot$data <- object
  plot
}
#' @export
ggplot_add.function <- function(object, plot, object_name) {
  abort(glue(
    "Can't add `{object_name}` to a ggplot object.\n",
    "Did you forget to add parentheses, as in `{object_name}()`?"
  ))
}
#' @export
ggplot_add.theme <- function(object, plot, object_name) {
  plot$theme <- add_theme(plot$theme, object)
  plot
}
#' @export
ggplot_add.Scale <- function(object, plot, object_name) {
  plot$scales$add(object)
  plot
}
#' @export
ggplot_add.labels <- function(object, plot, object_name) {
  update_labels(plot, object)
}
#' @export
ggplot_add.guides <- function(object, plot, object_name) {
  update_guides(plot, object)
}
#' @export
ggplot_add.uneval <- function(object, plot, object_name) {
  plot$mapping <- defaults(object, plot$mapping)
  # defaults() doesn't copy class, so copy it.
  class(plot$mapping) <- class(object)

  labels <- make_labels(object)
  names(labels) <- names(object)
  update_labels(plot, labels)
}
#' @export
ggplot_add.Coord <- function(object, plot, object_name) {
  if (!isTRUE(plot$coordinates$default)) {
    message(
      "Coordinate system already present. Adding new coordinate ",
      "system, which will replace the existing one."
    )
  }

  plot$coordinates <- object
  plot
}
#' @export
ggplot_add.Facet <- function(object, plot, object_name) {
  plot$facet <- object
  plot
}
#' @export
ggplot_add.list <- function(object, plot, object_name) {
  for (o in object) {
    plot <- plot %+% o
  }
  plot
}
#' @export
ggplot_add.by <- function(object, plot, object_name) {
  ggplot_add.list(object, plot, object_name)
}

#' @export
ggplot_add.Layer <- function(object, plot, object_name) {
  plot$layers <- append(plot$layers, object)

  # Add any new labels
  mapping <- make_labels(object$mapping)
  default <- make_labels(object$stat$default_aes)
  new_labels <- defaults(mapping, default)
  plot$labels <- defaults(plot$labels, new_labels)
  plot
}
