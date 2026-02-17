#!/usr/bin/env python3

import sys
import subprocess
from pathlib import Path
from typing import List

ODL_FILE_PATH = Path("/etc/config/tr181-security/tr181-security_config.odl")
ODL_DIRECTORY = Path("/etc/config/tr181-security/")
CA_CERTIFICATES_TOP_DIR = Path("/usr/share/ca-certificates/")
CA_BUNDLE_FILENAME = "ca-certificate.crt"
MAX_LINKS = 10

ODL_TEMPLATE = """%populate {{
    object Security.CABundle {{
{ca_bundles}
    }}
}}
"""

ODL_CA_BUNDLE_TEMPLATE = """        instance add ("{name}") {{
            parameter Enable = true;
            parameter Name = "{name}";
            parameter CADirURI = "file://{dir_uri}";
            parameter CAFileURI = "file://{file_uri}";
        }}"""

DEFAULT_CA_BUNDLE = ODL_CA_BUNDLE_TEMPLATE.format(
    name="default",
    dir_uri="/etc/ssl/certs",
    file_uri="/etc/ssl/certs/ca-certificates.crt",
)

def get_certificate_hash(cert_path: Path) -> str:
    result = subprocess.run(
        ["openssl", "x509", "-subject_hash", "-noout", "-in", str(cert_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"OpenSSL failed for {cert_path}: {result.stderr.strip()}"
        )

    return result.stdout.strip()


def create_hash_symlink(cert_path: Path, cert_hash: str) -> None:
    directory = cert_path.parent
    filename = cert_path.name

    for i in range(MAX_LINKS):
        link_name = f"{cert_hash}.{i}"
        link_path = directory / link_name

        if not link_path.exists():
            link_path.symlink_to(filename)
            return

    raise RuntimeError(
        f"Too many hash collisions for {cert_path} (max {MAX_LINKS})"
    )


def process_certificate_directory(directory: Path) -> None:
    bundle_path = directory / CA_BUNDLE_FILENAME
    with bundle_path.open("w") as bundle_file:
        for cert_path in sorted(directory.glob("*.crt")):
            if cert_path.name == CA_BUNDLE_FILENAME:
                continue

            # Append certificate to bundle
            bundle_file.write(cert_path.read_text())

            # Create subject hash symlink
            cert_hash = get_certificate_hash(cert_path)
            create_hash_symlink(cert_path, cert_hash)

def generate_odl_entry(name: str) -> str:
    dir_uri = CA_CERTIFICATES_TOP_DIR / name
    file_uri = dir_uri / CA_BUNDLE_FILENAME

    return ODL_CA_BUNDLE_TEMPLATE.format(
        name=name,
        dir_uri=dir_uri,
        file_uri=file_uri,
    )


def generate_odl_file(rootfs: Path, subdirs: List[str]) -> None:
    entries = [DEFAULT_CA_BUNDLE]
    entries.extend(generate_odl_entry(name) for name in sorted(subdirs))

    odl_content = ODL_TEMPLATE.format(
        ca_bundles="\n".join(entries)
    )

    odl_path = rootfs / ODL_FILE_PATH.relative_to("/")
    odl_path.parent.mkdir(parents=True, exist_ok=True)
    odl_path.write_text(odl_content)

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <rootfs-path>")
        sys.exit(1)

    rootfs = Path(sys.argv[1]).resolve()
    ca_top_dir = rootfs / CA_CERTIFICATES_TOP_DIR.relative_to("/")

    if not ca_top_dir.exists():
        print(f"ERROR: CA directory not found: {ca_top_dir}")
        sys.exit(1)

    subdirs = []

    for directory in sorted(ca_top_dir.iterdir()):
        if not directory.is_dir():
            continue

        subdirs.append(directory.name)
        process_certificate_directory(directory)

    generate_odl_file(rootfs, subdirs)


if __name__ == "__main__":
    main()
