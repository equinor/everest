#!/bin/bash
# This script sets up an environment for installing and developing
# Everest and all of its dependencies. This gives a predictable
# folder structure with install logs for all of the dependencies,
# which can be compared across different users for debugging purposes.
# The script is invoked with two arguments: (1) the path to the python executable.
# We require this path to be specified explicitly to avoid just taking
# whatever happens to be in the env and hoping for the best.
# (2) The name of the to-be-created directory that will contain everest
# and all its dependencies. Defaults to "everdir"

if [ "$(uname -m)" != "x86_64" ]; then
  echo "This script is untested for $(uname -m) architecture"
  echo "It is recommended to use x86_64 architecture"
  echo "Do you want to continue? (y/n)"
  read -r response

  if [ "$response" = "y" ]; then
    echo "Continuing..."
  else
    echo "Exiting ..."
    exit
  fi
fi

set -e
ROOT_DIR=$(pwd)
echo "ROOT_DIR=$ROOT_DIR"

PYTHON_EXECUTABLE=$1
TARGET_DIR=$2

if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Python executable must be explicitly declared as first argument"
  exit
fi

if [ -z "$TARGET_DIR" ]; then
  echo "Target directory not specified, defaulting to 'everdir'..."
  TARGET_DIR="everdir"
fi

INSTALL_DIR="$ROOT_DIR/$TARGET_DIR"
echo "INSTALL_DIR=$INSTALL_DIR"
ENVS_DIR="$INSTALL_DIR/venv"
echo "ENVS_DIR=$ENVS_DIR"
mkdir "$INSTALL_DIR"
mkdir "$ENVS_DIR"

echo "Made dir $INSTALL_DIR"
echo "Made envs dir: $ENVS_DIR"
"$PYTHON_EXECUTABLE" -m venv "$ENVS_DIR/$TARGET_DIR"
echo "Made virtual env in $ENVS_DIR/$TARGET_DIR"

cd $INSTALL_DIR
git clone git@github.com:equinor/everest.git
cd everest
source "$ENVS_DIR/$TARGET_DIR/bin/activate"

cd "$INSTALL_DIR"
env -i sh "$INSTALL_DIR/everest/script/install-macos.sh" $VIRTUAL_ENV
cd everest
echo "Installing everest..."
pip install -e .[test]

echo "Running everest tests..."
python -m pytest tests
