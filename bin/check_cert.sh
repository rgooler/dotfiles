#!/bin/bash

private_key=$1
certificate=$2
cert_bundle=$3

echo "Verifying Certificate Chain... "
openssl verify -CAfile $cert_bundle $certificate

echo "Verifying key/cert match..."

md5_crt=$(openssl x509 -noout -modulus -in ${certificate} | openssl md5)
md5_key=$(openssl rsa  -noout -modulus -in ${private_key} | openssl md5)


if [ $md5_crt -eq $md5_key ] ; then
    echo "Certs match!"
else
    echo ""
    echo CRT: $verifycrt
    echo KEY: $verifykey
    echo ""
fi
