library(httr)
library(dplyr)
library(purrr)

# define base url
b_url <- "http://packagemanager.rstudio.com/__api__"


remove_null <- function(x) {
  purrr::modify_if(x, is.null, ~NA)
}

# First build with public package manager
# then provide method for substituting any RSPM URL
# note for OSS index Debian is as close to ubuntu as we can get and RPM is for redhat / centos

#' Get package repository information
#'
#' @export
get_repos <- function() {
  GET(file.path(b_url, "repos")) %>%
    content(as = "text") %>%
    jsonlite::fromJSON() %>%
    as_tibble()

}

#get_repos()
#' Get all packages for a repository
#' @export
# TODO add n_pages argument
get_repo_packages <- function(repo_id) {

  query_string <- file.path(b_url, "repos", repo_id, "packages")
  cat(query_string)
  n_pages <- 21

  pb <- progress::progress_bar$new(total = n_pages)

  queries <- purrr::map_chr(1:n_pages,
                            ~modify_url(query_string,
                                        query = list("_limit" = 1000,
                                                     "_page" = .x))) %>%
    #print() %>%
    purrr::map(~{
      pb$tick()
      r <- GET(.x)
      content(r, as = "text") %>%
        jsonlite::fromJSON()
    })

  as_tibble(bind_rows(queries))
}




# Get package by name -----------------------------------------------------
#' Get package information by name
#' @export
get_package <- function(package_name, repo_id = 1) {
  query_url <- file.path(b_url, "repos",
                         repo_id, "packages", package_name)


  res <- GET(query_url) %>%
    content(as = "text") %>%
    jsonlite::fromJSON() %>%
    purrr::modify_if(.p = is.null, ~NA)


  tibble::new_tibble(res[1:40], nrow = 1) %>%
    mutate(downloads = pluck(res, "downloads", "count"),
           links = list(pluck(res, "links")),
           archived = list(pluck(res, "archived")),
           ash = pluck(res, "ash")
    )

}

#get_package("dplyr")


# Get package sys reqs ----------------------------------------------------
# TODO distribution and package version arguments
#' Get system requirements for a single package
#' @export
get_package_sysreqs <- function(package_name, repo_id = 1, distribution = "ubuntu") {
  query_url <- file.path(b_url, "repos",
                         repo_id, "packages", package_name, "sysreqs")


  res <- GET(query_url) %>%
    stop_for_status() %>%
    content(as = "text") %>%
    jsonlite::fromJSON() %>%
    purrr::modify_if(.p = is.null, ~NA)

  deps <- pluck(res, "dependencies", .default = tibble())

  tibble(name = pluck(res, "name"),
         source_files = pluck(res, "source_file", .default = NA),
         has_sysreqs = ifelse(length(inst_scripts) == 1 && inst_scripts == "", FALSE, TRUE),
         dependencies = list(deps)) %>%
    as_tibble()
}

# get_package_sysreqs("stringr")
# get_package_sysreqs("fs")


# Get repo sysreqs --------------------------------------------------------
# Fetching sysreqs for the entire repo will be the easiest plan of attack
# You can get them all out of the way prior to having to useRs ask for them :)

#' Get all system requirements for a repository
#' @export
get_repo_sysreqs <- function(repo_id, distribution = "ubuntu") {
  query_url <- file.path(b_url, "repos", repo_id, "sysreqs")

  res <- GET(modify_url(query_url, query = list(all = TRUE, distribution = distribution))) %>%
    stop_for_status() %>%
    content(as = "text") %>%
    jsonlite::fromJSON()


  tibble(
    name = res$requirements$name,
    package_reqs = res$requirements$requirements$packages,
    install_scripts = remove_null(res$requirements$requirements$install_scripts),
    pre_install = remove_null(res$requirements$requirements$pre_install),
    post_install = remove_null(res$requirements$requirements$post_install)
  )

}

#get_repo_sysreqs(2) -> x


# Note for RSPM team
# public package manager gives BioC ID of 3.
# the API EP for repos/3/packages results in 404
# _limit param, has a max value of 1000, change the documentation.
# what is the download count for each package? There are 100 values all 0 for all packages
# all values for the `repository` column are RSPM. I'm calling the `all` repo...
# says "Fetches a package by ID" when it should say "by name"
# is ash supposed to be "sha"?
# what are the possible values for "distribution"
# provided value "centos" but not able to do 7 or 8
# not rhel, but redhat,
# possible values=opensuse, centos, ubuntu, redhat
# /repos/{id}/sysreqs only returns 726 pkgs. It's missing packages that have deps. how do we decide which show up?



# The source_id is always 1 even when providing repo_id of 2
# GET("http://packagemanager.rstudio.com/__api__/repos/2/packages?_limit=1000&_page=12") %>%
#   content(as = "text") %>%
#   jsonlite::fromJSON() %>%
#   as_tibble() %>%
#   glimpse()


