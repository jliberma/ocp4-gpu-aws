#!/usr/bin/env bash

sudo yum install -y skopeo podman buildah
sudo oc project default
sudo podman login -u '$oauthtoken' -p a3I4dXNyYWZtcmQwODlpaHFuMnU1aHRrdWo6MzY4YjFiMGYtMDY3OS00N2VjLTg3MzUtNzA4NWM0ZDI2Njk1 nvcr.io
sudo podman pull nvcr.io/nvidia/tensorflow:19.08-py3
# need to adjust limits on the project
