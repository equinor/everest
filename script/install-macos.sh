#! /bin/bash
# exit early if encounter failure
set -e

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

INSTALL_DIR="$(pwd)/everdeps"
CACHE_DIR="$(pwd)/download_cache"

if [ ! -d "$CACHE_DIR" ]; then
  mkdir "$CACHE_DIR"
  echo "Created directory $CACHE_DIR for caching downloads"
fi

if [ ! -d "$INSTALL_DIR" ]; then
  mkdir "$INSTALL_DIR"
  echo "Created directory $INSTALL_DIR"
else
  echo "Install directory: $INSTALL_DIR already exists"
  exit
fi

VENV_BASE=$1
if [ -z "$VENV_BASE" ]; then
  echo "The virtual environment must be explicitly declared;"
  echo "Please supply the path of the virtual environment as the first argument"
  echo "so that it can be sourced"
  echo "This is usually \$VIRTUAL_ENV"
  exit
fi

source "$VENV_BASE/bin/activate"
echo "Sourced venv: $VENV_BASE/bin/activate"

cd "$INSTALL_DIR"
mkdir trace
TRACE_DIR="$INSTALL_DIR/trace"

touch "$TRACE_DIR/setenv"
write_to_setenv() {
  local name=$1
  local value=$2

  echo "Set $name to $value"
  echo "$name=\"$value\"" >> "$TRACE_DIR/setenv"
}

write_to_setenv INSTALL_DIR "$INSTALL_DIR"

python_version=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$(which python) : {g['include']} : {g['stdlib']} ;\")")"
echo "Detected python version $python_version"

write_to_setenv python_version "$python_version"
write_to_setenv python_bin_include_lib "$python_bin_include_lib"

# create logfiles
touch "$TRACE_DIR/boost_bootstrap.log"
touch "$TRACE_DIR/boost_install.log"

echo "Downloading and extracting Boost .."
boost_file=boost_1_82_0.tar.bz2

if [ ! -f "$CACHE_DIR/$boost_file" ]; then
  wget https://boostorg.jfrog.io/artifactory/main/release/1.82.0/source/boost_1_82_0.tar.bz2 -P "$CACHE_DIR"
else
  echo "Found $boost_file in download cache .."
fi

tar xf "$CACHE_DIR"/$boost_file
cd boost_1_82_0

echo "Bootstrapping Boost .."
./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python-version="$python_version" &> "$TRACE_DIR/boost_bootstrap.log"

echo "Replacing Python version in project-config.jam .."
sed -i '' "s|.*using python.*|$python_bin_include_lib|" project-config.jam

echo "Building Boost .."
./b2 install -j"$(getconf _NPROCESSORS_ONLN)" -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR" &> "$TRACE_DIR/boost_install.log"

echo "Done"
echo "Installed Boost to $INSTALL_DIR, logged to $TRACE_DIR/boost_bootstrap.log and $TRACE_DIR/boost_install.log"

cd "$INSTALL_DIR"

echo "Installing Dakota"

# create logfile
touch "$TRACE_DIR/dakota_install.log"

# Numpy is required for Dakota
# since we use DAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON
# If it is installed under arm64 arch, this will fail,
# solution is to uninstall and reinstall when in intel arch
pip install numpy
pip install cmake

echo "Download and extract Dakota .."

dakota_file=dakota-6.18.0-public-src-cli.tar.gz

if [ ! -f "$CACHE_DIR"/$dakota_file ]; then
  wget https://github.com/snl-dakota/dakota/releases/download/v6.18.0/dakota-6.18.0-public-src-cli.tar.gz -P "$CACHE_DIR"
else
  echo "Found $dakota_file in download cache .."
fi

tar xf "$CACHE_DIR"/$dakota_file
cd dakota-6.18.0-public-src-cli

mkdir build
cd build

echo "Building Dakota with cmake, logging to $TRACE_DIR/dakota_build.log"
cmake \
      -DCMAKE_CXX_STANDARD=14 \
      -DBUILD_SHARED_LIBS=ON \
      -DDAKOTA_PYTHON_DIRECT_INTERFACE=ON \
      -DDAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON \
      -DDAKOTA_DLL_API=OFF \
      -DHAVE_X_GRAPHICS=OFF \
      -DDAKOTA_ENABLE_TESTS=OFF \
      -DDAKOTA_ENABLE_TPL_TESTS=OFF \
      -DCMAKE_BUILD_TYPE="Release" \
      -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
      -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
      .. &> "$TRACE_DIR/dakota_build.log"

# set DYLD-path to include our libs
export "DYLD_LIBRARY_PATH=$INSTALL_DIR/lib:$INSTALL_DIR/bin"
write_to_setenv "export DYLD_LIBRARY_PATH" "$DYLD_LIBRARY_PATH"

echo "Building and Installing Dakota, logging to $TRACE_DIR/dakota_install.log"
make -j"$(getconf _NPROCESSORS_ONLN)" install &> "$TRACE_DIR/dakota_install.log"

echo "Installed Dakota to $INSTALL_DIR"
echo "Done"

export PATH="$PATH:$INSTALL_DIR/bin"
write_to_setenv "export PATH" "$PATH"

cd "$INSTALL_DIR"

echo "Pulling Carolina from git .."
git clone git@github.com:equinor/Carolina.git

# create logfile
touch "$TRACE_DIR/carolina_install.log"

cd Carolina

# Set vars needed by Carolina
export BOOST_ROOT="$INSTALL_DIR"
write_to_setenv "export BOOST_ROOT" "$INSTALL_DIR"

python_version_no_dots="$(echo "${python_version//\./}")"

export BOOST_PYTHON="boost_python$python_version_no_dots"
write_to_setenv "export BOOST_PYTHON" "$BOOST_PYTHON"

echo "Building Carolina .."
pip install . &> "$TRACE_DIR/carolina_install.log"
echo "Done"

cd "$INSTALL_DIR"
echo "Pulling Seba from git .."
git clone git@github.com:TNO-Everest/seba.git
cd seba
git checkout tags/6.13.0

echo "Building Seba .."
pip install .
echo "Done"

cd "$INSTALL_DIR"
echo "Pulling Everest-models from git .."
git clone git@github.com:equinor/everest-models.git
cd everest-models

echo "Building Everest-models .."
pip install .
echo "Done building Everest-models"

site_packages_dir=$(python -c "import site; print(site.getsitepackages()[0])")
carolina_so_path=$(find "$site_packages_dir" -name "carolina.cpython-310-darwin.so")
fortran_dylib_path=$(find /usr -name "libgfortran.dylib" | head -n 1)

echo "found site packages @ $site_packages_dir"
echo "found carolina.cpython-310-darwin.so @ $carolina_so_path"
echo "found libgfortran.dylib @ $fortran_dylib_path"

fortran_dylib_dir=$(dirname "$fortran_dylib_path")
install_lib_dir="$INSTALL_DIR/lib"

echo "Adding required rpaths to $carolina_so_path, like this:"

echo "install_name_tool -add_rpath $fortran_dylib_dir $carolina_so_path"
echo "install_name_tool -add_rpath $install_lib_dir $carolina_so_path"

install_name_tool -add_rpath "$fortran_dylib_dir" "$carolina_so_path"
install_name_tool -add_rpath "$install_lib_dir" "$carolina_so_path"

touch "$TRACE_DIR/carolina_so_otool.out"
otool -l "$carolina_so_path" > "$TRACE_DIR/carolina_so_otool.out"
echo "Done adding rpaths"
