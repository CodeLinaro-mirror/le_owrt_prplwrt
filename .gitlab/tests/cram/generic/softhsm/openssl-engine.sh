# Setup OpenSSL configuration
cat << EOF > /etc/config/openssl
config engine 'pkcs11'
        option enabled '1'
        option engine_id 'pkcs11'
EOF

cat << EOF > /etc/ssl/modules.cnf.d/pkcs11.cnf
[ pkcs11_sect ]
engine_id = pkcs11
dynamic_path = /usr/lib/engines/pkcs11.so
MODULE_PATH = /usr/lib/softhsm/libsofthsm2.so
PIN = 1234
EOF

/etc/init.d/openssl restart
