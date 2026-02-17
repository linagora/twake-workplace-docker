#!/bin/bash
set -e

. ../.env

DOMAIN="*.${BASE_DOMAIN}"

echo "▶ Generating CA"
openssl genrsa -out traefik/ssl/root-ca.key 4096
openssl req -x509 -new -nodes \
  -key traefik/ssl/root-ca.key \
  -sha256 -days 3650 \
  -out traefik/ssl/root-ca.pem \
  -subj "/C=TN/O=Twake/OU=RootCA/CN=Twake Root CA"

echo "▶ Generating server cert for ${DOMAIN}"
openssl genrsa -out traefik/ssl/twake-server.key 2048
openssl req -new \
  -key traefik/ssl/twake-server.key \
  -out traefik/ssl/twake-server.csr \
  -subj "/C=TN/O=Twake/OU=Server/CN=${DOMAIN}"

openssl x509 -req \
  -in traefik/ssl/twake-server.csr \
  -CA traefik/ssl/root-ca.pem \
  -CAkey traefik/ssl/root-ca.key \
  -CAcreateserial \
  -out traefik/ssl/twake-server.pem \
  -days 825 \
  -sha256 \
  -extfile <(printf "subjectAltName=DNS:${DOMAIN}\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")

echo "▶ Generating fullchain"
cat traefik/ssl/twake-server.pem traefik/ssl/root-ca.pem > traefik/ssl/twake-server-fullchain.pem  
cp traefik/ssl/root-ca.pem traefik/ssl/root-ca.crt
