
# rotoworld ---------------------------------------------------------------

get_player_rotowire_news <-
  function(player_id = 201935,
           return_message = TRUE,
           results = 50) {
    json_url <-
      glue::glue(
        "https://stats-prod.nba.com/wp-json/statscms/v1/rotowire/player/?playerId={player_id}&limit={results}&offset=0"
      ) %>%
      as.character()

    json <-
      json_url %>%
      curl_json_to_vector()

    data <-
      json$PlayerRotowires %>%
      as_data_frame()

    actual_names <- names(data) %>% resolve_nba_names()
    data <-
      data %>%
      purrr::set_names(actual_names) %>%
      tidyr::unite(namePlayer, nameFirst, nameLast, sep = " ") %>%
      mutate_at(c("idUpdate", "idPlayer", "idRotoWorld", "dateISO", "numberPriority"),
                funs(. %>% as.numeric())) %>%
      mutate_at(c("datetimePublished", "datetimeUpdatedLast"),
                funs(. %>% lubridate::mdy_hms())) %>%
      mutate(isInjured = !slugInjured %>% str_detect("NO")) %>%
      dplyr::select(idPlayer, namePlayer, slugTeam, codeTeam, datetimePublished, articleHeadline, everything()) %>%
      mutate_if(is.character,
                funs(ifelse(. == "", NA_character_, .)))

    if (return_message) {
      glue::glue("Acquired {nrow(data)} Roto Wire articles for {data$namePlayer %>% unique()}") %>% message()
    }
    data
  }

#' Get players RotoWire news
#'
#' Returns rotowire news for specified
#' players.
#'
#' @param players vector of player_names
#' @param player_ids vector of player names
#' @param nest_data if \code{TRUE} returns a nested data frame
#' @param results integer of results
#' @param return_message if \code{TRUE} returns a message
#'
#' @return
#' @export
#' @import dplyr curl readr lubridate purrr jsonlite tidyr
#' @importFrom glue glue
#' @examples
#' get_players_roto_wire_news(players = c( "Jarrett Allen", "DeMarre Carroll", "Allen Crabbe"))
get_players_roto_wire_news <-
  function(players =  NULL,
           player_ids = NULL,
           nest_data = F,
           results = 50,
           return_message = TRUE) {
    if (!'df_nba_player_dict' %>% exists()) {
      df_nba_player_dict <-
        get_nba_players()

      assign(x = 'df_nba_player_dict', df_nba_player_dict, envir = .GlobalEnv)
    }
    ids <-
      get_nba_players_ids(player_ids = player_ids,
                          players = players)
    get_player_rotowire_news_safe <-
      purrr::possibly(get_player_rotowire_news, data_frame())

    all_data <-
      ids %>%
      map_df(function(id) {
        get_player_rotowire_news_safe(player_id = id, return_message = return_message)
      })

    all_data <-
      all_data %>%
      arrange(datetimePublished)




    all_data <-
      all_data %>%
      left_join(
        df_nba_player_dict %>% dplyr::select(nameTeam, idPlayer, matches("url"))
      ) %>%
      suppressMessages()

    if (nest_data) {
      all_data <-
        all_data %>%
        nest(
          -c(
            idPlayer,
            nameTeam,
            namePlayer,
            urlPlayerActionPhoto,
            urlPlayerStats,
            urlPlayerThumbnail,
            urlPlayerHeadshot
          ),
          .key = 'dataRotoWireArticles'
        ) %>%
        mutate(countArticles = dataRotoWireArticles %>% map_dbl(nrow))
    }
    all_data
  }

