

# utilities ---------------------------------------------------------------

# define base url
# should likely become an environment variable to change RSPM instances
b_url <- "http://packagemanager.rstudio.com/__api__"

# utility function to replace NULLs with NA in a list
#' @keywords internal
remove_null <- function(x) {
  purrr::modify_if(x, is.null, ~NA)
}

# vector of install commands to be removed from install scripts to identify deps
install_commands <- "apt-get install -y |yum install -y |zypper install -y "

# First build with public package manager
# then provide method for substituting any RSPM URL
# note for OSS index Debian is as close to ubuntu as we can get and RPM is for redhat / centos


# API wrappers ------------------------------------------------------------
#' Get package repository information
#' Provides a tibble of all repositories on RSPM.
#' @export
get_repos <- function() {
  httr::GET(file.path(b_url, "repos")) %>%
    httr::content(as = "text") %>%
    jsonlite::fromJSON() %>%
    tibble::as_tibble()

}


#' Get all packages for a repository
#' @param repo_id The repository ID.
#' @export
# TODO add n_pages argument
# Figure out pagination for other repositories
get_repo_packages <- function(repo_id) {

  query_string <- file.path(b_url, "repos", repo_id, "packages")

  n_pages <- 21

  pb <- progress::progress_bar$new(total = n_pages)

  queries <- purrr::map_chr(1:n_pages,
                            ~httr::modify_url(query_string,
                                              query = list("_limit" = 1000,
                                                           "_page" = .x))) %>%

    purrr::map(~{
      pb$tick()
      r <- httr::GET(.x)
      httr::content(r, as = "text") %>%
        jsonlite::fromJSON()
    })

  tibble::as_tibble(dplyr::bind_rows(queries))
}




# Get package by name -----------------------------------------------------

#' Get package information by name
#'
#' Fetches package information from an RSPM repository for a package by name.
#'
#' @param package_name The name of the package.
#' @param repo_id The repository ID.

#' @export
get_package <- function(package_name, repo_id = 1) {
  query_url <- file.path(b_url, "repos", repo_id, "packages", package_name)


  res <- httr::GET(query_url) %>%
    httr::content(as = "text") %>%
    jsonlite::fromJSON() %>%
    purrr::modify_if(.p = is.null, ~NA)


  tibble::new_tibble(res[1:40], nrow = 1) %>%
    dplyr::mutate(downloads = purrr::pluck(res, "downloads", "count"),
           links = list(purrr::pluck(res, "links")),
           archived = list(purrr::pluck(res, "archived")),
           ash = purrr::pluck(res, "ash")
    )

}

#get_package("dplyr")


# Get package sys reqs ----------------------------------------------------
# TODO distribution and package version arguments
# TODO add has_sysreq field

#' Get system requirements for a single package
#'
#' @param package_name The name of the package.
#' @param distribution The linux distribution to check against. Possible values are `"ubuntu"`, `"centos"`, `"redhat"`, and `"opensuse"`.
#' @param repo_id The repository ID.
#'
#' @export
get_package_sysreqs <- function(package_name, distribution = "ubuntu", repo_id = 1) {

    query_url <- file.path(b_url, "repos", repo_id, "packages", package_name, "sysreqs") %>%
    httr::modify_url(query = list(all = TRUE, distribution = distribution))

  res <- httr::GET(query_url) %>%
    httr::stop_for_status() %>%
    httr::content(as = "text") %>%
    jsonlite::fromJSON() %>%
    remove_null()

  inst_scripts <- remove_null(purrr::pluck(res, "dependencies", "install_scripts", .default = ""))

  sys_reqs <- purrr::map(inst_scripts, ~stringr::str_remove(.x, install_commands))

  deps <- purrr::pluck(res, "dependencies",
                       .default = tibble::tibble(
                         import = character(0),
                         source_files = character(0),
                         install_scripts = character(0)
                       )) %>%
    dplyr::mutate(install_scripts = inst_scripts,
           system_reqs = sys_reqs) %>%
    dplyr::rename_with(~"import", matches("name"))


  tibble::tibble(name = purrr::pluck(res, "name"),
                 distribution = distribution,
                 has_sysreqs = ifelse(length(inst_scripts) == 1 && inst_scripts == "", FALSE, TRUE),
                 dependencies = list(deps)) %>%
    tibble::as_tibble()

}

# get_package_sysreqs("stringr")
# get_package_sysreqs("fs")



# Get repo sysreqs --------------------------------------------------------
# Fetching sysreqs for the entire repo will be the easiest plan of attack
# You can get them all out of the way prior to having to useRs ask for them :)

#' Get all system requirements for a repository
#' @param distribution The linux distribution to check against. Possible values are `"ubuntu"`, `"centos"`, `"redhat"`, and `"opensuse"`.
#' @param repo_id The repository ID.
#' @export
get_repo_sysreqs <- function(repo_id, distribution = "ubuntu") {
  query_url <- file.path(b_url, "repos", repo_id, "sysreqs")

  res <- httr::GET(
    httr::modify_url(query_url,
                     query = list(all = TRUE,
                                  distribution = distribution))) %>%
    httr::stop_for_status() %>%
    httr::content(as = "text") %>%
    jsonlite::fromJSON()


  tibble::tibble(
    name = purrr::pluck(res, "requirements", "name"),
    system_reqs = purrr::pluck(res, "requirements", "requirements", "packages"),
    install_scripts = remove_null(purrr::pluck(res, "requirements", "requirements", "install_scripts")),
    pre_install = remove_null(purrr::pluck(res, "requirements", "requirements", "pre_install")),
    post_install = remove_null(purrr::pluck(res, "requirements", "requirements", "post_install"))
  )

}

#get_repo_sysreqs(2) -> x


# Notes for RSPM team
# public package manager gives BioC ID of 3.
# the API EP for repos/3/packages results in 404
# _limit param, has a max value of 1000, change the documentation.
# should include a next page url as well as a record number so that the users knows to continue making requests
# what is the download count for each package? There are 100 values all 0 for all packages
# all values for the `repository` column are RSPM. I'm calling the `all` repo...
# says "Fetches a package by ID" when it should say "by name"
# is ash supposed to be "sha"?
# what are the possible values for "distribution"
# provided value "centos" but not able to do 7 or 8
# not rhel, but redhat,
# possible values=opensuse, centos, ubuntu, redhat
# /repos/{id}/sysreqs only returns 726 pkgs. It's missing packages that have deps. how do we decide which show up?


#
# # The source_id is always 1 even when providing repo_id of 2
# GET("http://packagemanager.rstudio.com/__api__/repos/2/packages?_limit=1000&_page=12") %>%
#   content(as = "text") %>%
#   jsonlite::fromJSON() %>%
#   as_tibble() %>%
#   glimpse()
#
#
