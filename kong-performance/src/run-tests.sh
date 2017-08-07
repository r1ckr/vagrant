#!/usr/bin/env bash

runPerformance(){
  parallelism=$1
  url=$2
  totalRequests=$((${parallelism}*10))
#  for i in {1..3}
#  do
    ab -n ${totalRequests} -c ${parallelism} ${url}
#  done
}

waitToCoolDown(){
  sleepTimeSeconds=10
  echo "Sleeping for ${sleepTimeSeconds} seconds to cool down..."
  sleep ${sleepTimeSeconds}
}

echo "######### Running App performance... ######### "
logFile="app.log"
appUrl="http://127.0.0.1:7777/"
date > ${logFile}
runPerformance 1 ${appUrl} >> ${logFile}
runPerformance 5 ${appUrl} >> ${logFile}
runPerformance 10 ${appUrl} >> ${logFile}
runPerformance 20 ${appUrl} >> ${logFile}
runPerformance 30 ${appUrl} >> ${logFile}
runPerformance 40 ${appUrl} >> ${logFile}
runPerformance 50 ${appUrl} >> ${logFile}

waitToCoolDown

echo "######### Running NGINX performance... ######### "
logFile="nginx.log"
appUrl="http://127.0.0.1:9999/"
date > ${logFile}
runPerformance 1 ${appUrl} >> ${logFile}
runPerformance 5 ${appUrl} >> ${logFile}
runPerformance 10 ${appUrl} >> ${logFile}
runPerformance 20 ${appUrl} >> ${logFile}
runPerformance 30 ${appUrl} >> ${logFile}
runPerformance 40 ${appUrl} >> ${logFile}
runPerformance 50 ${appUrl} >> ${logFile}

waitToCoolDown

echo "######### Running Kong performance... ######### "
logFile="kong.log"
appUrl="http://127.0.0.1:8000/test/"
date > ${logFile}
runPerformance 1 ${appUrl} >> ${logFile}
runPerformance 5 ${appUrl} >> ${logFile}
runPerformance 10 ${appUrl} >> ${logFile}
runPerformance 20 ${appUrl} >> ${logFile}
runPerformance 30 ${appUrl} >> ${logFile}
runPerformance 40 ${appUrl} >> ${logFile}
runPerformance 50 ${appUrl} >> ${logFile}



