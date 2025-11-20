#!/bin/bash
# Wrapper script for kcli to use correct SSH key and directories
# This works around GitHub Actions runner setting HOME=/root

export HOME=/home/github-runner
export KCLI_HOME=/home/github-runner/.kcli
export KCLI_CONFIG=/home/github-runner/.kcli/config.yml

# Execute kcli with all arguments
exec /usr/bin/kcli "$@"

