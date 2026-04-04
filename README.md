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
