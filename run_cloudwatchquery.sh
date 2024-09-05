#!/bin/bash
## Aggregated call times
queryId=$(aws logs start-query \
    --log-group-name '/aws/elasticbeanstalk/Neotomaapi-env/var/log/nginx/access.log' \
    --start-time `date -d '-1 year' +"%s"` \
    --end-time `date +"%s"` \
    --query-string 'fields @message | parse @message "* - - [*] \"* * *\" * * *" as loggingIP, loggingTime, loggingVerb, loggingPath, loggingUse, loggingStatus, loggingSize | filter (loggingVerb = "GET" or loggingVerb = "POST") and loggingStatus = 200 | stats count(*) as calls, sum(loggingSize) as volume by strcontains(loggingPath, "dojo") as explorerCall, bin(1d) as date' | jq -r '.queryId')

echo "Query started (query id: $    --query-id $queryId), please hold ..." && sleep 300 # give it some time to query
aws logs get-query-results \
    --query-id $queryId \
    --output json > log_run.json

## Specific Calls:
queryId=$(aws logs start-query \
    --log-group-name '/aws/elasticbeanstalk/Neotomaapi-env/var/log/nginx/access.log' \
    --start-time `date -d '-1 year' +"%s"` \
    --end-time `date +"%s"` \
    --query-string 'fields @message | parse @message "* - - [*] \"* *?* *\" * * *" as loggingIP, loggingTime, loggingVerb, loggingPath, loggingQuery, loggingUse, loggingStatus, loggingSize | filter (loggingVerb = "GET" or loggingVerb = "POST") and loggingStatus = 200  | stats count(*) as calls by tolower(loggingPath) as path | sort by calls desc' | jq -r '.queryId')

echo "Query started (query id: $    --query-id $queryId), please hold ..." && sleep 300 # give it some time to query
aws logs get-query-results \
    --query-id $queryId \
    --output json > log_run_api_calls.json

## Tilia Daily Calls:
queryId=$(aws logs start-query \
    --log-group-name '/aws/elasticbeanstalk/Tiliaapiv2-env/var/log/nginx/access.log' \
    --start-time `date -d '-1 year' +"%s"` \
    --end-time `date +"%s"` \
    --query-string 'fields @message | parse @message "* - - [*] \"* *?* *\" * * *" as loggingIP, loggingTime, loggingVerb, loggingPath, loggingQuery, loggingUse, loggingStatus, loggingSize | filter (loggingVerb = "GET" or loggingVerb = "POST") and loggingStatus = 200  | stats count(*) as calls by datefloor(@timestamp, 1d) as date | sort by date desc' | jq -r '.queryId')

echo "Query started (query id: $    --query-id $queryId), please hold ..." && sleep 300 # give it some time to query
aws logs get-query-results \
    --query-id $queryId \
    --output json > log_run_tilia.json

## Tilia Steward Calls
queryId=$(aws logs start-query \
    --log-group-name '/aws/elasticbeanstalk/Tiliaapiv2-env/var/log/nginx/access.log' \
    --start-time `date -d '-1 year' +"%s"` \
    --end-time `date +"%s"` \
    --query-string 'fields @message | filter strcontains(@message, "validate") | parse @message "* - - [*] \"* *?*_username=%27*%27 *\" * * *" as loggingIP, loggingTime, loggingVerb, loggingPath, loggingQuery, loggingSteward, loggingUse, loggingStatus, loggingSize | filter (loggingVerb = "GET" or loggingVerb = "POST") and loggingStatus = 200 | stats count(*) as count by loggingSteward | sort by @timestamp desc' | jq -r '.queryId')

echo "Query started (query id: $    --query-id $queryId), please hold ..." && sleep 300 # give it some time to query
aws logs get-query-results \
    --query-id $queryId \
    --output json > log_run_tilia_steward.json
