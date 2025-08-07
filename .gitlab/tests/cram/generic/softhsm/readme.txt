Local run instruction


# Create and activate a virtual environment
python -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install the python cram package
pip install cram


export TARGET_LAN_IP=freedom
export CRAM_REMOTE_COMMAND="ssh root@$TARGET_LAN_IP"
export CRAM_REMOTE_COPY="scp -q -O"

# Workaround if MAC address changed
ssh-keygen -f '/home/tomasz.kilarski/.ssh/known_hosts' -R 10.42.0.28
$CRAM_REMOTE_COMMAND "echo hello"


cram -v ~/prplos/.gitlab/tests/cram/generic/softhsm/001-hsm-setup.t
cram -v ~/prplos/.gitlab/tests/cram/generic/softhsm/002-hsm-mqtt-broker.t
cram -v ~/prplos/.gitlab/tests/cram/generic/softhsm/003-hsm-http-server.t
