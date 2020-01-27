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

## Run the graph:
Back in the host machine, run the node app to see the graph:
```bash
node server.js
```

## Manual Docker commands
If you prefer to start manually each container, use the commands below

### Start the Hello App
```
docker run -d --name hello \
-p 7777:7777 \
r1ckr/http-hello
```
#### Test it
```
curl -i localhost:7777
```

### Run Kong
```bash
# Kong instance
docker run -d --name kong \
    --restart always \
    -e "KONG_DATABASE=off" \
    -e "KONG_LOG_LEVEL=info" \
    -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
    -e "KONG_DECLARATIVE_CONFIG=/etc/kong/kong.yml" \
    -v $(pwd)/kong.yml:/etc/kong/kong.yml:ro \
    -p 8000:8000 \
    -p 8443:8443 \
    -p 8001:8001 \
    -p 8444:8444 \
    -p 7946:7946 \
    -p 7946:7946/udp \
    kong:latest
```
#### Test the API
```
curl -i localhost:8000/test
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




