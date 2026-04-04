FROM kong:3.9.1

# Build args let you pass the plugin version at build time,
# e.g. docker build --build-arg NONAME_VERSION=1.2.3 .
ARG NONAME_VERSION=3.2.7-1

USER root

COPY ./kong-plugin-nonamesecurity-${NONAME_VERSION}.all.rock \
     kong-plugin-nonamesecurity-${NONAME_VERSION}.all.rock

RUN luarocks install kong-plugin-nonamesecurity-${NONAME_VERSION}.all.rock

# Tell Kong to load the custom plugin
ENV KONG_PLUGINS=bundled,nonamesecurity

USER kong