#' Get teams roto wire news
#'
#' Returns roto wire news for specified
#' teams.
#'
#' @param teams
#' @param nest_data
#' @param results
#' @param return_message
#'
#' @return
#' @export
#' @import dplyr curl readr lubridate purrr jsonlite tidyr
#' @importFrom glue glue
#' @examples
  get_teams_roto_wire_news <-
  function(teams = NULL,
           nest_data = F,
           results = 50,
           return_message = TRUE) {
    if (!'df_nba_player_dict' %>% exists()) {
      df_nba_player_dict <-
        get_nba_players()

      assign(x = 'df_nba_player_dict', df_nba_player_dict, envir = .GlobalEnv)
    }
    if (teams %>% purrr::is_null()) {
      stop("Please Enter a team name")
    }
    teams_search <-
      teams %>% str_to_lower() %>% str_c(collapse  = "|")

    ids <-
      df_nba_player_dict %>%
      mutate(teamLower = nameTeam %>% str_to_lower()) %>%
      filter(teamLower %>% str_detect(teams_search)) %>%
      pull(idPlayer) %>%
      unique()

    all_data <- get_players_roto_wire_news(player_ids = ids, nest_data = F, results = results)

    all_data <-
      all_data %>%
      arrange(desc(datetimePublished))

    if (nest_data) {
      all_data <-
        all_data %>%
        nest(
          -c(
            idPlayer,
            nameTeam,
            namePlayer,
            urlPlayerActionPhoto,
            urlPlayerStats,
            urlPlayerThumbnail,
            urlPlayerHeadshot
          ),
          .key = 'dataRotoWireArticles'
        ) %>%
        mutate(countArticles = dataRotoWireArticles %>% map_dbl(nrow)) %>%
        arrange(nameTeam, namePlayer)
    }
    all_data

  }

# transactions ------------------------------------------------------------


nba_transactions_historic <-
  function() {
    json <-
      "http://stats.nba.com/feeds/NBAPlayerTransactions-559107/json.js" %>%
      curl_json_to_vector()

    data <-
      json$ListItems %>%
      as_data_frame() %>%
      purrr::set_names(c("title", "descriptionTransaction", "idTeam", "nameTeamFrom",
                         "idPlayer", "dateTransaction", "idTransaction", "meta")) %>%
      mutate_at(c("idPlayer", "idTransaction", "idTeam"),
                funs(. %>% as.numeric())) %>%
      mutate(dateTransaction = lubridate::mdy(dateTransaction)) %>%
      select(-one_of("title", "nameTeamFrom", "meta")) %>%
      suppressWarnings()

    if (!'df_nba_team_dict' %>% exists()) {
      df_nba_team_dict <- get_nba_teams()

      assign('df_nba_team_dict', df_nba_team_dict, envir = .GlobalEnv)
    }

    if (!'df_nba_player_dict' %>% exists()) {
      df_nba_player_dict <-
        get_nba_players()

      assign(x = 'df_nba_player_dict', df_nba_player_dict, envir = .GlobalEnv)
    }
    data <-
      data %>%
      mutate(
        idPlayer = ifelse(idPlayer == 0 , NA, idPlayer),
        yearTransaction = lubridate::year(dateTransaction),
        monthTransaction = lubridate::month(dateTransaction),
        hasDraftPick = descriptionTransaction %>% str_detect("draft"),
        typeTransaction = case_when(
          descriptionTransaction %>% str_to_lower() %>% str_detect("trade") ~ "Trade",
          descriptionTransaction %>% str_to_lower() %>% str_detect("sign") ~ "Signing",
          descriptionTransaction %>% str_to_lower() %>% str_detect("waive") ~ "Waive",
          descriptionTransaction %>% str_to_lower() %>% str_detect("claimed") ~ "AwardOnWaivers"
        )
      ) %>%
      left_join(df_nba_player_dict %>% dplyr::select(idPlayer, namePlayer)) %>%
      left_join(df_nba_team_dict %>% dplyr::select(idTeam, nameTeam)) %>%
      suppressMessages()
    data


  }

