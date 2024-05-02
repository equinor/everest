# Building Everest and dependencies on MacOS

These instructions describe what you need to do in order to get Everest and needed dependencies up and running.

## General setup
Tested using

* boost 1.82
* python 3.10.11
* dakota 6.18

It is recommended to use one of the install scripts in the `scripts/` directory to standardize the management of paths and dependencies. Installation with and without the scripts require you to have **python** (recommended version: 3.10), **rosetta 2**, **gcc (with fortran)**, and **wget** installed.

### Setup using scripts in `scripts/`

Using available scrips, *either* run:

- install-macos-aio.sh
- install-macos.sh (and optionally make-m1-intel-python-executable.sh)

#### install-macos-aio.sh
This will install the environment and download Everest and set up a development environment with a standardized folder structure.

Run *either* from the terminal with appropriate arguments:

```
# The path to the python interpreter to be used for developing everest. Example: `$(which python3)`.
env -i sh install-macos-aio.sh $(which python3)
```

or

```
# The name of the directory that will contain Everest and its dependencies Default: `everdir`.
env -i sh install-macos-aio.sh $(which python3) custom-container-folder-name
```

This will call the script with a clean environment due to `env -i` into the folder `everdir` using the binary referred to by `python3`. This script will also create a fresh python virtual environment and a python interpreter that will work with M1 PyCharm.

#### install-macos.sh
This will install the dependencies of everest into `everdeps` as a subdirectory of the current directory. For this script you will have to supply an existing virtual environment before running. Thus, this script must be called with the base path of the virtual environment you wish to use.

`env -i sh ./everest/script/install-macos.sh $VIRTUAL_ENV`

(if you are currently inside the virtual env you wish to use)

#### make-m1-intel-python-executable.sh
To create python interpreter for intel arch, that can still be used within M1 PyCharm etc.
After having created the executable, select it as your python interpreter in PyCharm. This is only necesary if you are on a M1/M2 mac and you are running PyCharm for that architecture. If your PyCharm is intel arch it is not necessary to do this step.

## Rosetta & Homebrew

This section is for Apple silicon, -- not Intel Macs.

### Rosetta

Read these before you start
https://hackernoon.com/apple-m1-chip-how-to-install-homebrew-using-rosetta-su12331b
https://stackoverflow.com/questions/64882584/how-to-run-the-homebrew-installer-under-rosetta-2-on-m1-macbook

Create a setup that runs x86_64 using rosetta 2


### Homebrew

```
# read
https://brew.sh

# install homebrew
arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# install packages
arch -x86_64 brew install <packackage_name>
```


## Build Boost

**Download, extract and configure**

```
wget https://boostorg.jfrog.io/artifactory/main/release/1.82.0/source/boost_1_82_0.tar.bz2
tar xf boost_1_82_0.tar.bz2
cd boost_1_82_0

python_version=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')

./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python-version="$python_version"

# Insert correct using python.* statement for project-config.jam
python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$(which python) : {g['include']} : {g['stdlib']} ;\")")"
sed -i '' "s|.*using python.*|$python_bin_include_lib|" project-config.jam
```


I had issues detecting the python setup, and had to edit project-config.jam manually to account for this

_Please note that the spaces used here actually have an impact on boost configuration_

``` diff
diff -Naur project-config.jam.1 project-config.jam
--- project-config.jam.1	2023-06-05 13:16:49
+++ project-config.jam	2023-06-05 13:16:58
@@ -18,7 +18,7 @@
 import python ;
 if ! [ python.configured ]
 {
-    using python : 3.10 : "/Users/ANDRLI/Project/dev-env" ;
+using python : 3.10 : /usr/local/Cellar/python@3.10/3.10.11/bin/python3.10 : /usr/local/Cellar/python@3.10/3.10.11/Frameworks/Python.framework/Versions/3.10/include/python3.10 : /usr/local/Cellar/python@3.10/3.10.11/Frameworks/Python.framework/Versions/3.10/lib ;
 }

 # List of --with-<library> and --without-<library>
```

**Build**

```
./b2 install -j"$(getconf _NPROCESSORS_ONLN)" -a --prefix="$INSTALL_DIR_PATH"

```


## Build Dakota

Download, extract, build

```
wget https://github.com/snl-dakota/dakota/releases/download/v6.18.0/dakota-6.18.0-public-src-cli.tar.gz
tar xf dakota-6.18.0-public-src-cli.tar.gz
cd dakota-6.18.0-public-src-cli

# use a build directory
mkdir build
cd build

cmake \
    -DBUILD_SHARED_LIBS=ON \
    -DDAKOTA_PYTHON_DIRECT_INTERFACE=ON \
    -DDAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON \
    -DDAKOTA_DLL_API=OFF \
    -DHAVE_X_GRAPHICS=OFF \
    -DDAKOTA_ENABLE_TESTS=OFF \
    -DDAKOTA_ENABLE_TPL_TESTS=OFF \
    -DCMAKE_BUILD_TYPE='Release' \
    -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR_PATH}" \
    ..

# set DYLD-path to include our libs, and gfortran
export DYLD_LIBRARY_PATH=$INSTALL_DIR_PATH/lib

make -j "$(getconf _NPROCESSORS_ONLN)" install 2> err.log

```


## Carolina

```
git clone git@github.com:equinor/Carolina.git
cd Carolina
export BOOST_PYTHON=boost_python310

pip install .

```

### Note:
On mac, the linking between the shared object (for example `carolina.cpython-310-darwin.so`) and dynamic libraries generated by Dakota does not happen automatically. It is recommended to force the locations of these dynamic libraries into the `rpath` of the shared object file. To do this, do the following:

```
install_name_tool -add_rpath "$fortran_dylib_dir" "$carolina_so_path"
install_name_tool -add_rpath "$install_lib_dir" "$carolina_so_path"
```
where
* `$carolina_so_path` is the path to the `carolina.cpython-310-darwin.so` file, found under `site-packages` folder of your python installation
* `$fortran_dylib_dir` is the path to the folder in your system containing `libgfortran.dylib`
* `$install_lib_dir` is the `lib/` dir of your installation, containing the dylib files generated by Dakota.

The setup script (`script/install-macos.sh`) will do this automatically for you.

## Seba
```
git clone git@github.com:TNO-Everest/seba.git
cd seba
git checkout tags/<select_your_tag>
pip install .
```

## Everest-models
```
git clone git@github.com:equinor/everest-models.git
cd everest-models
pip install .
```

## Everest
```
git clone git@github.com:equinor/everest.git
cd everest
pip install .
```

# Check installation

After boost, dakota and Carolina have been installed, it's possible to do a simple test to see if paths are correct

```
python
import dakota
```
