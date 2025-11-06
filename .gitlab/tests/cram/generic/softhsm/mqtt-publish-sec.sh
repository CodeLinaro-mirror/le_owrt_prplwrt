export PKCS11_MODULE_PATH=/usr/lib/softhsm/libsofthsm2.so
mosquitto_pub \
  --cafile /usr/share/ca-certificates/ca.crt \
  --cert /root/certs/client.crt \
  --key /root/certs/client.key \
  -h prplOS.lan -p 8883 \
  -t MySerialTopic \
  -m "hello" \
  -d
