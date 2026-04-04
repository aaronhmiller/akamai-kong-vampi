# akamai-kong-vampi
An Akamai API Security demo using Kong and Vampi

## Overview
* On an EC2 box, setup Docker
* From Akamai console, download the Kong plugin configuration
* Build the image
* Run `docker compose up -d`
* Setup the Kong Service and Route and enable the NN Plugin
* Use `vampi_traffic.sh` to generate traffic

## Details for above
* build command example:
  ```docker build \
  --build-arg NONAME_VERSION=1.2.3 \
  -t your-registry/kong-akamai:3.9.1 \
  .
  ```
* adding service example:
```
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "passthru-5000",
    "url": "http://host.docker.internal:5000"
  }'
```
* adding route example:
```
curl -s -X POST http://localhost:8001/services/passthru-5000/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "passthru-5000-route",
    "paths": ["/"],
    "strip_path": false,
    "preserve_host": true
  }'
```
* associate the plugin with the service example:
```
  curl -X POST --url http://<kong-domain>:<kong-port>/services/<your-kong service-id>/plugins/ \
--data "name=nonamesecurity"
```
