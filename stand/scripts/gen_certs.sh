#!/usr/bin/env bash
# =====================================================================
#  Генерація власного центру сертифікації (CA) і сертифіката сервера
#  для етапу 4. Запуск (з каталогу stand):
#
#     docker compose run --rm client bash /scripts/gen_certs.sh
#
#  Результат у ./certs:
#     ca/ca.key      — закритий ключ CA. У реальному житті зберігається офлайн!
#     ca.crt         — сертифікат CA (його отримують клієнти)
#     server.key     — закритий ключ сервера
#     server.crt     — сертифікат сервера, підписаний CA
#     client.key/.crt— (необов'язково) клієнтський сертифікат для clientcert=verify-full
# =====================================================================
set -euo pipefail
cd /certs
mkdir -p ca

DAYS_CA=730
DAYS_LEAF=365
SERVER_CN="db"
CLIENT_CN="${CLIENT_CN:-u_director}"

echo ">>> 1. Ключ і самопідписаний сертифікат CA"
openssl ecparam -name prime256v1 -genkey -noout -out ca/ca.key
openssl req -x509 -new -key ca/ca.key -sha256 -days "$DAYS_CA" \
    -subj "/C=UA/O=PR DB Security Lab/CN=PR Lab Root CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -out ca.crt

echo ">>> 2. Ключ і запит на сертифікат сервера"
openssl ecparam -name prime256v1 -genkey -noout -out server.key
openssl req -new -key server.key -subj "/C=UA/O=PR DB Security Lab/CN=${SERVER_CN}" -out server.csr

cat > server.ext <<EOF
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:db,DNS:restore,DNS:localhost,IP:127.0.0.1,IP:172.28.0.10,IP:172.28.0.11
EOF

echo ">>> 3. CA підписує сертифікат сервера"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca/ca.key -CAcreateserial \
    -days "$DAYS_LEAF" -sha256 -extfile server.ext -out server.crt

echo ">>> 4. (Необов'язково) клієнтський сертифікат для ${CLIENT_CN}"
openssl ecparam -name prime256v1 -genkey -noout -out client.key
openssl req -new -key client.key -subj "/CN=${CLIENT_CN}" -out client.csr
printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\n' > client.ext
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca/ca.key -CAcreateserial \
    -days "$DAYS_LEAF" -sha256 -extfile client.ext -out client.crt

rm -f server.csr server.ext client.csr client.ext
chmod 600 ca/ca.key server.key client.key

echo ">>> Перевірка ланцюжка:"
openssl verify -CAfile ca.crt server.crt client.crt
openssl x509 -in server.crt -noout -subject -issuer -dates -ext subjectAltName
