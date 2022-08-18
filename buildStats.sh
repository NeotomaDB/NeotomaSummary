#!/bin/bash

if [$2 = "local"]; then
    echo local
    export DBNAME=neotoma
    export HOST=localhost
    export PORT=5432
    export USER=postgres
    export PASSWORD=postgres
else
    export DBNAME=neotoma
    export HOST=db5.cei.psu.edu
    export PORT=5432
    export USER=sug335
    export PASSWORD=northCountry2020
    # Rscript -e "rmarkdown::render('StateoftheDB.Rmd')"
    git add --all
    git commit -m "Running the build"
    git push
fi
echo Done.