#!/bin/bash
Rscript -e "rmarkdown::render('StateoftheDB.Rmd')"
Rscript neotomaplots.R
