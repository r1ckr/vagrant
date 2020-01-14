# Kong Performance
This is a Vagrant machine to check what's the performance of Kong in Docker

The environment is an Ubuntu VM (2 cores * 4096 RAM) with Docker, in Docker we are running:
- Spring App that prints "Hello >Random Name<"
- Kong with Cassandra
- NGINX

The plan is to compare Kong and NGINX performance to see what's the overhead of Kong over NGINX

To start everything, please run the Vagrant box:

## Starting Vagrant
```bash
vagrant up
```

## Run the docker-compose file
```bash
vagrant ssh
cd /src
docker-compose up -d
```
This compose will run all the necessary apps

## Run the tests
```bash
./run-tests.sh
```

## Parse the results
```bash
./extract-results.sh
```
Then print only the data to plot:
```bash
./extract-results.sh | grep -v Concu | awk -F " " '{print $4}'
```

## Manual Docker commands
If you prefer to start manually each container, use the commands below

### Start the Spring App
```
docker run -d --name spring-hello \
-e SERVER_TOMCAT_ACCESSLOG_ENABLED=true \
-e JAVA_TOOL_OPTIONS="-Xmx512m" \
-p 7777:7777 \
r1ckr/http-hello
```
#### Test it
```
curl -i localhost:7777
```

### Run Kong
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
### Create the API
```
curl -i -X POST http://localhost:8001/apis/ \
  --data 'name=test-api' \
  --data 'uris=/test' \
  --data 'upstream_url=http://172.17.0.2:7777/'
```
#### Test the API
```
curl -i localhost:8000/test
```
### Delete the API when needed
```
curl -i -X DELETE http://localhost:8001/apis/test-api
```


### Start an NGINX pointing to the Spring App
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
#### Running NGINX
```
docker run -d --name nginx \
-p 9999:9999 \
-v /src/nginx.conf:/etc/nginx/nginx.conf:ro \
nginx:latest
```
#### Test it
curl -i localhost:9999




