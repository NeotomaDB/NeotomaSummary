#!/bin/bash
export DBNAME=neotoma
export HOST=db5.cei.psu.edu
export PORT=5432
export USER=sug335
export PASSWORD=northCountry2020
Rscript -e "rmarkdown::render('StateoftheDB.Rmd')"
Rscript neotomaplots.R
git add --all
git commit -m "Running the build"
git push