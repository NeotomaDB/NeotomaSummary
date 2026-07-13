#!/bin/bash
## API calls per day, per service (Neotoma API prod and Tilia prod).
## The API moved to App Runner, which does not emit the nginx access logs the
## other queries parse, so this uses the AWS/AppRunner "Requests" metric (total)
## and "2xxStatusResponses" (successful calls, comparable to the old status=200
## filter) instead.

start=`date -u -v-1y +"%Y-%m-%dT%H:%M:%SZ"`
end=`date -u +"%Y-%m-%dT%H:%M:%SZ"`

points='[]'
for svc in neoapi-prod neoapi-tprod; do
    svcId=$(aws apprunner list-services \
        --query "ServiceSummaryList[?ServiceName=='$svc'].ServiceId" --output text)
    req=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/AppRunner \
        --metric-name Requests \
        --dimensions Name=ServiceName,Value=$svc Name=ServiceID,Value=$svcId \
        --start-time $start --end-time $end --period 86400 --statistics Sum \
        --query 'Datapoints[].{date:Timestamp, calls:Sum}' --output json)
    ok=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/AppRunner \
        --metric-name 2xxStatusResponses \
        --dimensions Name=ServiceName,Value=$svc Name=ServiceID,Value=$svcId \
        --start-time $start --end-time $end --period 86400 --statistics Sum \
        --query 'Datapoints[].{date:Timestamp, calls_2xx:Sum}' --output json)
    svcpoints=$(jq -s --arg svc "$svc" '(.[0] + .[1]) | map(. + {service: $svc})' \
        <(printf '%s' "$req") <(printf '%s' "$ok"))
    points=$(jq -s '.[0] + .[1]' <(printf '%s' "$points") <(printf '%s' "$svcpoints"))
done

## One row per day and service, written in the same format as the other
## log_run*.json files (fields: date, calls, calls_2xx, service).
printf '%s' "$points" | jq '
  group_by([.date[0:10], .service])
  | map({date:      .[0].date[0:10],
         service:   .[0].service,
         calls:     (map(.calls // 0)     | add | floor),
         calls_2xx: (map(.calls_2xx // 0) | add | floor)})
  | sort_by([.date, .service])
  | {results: map([{field: "date",      value: .date},
                   {field: "calls",     value: (.calls | tostring)},
                   {field: "calls_2xx", value: (.calls_2xx | tostring)},
                   {field: "service",   value: .service}]),
     status: "Complete"}' > log_run_all.json
