#!/usr/bin/env bash

runPerformance(){
  parallelism=$1
  url=$2
  totalRequests=$((${parallelism}*100))
#  for i in {1..3}
#  do
    ab -n ${totalRequests} -c ${parallelism} ${url}
#  done
}

echo "Warming up App..."
ab -n 10000 -c 10 http://127.0.0.1:7777/

sleep 5

echo "######### Running App performance... ######### "
logFile="app.log"
appUrl="http://127.0.0.1:7777/"
date > ${logFile}
runPerformance 10 ${appUrl} >> ${logFile}
runPerformance 25 ${appUrl} >> ${logFile}
runPerformance 50 ${appUrl} >> ${logFile}
runPerformance 75 ${appUrl} >> ${logFile}
#runPerformance 100 ${appUrl} >> ${logFile}

sleep 5

echo "######### Running NGINX performance... ######### "
logFile="nginx.log"
appUrl="http://127.0.0.1:9999/"
date > ${logFile}
runPerformance 10 ${appUrl} >> ${logFile}
runPerformance 25 ${appUrl} >> ${logFile}
runPerformance 50 ${appUrl} >> ${logFile}
runPerformance 75 ${appUrl} >> ${logFile}
#runPerformance 100 ${appUrl} >> ${logFile}

sleep 5

echo "######### Running Kong performance... ######### "
logFile="kong.log"
appUrl="http://127.0.0.1:8000/test/"
date > ${logFile}
runPerformance 10 ${appUrl} >> ${logFile}
runPerformance 25 ${appUrl} >> ${logFile}
runPerformance 50 ${appUrl} >> ${logFile}
runPerformance 75 ${appUrl} >> ${logFile}
#runPerformance 100 ${appUrl} >> ${logFile}



