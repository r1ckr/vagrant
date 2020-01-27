#!/usr/bin/env bash

DATA="Requests/sec"

files=$1

if [ "${files}" == "" ]; then
  files="./results/*.log"
fi

for file in ${files}
do
  echo "Results in ${file}:"
  grep -A10 "Concurrency Level:" ${file} | grep -E "${DATA}" | awk -F ':' '{print $2}' | sed 's/[[:space:]]//g' | jq -R -s -c 'split("\n")' >  ${file}.json
  echo ""
done
