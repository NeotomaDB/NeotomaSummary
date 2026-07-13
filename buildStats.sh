#!/bin/bash

# Need to run after I fix api_nodetest to send the logs to cloudwatch
# bash run_cloudwatchquery.sh
#bash run cloudwatchquery_partial.sh

# Load the database connection variables (DBNAME, HOST, PORT, USER, PASSWORD)
# from the .env file rather than hardcoding them here.
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "No .env file found. Copy .env-template to .env and set your values." >&2
    exit 1
fi

if [ "$1" == "local" ]; then
    echo "Running against the local DB ($USER@$HOST:$PORT/$DBNAME)."
    Rscript -e "rmarkdown::render('StateoftheDB.Rmd')"
else
    echo "Running against the remote ($USER@$HOST:$PORT/$DBNAME)."
    Rscript -e "rmarkdown::render('StateoftheDB.Rmd')"
    git add --all
    git commit -m "Running the build"
    git push
fi
echo Done.
