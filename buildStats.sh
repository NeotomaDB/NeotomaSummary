#!/bin/bash
export DBNAME=neotoma
export HOST=localhost
export PORT=5432
export USER=postgres    
export PASSWORD=postgres
Rscript -e "rmarkdown::render('outputs/StateoftheDB.Rmd')"
Rscript neotomaplots.R
