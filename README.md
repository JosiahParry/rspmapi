
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rspmapi

<!-- badges: start -->
<!-- badges: end -->

## Installation

You can install the development version from
[GitHub](https://github.com/) with:

``` r
# install.packages("remotes")
remotes::install_github("JosiahParry/rspmapi")
```

## Example

List all repositories.

``` r
library(rspmapi)
library(tidyverse)

get_repos()
#> # A tibble: 3 x 5
#>      id name     created          description                            type   
#>   <int> <chr>    <chr>            <chr>                                  <chr>  
#> 1     1 all      2020-04-23T12:0… This repository contains packages fro… R      
#> 2     3 biocond… 2020-11-30T18:5… <NA>                                   Biocon…
#> 3     2 cran     2020-04-23T12:0… <NA>                                   R
```

List system dependencies for a package.

``` r
get_package_sysreqs("stringr") 
#> # A tibble: 1 x 3
#>   name    source_files                                           dependencies   
#>   <chr>   <chr>                                                  <list>         
#> 1 stringr https://packagemanager.rstudio.com/__api__/packages/9… <df[,3] [3 × 3…
```

Get system requirements for the entire repository.

``` r
(repo_sysreqs <- get_repo_sysreqs(1))
#> # A tibble: 726 x 5
#>    name               package_reqs install_scripts pre_install post_install    
#>    <chr>              <list>       <list>          <list>      <list>          
#>  1 rkafka             <chr [1]>    <chr [1]>       <lgl [1]>   <df[,1] [1 × 1]>
#>  2 rriskDistributions <chr [4]>    <chr [4]>       <lgl [1]>   <lgl [1]>       
#>  3 bdpopt             <chr [1]>    <chr [1]>       <lgl [1]>   <lgl [1]>       
#>  4 RWebLogo           <chr [1]>    <chr [1]>       <lgl [1]>   <lgl [1]>       
#>  5 gdata              <chr [1]>    <chr [1]>       <lgl [1]>   <lgl [1]>       
#>  6 mailR              <chr [1]>    <chr [1]>       <lgl [1]>   <df[,1] [1 × 1]>
#>  7 DeducerText        <chr [1]>    <chr [1]>       <lgl [1]>   <df[,1] [1 × 1]>
#>  8 gbp                <chr [1]>    <chr [1]>       <lgl [1]>   <lgl [1]>       
#>  9 prevalence         <chr [1]>    <chr [1]>       <lgl [1]>   <lgl [1]>       
#> 10 dataframes2xls     <chr [1]>    <chr [1]>       <lgl [1]>   <lgl [1]>       
#> # … with 716 more rows
```

Get the install scripts for your Linux distribution

``` r
repo_sysreqs %>% 
  slice(1:3) %>% 
  pull(install_scripts)
#> [[1]]
#> [1] "apt-get install -y default-jdk"
#> 
#> [[2]]
#> [1] "apt-get install -y tcl"      "apt-get install -y tk"      
#> [3] "apt-get install -y tk-dev"   "apt-get install -y tk-table"
#> 
#> [[3]]
#> [1] "apt-get install -y jags"
```
