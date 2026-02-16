#!/usr/bin/env python3

import os
import sys
import subprocess

ODL_FILE_PATH = "/etc/config/tr181-security/tr181-security_config.odl"
ODL_DIRECTORY = "/etc/config/tr181-security/"
CA_CERTIFICATES_TOP_DIR="/usr/share/ca-certificates/"
CA_BUNDLE_FILENAME = "ca-certificate.crt"
ODL_TEMPLATE = """%populate {{
    object Security.CABundle {{
       {ca_bundles}
    }}
}}
"""
ODL_CA_BUNDLE_TEMPLATE = """\tinstance add (\"{name}\") {{
            parameter Enable = true;
            parameter Name = "{name}";
            parameter CADirURI = "file://{dir_uri}";
            parameter CAFileURI = "file://{file_uri}";
        }}"""

DEFAULT_CA_BUNDLE = ODL_CA_BUNDLE_TEMPLATE.format(
        name="default",
        dir_uri="/etc/ssl/certs",
        file_uri="/etc/ssl/certs/ca-certificates.crt"
    )

MAX_LINKS=10

def create_ca_bundle_odl_entry(name):
    dir_uri = CA_CERTIFICATES_TOP_DIR+name
    file_uri = dir_uri+"/"+CA_BUNDLE_FILENAME
    return ODL_CA_BUNDLE_TEMPLATE.format(name=name, dir_uri=dir_uri, file_uri=file_uri)

def get_certificate_hash(path):
    result = subprocess.run(
            ['openssl', 'x509', '-subject_hash', '-noout', '-in', path],
            stdout=subprocess.PIPE,
            text=True
        )
    return str(result.stdout.strip())


def main():
    if len(sys.argv) < 2:
        print("ERROR: ROOTFS path not provided")
        sys.exit(1)
    rootfs = sys.argv[1]
    if rootfs[-1]=="/":
        rootfs[-1]="\0"
    subdirs = []

    ca_certificates_full_path = rootfs+CA_CERTIFICATES_TOP_DIR
    topdir_contents = os.listdir(ca_certificates_full_path)
    for subdir in topdir_contents:
        
        subdir_path = ca_certificates_full_path + subdir
        if not os.path.isdir(subdir_path):
            continue
        
        subdirs.append(subdir)
        subdir_contents = os.listdir(subdir_path)
        ca_bundle_file = open(subdir_path+"/"+CA_BUNDLE_FILENAME, "w")
        for filename in subdir_contents:
            ca_certificate_path = subdir_path+"/"+filename
            if not os.path.isfile(ca_certificate_path) or filename==CA_BUNDLE_FILENAME or filename[-1]=="0":
                continue
            with open(ca_certificate_path, "r") as ca_certificate_file:
                ca_bundle_file.write(ca_certificate_file.read())
            ca_certificate_hash = get_certificate_hash(ca_certificate_path)
            for i in range(0, MAX_LINKS):
                link_name = ca_certificate_hash+"."+str(i)
                link_path = subdir_path+"/"+link_name
                if not os.path.lexists(link_path):
                    os.symlink(filename, link_path)
                    print(link_path + " -> " + filename)
                    break

    

    ca_bundles = []
    ca_bundles.append(ODL_CA_BUNDLE_TEMPLATE.format(
        name="default",
        dir_uri="/etc/ssl/certs",
        file_uri="/etc/ssl/certs/ca-certificates.crt"
    ))
    for i in range(0, len(subdirs)):
        ca_bundles.append(create_ca_bundle_odl_entry(subdirs[i]))
    
    odl_contents = ODL_TEMPLATE.format(
        ca_bundles ='\n'.join(ca_bundles)
    )

    odl_full_path = rootfs+ODL_FILE_PATH
    os.makedirs(rootfs+ODL_DIRECTORY, exist_ok=True)
    with open(odl_full_path, "w") as odl:
        odl.write(odl_contents)

if __name__ == "__main__":
    main()