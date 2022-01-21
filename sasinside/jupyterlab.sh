#!/bin/bash

# Run in the context of the user
su - ${SAS_DEMO_USER} << "EOT"
echo "Setting up Python environment"
python3 -mvenv /python/
source /python/bin/activate
pip install --upgrade pip
echo "Installing Jupyter Lab and SAS Kernel"
pip install --upgrade wheel
pip install --upgrade pandas jupyterlab ipykernel sas_kernel
echo "Starting Jupyter Lab"
existing_pw=$(awk '{print $5}' authinfo.txt)
python -m jupyter_server.auth password ${existing_pw}
nohup jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser &
EOT