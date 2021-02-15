#' @title Identify potential duplicates based on title and year
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' Currently this only works for files that were generated while Citavi
#' was set to "English" so that column names are "Short Title" etc.
#'
#' @param CitDat A dataframe/tibble returned by \code{\link[CitaviR]{find_obvious_dups}}
#' or \code{\link[CitaviR]{handle_obvious_dups}}.
#' @param minSimilarity Minimum similarity (between 0 and 1). Default is 0.6. (TO DO)
#' @param potDupAfterObvDup If TRUE (default), the newly created column
#' \code{pot_dup_id} is moved right next to the \code{obv_dup_id} column.
#'
#' @return A tibble containing three one columns: \code{pot_dup_id}.
#' @importFrom RecordLinkage levenshteinSim
#' @importFrom scales percent
#' @importFrom stringr str_pad
#' @importFrom tidyr pivot_longer
#' @importFrom utils combn
#' @import dplyr
#' @export

find_potential_dups <- function(CitDat, minSimilarity = 0.6, potDupAfterObvDup = TRUE) {

  ct <- CitDat %>% filter(.data$obv_dup_id == "dup_01") %>% pull(.data$clean_title)
  ct_padding <- ct %>% n_distinct() %>% log(10) %>% ceiling() + 1


  # calculate similarity = Levenshtein distance -----------------------------
  similarities <- as.data.frame(t(combn(ct, 2))) %>% # get unique combinations of clean_titles
    mutate(similarity = RecordLinkage::levenshteinSim(str1 = .data$V1,
                                                      str2 = .data$V2))


  # create clean_title_similarity -------------------------------------------
  similarities <- similarities %>% # similarity per pair
    filter(.data$similarity >= minSimilarity) %>% # keep only those with a minimum similarity
    arrange(.data$similarity, .desc = TRUE) %>%
    group_by(.data$V1, .data$V2) %>%
      mutate(similarityRank = cur_group_id()) %>% # similarity rank
    ungroup() %>%
    mutate(pot_dup_id = paste0(
      "potdup_",
      stringr::str_pad(.data$similarityRank, ct_padding, pad = "0"),
      " ",
      scales::percent(.data$similarity, accuracy = 0.1),
      " similarity"
    )) %>%
    select(-.data$similarity, -.data$similarityRank) %>%
    pivot_longer(cols = .data$V1:.data$V2,
                 values_to = "clean_title",
                 names_to = NULL)


  # join with CitDat --------------------------------------------------------
  CitDat <- left_join(x = CitDat, y = similarities, by = "clean_title") %>%
    mutate(pot_dup_id = if_else(.data$obv_dup_id != "dup_01", NA_character_, .data$pot_dup_id))


  # potDupAfterObvDup -------------------------------------------------------
  if (potDupAfterObvDup) {
    CitDat <- CitDat %>%
      relocate("pot_dup_id", .after = "obv_dup_id")
  }


  # return tibble -----------------------------------------------------------
  CitDat
}