#' Get NBA transactions since 2012
#'
#' @return
#' @export
#' @import dplyr purrr curl jsonlite readr lubridate tidyr tibble
#' @examples
get_nba_transactions <-
  function(include_histori) {
    json <-
      "http://stats.nba.com/js/data/playermovement/NBA_Player_Movement.json" %>%
      curl_json_to_vector()

    data <-
      json$NBA_Player_Movement$rows %>%
      as_data_frame()

    json_names <- json$NBA_Player_Movement$columns$Name
    actual_names <- json_names %>% resolve_nba_names()
    if (!'df_nba_team_dict' %>% exists()) {
      df_nba_team_dict <- get_nba_teams()

      assign('df_nba_team_dict', df_nba_team_dict, envir = .GlobalEnv)
    }

    if (!'df_nba_player_dict' %>% exists()) {
      df_nba_player_dict <-
        get_nba_players()

      assign(x = 'df_nba_player_dict', df_nba_player_dict, envir = .GlobalEnv)
    }

    data <-
      data %>%
      purrr::set_names(actual_names)

    data <-
      data %>%
      tidyr::separate(sortGroup,
                      into = c("remove", "idTransaction"),
                      sep = "\\ ") %>%
      mutate(
        dateTransaction = readr::parse_datetime(dateTransaction) %>% as.Date(),
        idTeamFrom = ifelse(idTeamFrom == 0, NA, idTeamFrom),
        idPlayer = ifelse(idPlayer == 0 , NA, idPlayer),
        yearTransaction = lubridate::year(dateTransaction),
        monthTransaction = lubridate::month(dateTransaction),
        hasDraftPick = descriptionTransaction %>% str_detect("draft"),
        idTransaction = idTransaction %>% as.numeric()
      ) %>%
      left_join(df_nba_player_dict %>% dplyr::select(idPlayer, namePlayer)) %>%
      left_join(df_nba_team_dict %>% dplyr::select(idTeam, nameTeam)) %>%
      left_join(df_nba_team_dict %>% dplyr::select(idTeamFrom = idTeam, nameTeamFrom = nameTeam)) %>%
      dplyr::select(-one_of("remove")) %>%
      suppressMessages()

    data <-
      data %>%
      bind_rows(    nba_transactions_historic())

    data <-
      data %>%
      dplyr::select(yearTransaction, monthTransaction,
                    dateTransaction, idTransaction, descriptionTransaction,
                    matches("name|id"), everything()) %>%
      arrange(desc(dateTransaction)) %>%
      distinct()

    data

  }


# beyond_the_numbers ------------------------------------------------------

#' Get Beyond the Numbers articles
#'
#' @param count_articles numeric vector of counts
#'
#' @return a \code{data_frame}
#' @export
#' @import dplyr curl jsonlite rvest xml2 purrr stringr lubridate readr
#' @importFrom glue glue
#' @examples
#'
#' get_beyond_the_numbers_articles(10)
get_beyond_the_numbers_articles <-
  function(count_articles = 50) {
    if (count_articles > 500){
      stop("Articles can't exceed 500")
    }

    url <-
      glue::glue("https://stats-prod.nba.com/wp-json/statscms/v1/type/beyondthenumber/?limit={count_articles}&offset=0") %>%
      as.character()

    data <-
      url %>%
      jsonlite::fromJSON(simplifyVector = T)
    url_article <- data$posts$meta %>% flatten_chr()

    df <-
      data$posts[1:5] %>% as_data_frame() %>%
      purrr::set_names(c("idArticle", "titleArticle", "datetimeArticle", "htmlContent", "urlImage")) %>%
      mutate(urlArticle = url_article,
             titleArticle = ifelse(titleArticle == "", NA, titleArticle),
             datetimeArticle = datetimeArticle %>% lubridate::ymd_hms()) %>%
      select(datetimeArticle, everything())

   df <-
     df %>%
      mutate(textArticle = htmlContent %>% map_chr(function(x) {
        x %>% read_html() %>% html_text() %>% str_trim()
      })) %>%
      dplyr::select(-htmlContent)

   closeAllConnections()

   df
  }

# daily video --------------------------------------------------------------
# http://api.nba.net/0/league/collection/47b76848-028b-4536-9c9c-37379d209639
