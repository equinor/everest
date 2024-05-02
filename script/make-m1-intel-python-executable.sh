#!/bin/bash
echo "Making intel executable python in venv...(should work as python interpreter in M1 ARM64 PyCharm)"
make_intel_python_executable () {
  binary_path="$(realpath $1)"
  directory="$(dirname $1)"
  echo "making arch -x86_64 version of $binary_path in directory: $directory"
  new_executable_name="$(basename $1)-intel"
  echo '#!/usr/bin/env zsh
mydir=${0:a:h}
/usr/bin/arch -x86_64 $mydir/python "$@"
' > "$directory/$new_executable_name"
  chmod +x "$directory/$new_executable_name"
  echo "Made x86_64 executable: $directory/$new_executable_name"
}

make_intel_python_executable "$1"
