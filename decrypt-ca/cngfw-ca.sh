#!/bin/bash

source env.sh

mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

echo "Creating Private Key for CA"
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

echo "Creating Self-signed CA Certificate"
openssl req -config openssl.cnf -key private/ca.key.pem -new -x509 \
    -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem \
    -subj "/CN=$CA_NAME" 

openssl pkcs12 -export -out root-ca.pfx -inkey private/ca.key.pem -in certs/ca.cert.pem

az group create -l $VAULT_REGION -n $VAULT_RG

az keyvault create --location $VAULT_REGION --name $VAULT_NAME --resource-group $VAULT_RG

read -s -p "Enter pass phrase for root-ca.pfx: " PASSWORD

az keyvault certificate import --vault-name $VAULT_NAME -n $CA_NAME --file root-ca.pfx --password $PASSWORD

VAULT_MI_SPID=$(az identity create --name $VAULT_MI --resource-group $VAULT_RG --query principalId -o tsv)

az keyvault set-policy -n $VAULT_NAME --certificate-permissions get list -g $VAULT_RG --object-id $VAULT_MI_SPID -o none



