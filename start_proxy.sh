#!/bin/sh

envsubst < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf
nginx -g 'daemon off;' -c /nginx.conf