#!/usr/bin/env bash

DATA="Requests per second"

files=$1

if [ "${files}" == "" ]; then
  files="./*.log"
fi

for file in ${files}
do
  echo "Results in ${file}:"
  grep -A10 "Concurrency Level" ${file} | grep -E "Concurrency|${DATA}" | awk '!x[$0]++'
done
