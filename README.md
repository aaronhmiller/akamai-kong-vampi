# akamai-kong-vampi
An Akamai API Security demo using Kong and Vampi

## Overview
* On an EC2 box, setup Docker
* Fire up Vampi `docker run --name vampi -d -p 5000:5000 erev0s/vampi:latest`
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
Adding in MCP!
```
QUERY / CONTROL PLANE  (read-only, on demand)
        ┌──────────────────────────────────────────────────────────────────────┐
        │                                                                      │
        ▼                                                                      │
┌───────────────┐                                                              │
│  Claude Code  │  MCP client (local)                                          │
│  MCP Client   │  ~/.claude.json  →  server "noname"                          │
│  (your laptop)│                                                              │
└───────┬───────┘                                                              │
        │  HTTPS  (streamable HTTP transport)                                  │
        │  GET https://mcp.akamai.com/mcp?token=<MCP Token>                    │
        │  tools: get_apis · get_incidents · get_findings · get_attackers      │
        ▼                                                                      │
┌────────────────────┐                                                         │
│  Akamai MCP Server │  hosted by Akamai                                       │
│  mcp.akamai.com    │  (token auth → maps to your product/tenant)             │
└─────────┬──────────┘                                                         │
          │  internal API calls                                                │
          ▼                                                                    │
┌──────────────────────────────────────────────────┐                           │
│        Noname / Akamai API Security Platform     │ ◄─────────────────────────┘
│  ┌──────────┐  ┌───────────┐  ┌──────────┐       │   answers your queries
│  │   APIs   │  │ Incidents │  │ Findings │  ...  │   from accumulated data
│  │ inventory│  │           │  │ attackers│       │
│  └──────────┘  └───────────┘  └──────────┘       │
│        ▲  analysis / detection / inventory       │
└────────┼─────────────────────────────────────────┘
         │  traffic mirrored / posted by the plugin
         │  (out-of-band — not in the request path)
         │
═════════╪══════════════════ EC2 instance ════════════════════════════════════
         │                                                                      
         │   ┌──────────────────────────────────────────────────────────┐      
         │   │                   Docker host (EC2)                      │      
         │   │                                                          │      
         │   │   ┌─────────────────────────┐      ┌──────────────────┐  │      
   ──────┘   │   │   Kong Gateway          │      │   VAmPI          │  │      
             │   │  ┌───────────────────┐  │      │  (Flask app in   │  │      
   client    │   │  │ Noname NN Plugin  │  │      │   a container)   │  │      
   traffic ──┼──►│  │  (taps traffic,   │──┼─────►│                  │  │      
   :8000     │   │  │   forwards async) │  │ proxy│  /users  /books  │  │      
             │   │  └───────────────────┘  │ pass │  /createdb  ...  │  │      
             │   │   Admin API :8001       │      │                  │  │      
             │   └─────────────────────────┘      └──────────────────┘  │      
             │            container                    container        │      
             │   └──────────────────────────────────────────────────────┘      
═══════════════════════════════════════════════════════════════════════════════

         ──►  DATA / OBSERVATION PLANE  (continuous, left-to-right)
```
