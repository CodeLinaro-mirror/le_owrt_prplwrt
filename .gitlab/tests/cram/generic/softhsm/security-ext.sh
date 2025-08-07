FILE="/etc/amx/tr181-security/tr181-security_definition.odl"
if ! grep -q "string CertificateURI" "$FILE"; then
  sed -i '/object Certificate/a\
            string CertificateURI {\
                on action validate call check_maximum_length 64;\
                default "";\
            }\
\
            string PrivateKeyURI {\
                on action validate call check_maximum_length 64;\
                default "";\
            }' "$FILE"
fi
