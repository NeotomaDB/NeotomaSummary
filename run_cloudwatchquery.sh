#!/bin/bash
## Neotoma API call stats, now from the App Runner JSON access logs.
##
## Where the numbers come from, and since when:
##   Nov 2025 -> 2026-07-16: the API was on App Runner but wrote its access logs to a file on
##   disk, so they never made it to CloudWatch. For that stretch the call counts come from the
##   App Runner metrics instead (see run_cloudwatchquery_partial.sh -> log_run_all.json), which
##   only give daily totals -- no per-endpoint, volume or explorer split.
##   2026-07-16 onward: the API logs one JSON line per request to stdout, App Runner ships that
##   to CloudWatch, and the queries below read the real logs. This data grows day by day.
##
## Each request is a JSON object (type,time,ip,method,path,status,bytes,ms,ua) and Logs Insights
## parses it for us, so we filter/aggregate on the fields directly instead of the old nginx parse.
## Health checks are already dropped at the source.

set -euo pipefail

REGION=us-east-2

## App Runner puts a service id in the log group path and makes a new one if the service is
## recreated, so find the current "application" group by most recent activity, don't hardcode it.
active_log_group() {  # $1 = service name
  local best="" best_ts=0 ts
  for lg in $(aws logs describe-log-groups --region "$REGION" \
        --log-group-name-prefix "/aws/apprunner/$1/" \
        --query "logGroups[?ends_with(logGroupName,'/application')].logGroupName" --output text); do
    ts=$(aws logs describe-log-streams --region "$REGION" --log-group-name "$lg" \
          --order-by LastEventTime --descending --max-items 1 \
          --query 'logStreams[0].lastEventTimestamp' --output text 2>/dev/null | head -1)
    if [ "$ts" != "None" ] && [ -n "$ts" ] && [ "$ts" -gt "$best_ts" ]; then
      best_ts=$ts; best=$lg
    fi
  done
  printf '%s' "$best"
}

## start the query, wait for it, save the results as-is (beats the old fixed sleep 300).
run_insights() {  # $1 = log group, $2 = query string, $3 = output file
  local qid status
  qid=$(aws logs start-query --region "$REGION" \
      --log-group-name "$1" \
      --start-time "$(date -u -v-1y +%s)" \
      --end-time "$(date -u +%s)" \
      --query-string "$2" \
      --query 'queryId' --output text)
  echo "Query started (id: $qid) -> $3, please hold ..."
  while :; do
    status=$(aws logs get-query-results --region "$REGION" --query-id "$qid" --query 'status' --output text)
    [ "$status" != "Running" ] && [ "$status" != "Scheduled" ] && break
    sleep 3
  done
  aws logs get-query-results --region "$REGION" --query-id "$qid" --output json > "$3"
  echo "  done ($status)"
}

PROD_LG="$(active_log_group neoapi-prod)"
if [ -z "$PROD_LG" ]; then
  echo "ERROR: no active neoapi-prod application log group found in $REGION" >&2
  exit 1
fi
echo "neoapi-prod log group: $PROD_LG"

## Aggregated call times: daily calls + volume, split by explorer vs core.
## Same idea as before -- 2xx GET/POST only, explorer = path contains "dojo".
run_insights "$PROD_LG" \
  'filter type = "access" and status >= 200 and status < 300 and (method = "GET" or method = "POST")
   | stats count(*) as calls, sum(bytes) as volume by strcontains(path, "dojo") as explorerCall, bin(1d) as date' \
  log_run.json

## Specific calls: counts per endpoint. path is the full url (query string and all) -- Logs
## Insights won't let us alias a computed group back to "path", so we keep it whole here and the
## report strips the query string / trailing ids / case on its side (same as it already does).
run_insights "$PROD_LG" \
  'filter type = "access" and status >= 200 and status < 300
   | stats count(*) as calls by path
   | sort calls desc' \
  log_run_calls.json

echo "Wrote log_run.json and log_run_calls.json"

## Tilia is still on the old setup -- its logs go to a file, not CloudWatch, so these can't run
## yet. Keeping them here as a reminder: once the Tilia API logs JSON to stdout like neoapi does,
## point these at its App Runner "application" group (active_log_group neoapi-tprod) and switch
## the parse over to the JSON fields, same as above.
##
## Tilia Daily Calls -> log_run_tilia.json (date, calls)
# queryId=$(aws logs start-query \
#     --log-group-name '/aws/elasticbeanstalk/Tiliaapiv2-env/var/log/nginx/access.log' \
#     --start-time `date -d '-1 year' +"%s"` \
#     --end-time `date +"%s"` \
#     --query-string 'fields @message | parse @message "* - - [*] \"* *?* *\" * * *" as loggingIP, loggingTime, loggingVerb, loggingPath, loggingQuery, loggingUse, loggingStatus, loggingSize | filter (loggingVerb = "GET" or loggingVerb = "POST") and loggingStatus = 200  | stats count(*) as calls by datefloor(@timestamp, 1d) as date | sort by date desc' | jq -r '.queryId')
# echo "Query started (query id: $queryId), please hold ..." && sleep 300
# aws logs get-query-results --query-id $queryId --output json > log_run_tilia.json
##
## Tilia Steward Calls -> log_run_tilia_steward.json (loggingSteward, count)
# queryId=$(aws logs start-query \
#     --log-group-name '/aws/elasticbeanstalk/Tiliaapiv2-env/var/log/nginx/access.log' \
#     --start-time `date -d '-1 year' +"%s"` \
#     --end-time `date +"%s"` \
#     --query-string 'fields @message | filter strcontains(@message, "validate") | parse @message "* - - [*] \"* *?*_username=%27*%27 *\" * * *" as loggingIP, loggingTime, loggingVerb, loggingPath, loggingQuery, loggingSteward, loggingUse, loggingStatus, loggingSize | filter (loggingVerb = "GET" or loggingVerb = "POST") and loggingStatus = 200 | stats count(*) as count by loggingSteward | sort by @timestamp desc' | jq -r '.queryId')
# echo "Query started (query id: $queryId), please hold ..." && sleep 300
# aws logs get-query-results --query-id $queryId --output json > log_run_tilia_steward.json
