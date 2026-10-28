#!/bin/sh
# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
#
# Download the artifacts of the firmware build job of pipeline
# FW_PIPELINE_ID. Extract the named files into a directory, and the whole
# bin/ tree into the working directory, as a job that needs the build job
# gets it: the cram tests read packages and images from bin/.
#
# Usage: firmware-from-pipeline.sh <directory> <file>...
#
# Needs FW_PIPELINE_ID, FW_BUILD_JOB_NAME and the predefined CI variables.

set -eu

: "${FW_PIPELINE_ID:?FW_PIPELINE_ID is empty}"
: "${FW_BUILD_JOB_NAME:?FW_BUILD_JOB_NAME is empty}"

directory="$1"
shift

api="$CI_API_V4_URL/projects/$CI_PROJECT_ID"

job_id="$(
	curl --fail --silent --show-error \
		--header "JOB-TOKEN: $CI_JOB_TOKEN" \
		"$api/pipelines/$FW_PIPELINE_ID/jobs?scope%5B%5D=success&per_page=100" |
	jq -r --arg name "$FW_BUILD_JOB_NAME" \
		'map(select(.name == $name)) | .[0].id // empty'
)"

if [ -z "$job_id" ]; then
	printf 'No successful job "%s" in pipeline %s\n' \
		"$FW_BUILD_JOB_NAME" "$FW_PIPELINE_ID" >&2
	exit 1
fi

echo "Firmware from pipeline $FW_PIPELINE_ID, job $job_id"

curl --fail --silent --show-error --location \
	--header "JOB-TOKEN: $CI_JOB_TOKEN" \
	--output firmware-artifacts.zip \
	"$api/jobs/$job_id/artifacts"

python3 - "$directory" "$@" <<'EOF'
import sys
import zipfile
from pathlib import Path

directory = Path(sys.argv[1])
wanted = set(sys.argv[2:])
directory.mkdir(parents=True, exist_ok=True)
tree = 0
with zipfile.ZipFile("firmware-artifacts.zip") as archive:
    for member in archive.infolist():
        if member.is_dir():
            continue
        if member.filename.startswith("bin/"):
            archive.extract(member, ".")
            tree += 1
        name = Path(member.filename).name
        if name in wanted:
            (directory / name).write_bytes(archive.read(member))
            print(f"Extracted {member.filename}")
            wanted.discard(name)
print(f"Extracted {tree} files of bin/")
if wanted:
    sys.exit(f"Not in the artifacts: {' '.join(sorted(wanted))}")
EOF

rm -f firmware-artifacts.zip
