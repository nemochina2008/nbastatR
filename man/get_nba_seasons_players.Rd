% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/players_seasons.R
\name{get_nba_seasons_players}
\alias{get_nba_seasons_players}
\title{Get Season's Players}
\usage{
get_nba_seasons_players(years_start = 1960:2017, nest_data = F,
  return_message = T)
}
\arguments{
\item{years_start}{vector of years start}

\item{nest_data}{if \code{TRUE} returns a nested data_frame}

\item{return_message}{if \code{TRUE} return message}
}
\description{
Get Season's Players
}
\examples{
get_nba_seasons_players(2010:2017, nest_data = T, return_message = T)
}
