#!/bin/bash

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

# Refresh the CloudWatch-derived data. These need AWS creds in the environment (us-east-2).
#   run_cloudwatchquery_partial.sh -> log_run_all.json (App Runner metrics: daily totals, full history)
#   run_cloudwatchquery.sh         -> log_run.json, log_run_calls.json (App Runner JSON logs: rich, since 2026-07-16)
bash run_cloudwatchquery_partial.sh
bash run_cloudwatchquery.sh

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
