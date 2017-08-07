The environment is an Ubuntu VM (2 cores * 4096 RAM) with Docker, in Docker we are running:
Spring App where we are redirecting: https://github.com/r1ckr/http-hello
Kong to run the perf tests
Bare NGINX to compare with Kong

## Start the Spring App:
```
docker run -d --name spring-hello \
-e SERVER_TOMCAT_ACCESSLOG_ENABLED=true \
-e JAVA_TOOL_OPTIONS="-Xmx512m" \
-p 7777:7777 \
r1ckr/http-hello
```
### Test it:
```
curl -i localhost:7777
```

## Run Kong:
```bash
# Kong Database
docker run -d --name kong-database \
    --restart always \
    -p 9042:9042 \
    cassandra:3

# Kong instance
docker run -d --name kong \
    --link kong-database:kong-database \
    --restart always \
    -e "KONG_DATABASE=cassandra" \
    -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
    -p 8000:8000 \
    -p 8443:8443 \
    -p 8001:8001 \
    -p 8444:8444 \
    -p 7946:7946 \
    -p 7946:7946/udp \
    kong:latest
```
## Create the API:
```
curl -i -X POST http://localhost:8001/apis/ \
  --data 'name=test-api' \
  --data 'uris=/test' \
  --data 'upstream_url=http://172.17.0.2:7777/'
```
### Test the API:
```
curl -i localhost:8000/test
```
## Delete the API when needed:
```
curl -i -X DELETE http://localhost:8001/apis/test-api
```


## Start an NGINX pointing to the Spring App:
Create the nginx configuration: 
vi ./nginx.conf
```
worker_processes auto;
worker_cpu_affinity auto;

events {
  worker_connections  4096;  ## Default: 1024
}
http {
    upstream myapp1 {
        server 172.17.0.2:7777;
    }

    server {
        listen 9999;

        location / {
            proxy_pass http://myapp1;
        }
    }
}
```
### Running NGINX
```
docker run -d --name nginx \
-p 9999:9999 \
-v /src/nginx.conf:/etc/nginx/nginx.conf:ro \
nginx:latest
```
### Test it:
curl -i localhost:9999


# Start the performance tests:
Install Apache Benchmark(AB):
```
sudo apt install apache2-utils
```

## AB directly to the Spring App:
```
ab -n 100 -c 10 \
  http://127.0.0.1:7777/
```
...
### Concurrency Level:      10
Time taken for tests:   1.406 seconds
Time per request:       14.060 [ms] (mean)
Time per request:       1.406 [ms] (mean, across all concurrent requests)
Transfer rate:          95.15 [Kbytes/sec] received
### Concurrency Level:      100
Time taken for tests:   0.884 seconds
Time per request:       88.391 [ms] (mean)
Time per request:       0.884 [ms] (mean, across all concurrent requests)
Transfer rate:          151.36 [Kbytes/sec] received
##Concurrency Level:      100
Time taken for tests:   1.521 seconds
Time per request:       152.101 [ms] (mean)
Time per request:       1.521 [ms] (mean, across all concurrent requests)
Transfer rate:          92.70 [Kbytes/sec] received

## AB through Kong:
```
ab -n 1000 -c 100 \
  http://127.0.0.1:8000/test
```
...
### Concurrency Level:      10
Time taken for tests:   1.941 seconds
Time per request:       19.409 [ms] (mean)
Time per request:       1.941 [ms] (mean, across all concurrent requests)
Transfer rate:          104.95 [Kbytes/sec] received
### Concurrency Level:      100
Time taken for tests:   1.320 seconds
Time per request:       131.970 [ms] (mean)
Time per request:       1.320 [ms] (mean, across all concurrent requests)
Transfer rate:          154.86 [Kbytes/sec] received
### Concurrency Level:      100
Time taken for tests:   1.815 seconds
Time per request:       181.476 [ms] (mean)
Time per request:       1.815 [ms] (mean, across all concurrent requests)
Transfer rate:          116.56 [Kbytes/sec] received

## AB through NGINX:
```
ab -n 1000 -c 10 \
  http://127.0.0.1:9999/
```
...
### Concurrency Level:      10
Time taken for tests:   2.375 seconds
Time per request:       23.755 [ms] (mean)
Time per request:       2.375 [ms] (mean, across all concurrent requests)
Transfer rate:          102.36 [Kbytes/sec] received
### Concurrency Level:      100
Time taken for tests:   2.102 seconds
Time per request:       210.212 [ms] (mean)
Time per request:       2.102 [ms] (mean, across all concurrent requests)
Transfer rate:          115.68 [Kbytes/sec] received


### Concurrency Level:      100
Time taken for tests:   1.743 seconds
Time per request:       174.262 [ms] (mean)
Time per request:       1.743 [ms] (mean, across all concurrent requests)
Transfer rate:          93.27 [Kbytes/sec] received


for i in {1..3}; do ab -n 100 -c 10 http://127.0.0.1:7777/ | grep "per second"; done


Requests per Second:
Native
10-100      = (1195.77+1440.49+1558.17)/3      = 1398.1
50-500      = (2358.40+2212.28+1929.91)/3      = 2166.9
100-1000    = (2433.18+2309.26+2281.44)/3      = 2341.3
500-5000    = (2021.37+1524.19+1815.70)/3      = 1787.1

for i in {1..3}; do ab -n 100 -c 10 http://127.0.0.1:9999/ | grep "per second"; done

NGINX
10-100      = (909.46+1242+1300)/3    = 1150.5
50-500      = (1111.69+1132.66+1069.60)/3    = 1104.7
100-1000    = (1160.83+1222.43+1252.12)/3    = 1211.8
500-5000    = (1117.12+679.99+698.38)/3      = 831.8


ab -n 100 -c 10 http://127.0.0.1:8000/test
for i in {1..3}; do ab -n 100 -c 10 http://127.0.0.1:8000/test | grep "per second"; done
Kong
10-100      = (1265.17+1208.88+1068.01)/3   = 1180.7
50-500      = (1620.48+1763.56+1505.68)/3   = 1629.9
100-1000    = (1812.88+1765.75+1971.85)/3   = 1850.2
500-5000    = (1525.77+1262.47+1212.01)/3   = 1333.4



