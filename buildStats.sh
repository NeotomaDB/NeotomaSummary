#!/bin/bash

if [ "$1" == "local" ]; then
    echo Running against the local DB.
    export DBNAME=neotoma
    export HOST=localhost
    export PORT=5435
    export USER=postgres
    export PASSWORD=postgres
    Rscript -e "rmarkdown::render('StateoftheDB.Rmd')"
else
    echo Running against the remote.
    export DBNAME=neotoma
    export HOST=localhost
    export PORT=5555
    export USER=neotomaAdmin
    export PASSWORD=ndbgeopoliticalunits
    Rscript -e "rmarkdown::render('StateoftheDB.Rmd')"
    git add --all
    git commit -m "Running the build"
    git push
fi
echo Done.