#!/usr/bin/env bash

heyInvoke(){
  parallelism=$1
  url=$2
  totalRequests=$((${parallelism}*100))
  echo "Concurrency Level: ${parallelism}"
  hey -n ${totalRequests} -c ${parallelism} ${url}

}

waitToCoolDown(){
  sleepTimeSeconds=5
  echo "Sleeping for ${sleepTimeSeconds} seconds to cool down..."
  sleep ${sleepTimeSeconds}
}

runPerformance(){
  logFile=$1
  appUrl=$2
  date > ${logFile}
  heyInvoke 10 ${appUrl} >> ${logFile}
  heyInvoke 50 ${appUrl} >> ${logFile}
  heyInvoke 100 ${appUrl} >> ${logFile}
  heyInvoke 200 ${appUrl} >> ${logFile}
  heyInvoke 300 ${appUrl} >> ${logFile}
  heyInvoke 400 ${appUrl} >> ${logFile}
  heyInvoke 500 ${appUrl} >> ${logFile}
}

mkdir -p results
echo "######### Running App performance... ######### "
runPerformance "results/app.log" "http://127.0.0.1:7777/"
waitToCoolDown

echo "######### Running NGINX performance... ######### "
runPerformance "results/nginx.log" "http://127.0.0.1:9999/"
waitToCoolDown

echo "######### Running Kong performance... ######### "
runPerformance "results/kong.log" "http://127.0.0.1:8000/test/"
waitToCoolDown

echo "######### Running Express GW performance... ######### "
runPerformance "results/express-gateway.log" "http://127.0.0.1:8888/"



