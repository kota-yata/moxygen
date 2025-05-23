#!/usr/bin/env bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

## Run this script to build moxygen and run the tests.

# Obtain the base directory this script resides in.
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Useful constants
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_OFF="\033[0m"

function detect_platform() {
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     PLATFORM=Linux;;
      Darwin*)    PLATFORM=Mac;;
      *)          PLATFORM="UNKNOWN:${unameOut}"
  esac
  echo -e "${COLOR_GREEN}Detected platform: $PLATFORM ${COLOR_OFF}"
}

function install_dependencies_linux() {
  apt update -yq
  apt install -yq \
    build-essential \
    git \
    python3 \
    cmake \
    g++ \
    gcc \
    libssl-dev \
    autoconf \
    libz-dev \
    libjemalloc-dev \
    libbz2-dev \
    liblz4-dev \
    libsnappy-dev \
    libsodium-dev \
    libunwind-dev \
    libgflags-dev \
    libevent-dev  \
    libgoogle-glog-dev \
    libdouble-conversion-dev \
    libboost-all-dev \
    gperf
}

function install_dependencies_mac() {
  # install the default dependencies from homebrew
  brew install -f            \
    cmake                    \
    m4                       \
    boost                    \
    double-conversion        \
    fast_float               \
    gflags                   \
    glog                     \
    gperf                    \
    libevent                 \
    lz4                      \
    snappy                   \
    xz                       \
    openssl                  \
    libsodium                \
    zstd

  brew link                 \
    cmake                   \
    boost                   \
    double-conversion       \
    gflags                  \
    glog                    \
    gperf                   \
    libevent                \
    lz4                     \
    snappy                  \
    openssl                 \
    xz                      \
    libsodium               \
    zstd
}

function install_dependencies() {
  echo -e "${COLOR_GREEN}[ INFO ] install dependencies ${COLOR_OFF}"
  if [ "$PLATFORM" = "Linux" ]; then
    install_dependencies_linux
  elif [ "$PLATFORM" = "Mac" ]; then
    install_dependencies_mac
  else
    echo -e "${COLOR_RED}[ ERROR ] Unknown platform: $PLATFORM ${COLOR_OFF}"
    exit 1
  fi
}

function synch_dependency_to_commit() {
  # Utility function to synch a dependency to a specific commit. Takes two arguments:
  #   - $1: folder of the dependency's git repository
  #   - $2: path to the text file containing the desired commit hash
  if [ "$FETCH_DEPENDENCIES" = false ] ; then
    return
  fi
  DEP_REV=$(sed 's/Subproject commit //' "$2")
  pushd "$1"
  git fetch
  # Disable git warning about detached head when checking out a specific commit.
  git -c advice.detachedHead=false checkout "$DEP_REV"
  popd
}

function setup_fast_float() {
  FASTFLOAT_DIR=$DEPS_DIR/fast_float
  FASTFLOAT_BUILD_DIR=$DEPS_DIR/fast_float/build/
  FASTFLOAT_TAG=$(grep "subdir = " ../build/fbcode_builder/manifests/fast_float | cut -d "-" -f 2,3)
  if [ ! -d "$FASTFLOAT_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning fast_float repo ${COLOR_OFF}"
    git clone https://github.com/fastfloat/fast_float.git  "$FASTFLOAT_DIR"
  fi
  cd "$FASTFLOAT_DIR"
  git fetch --tags
  git checkout "v${FASTFLOAT_TAG}"
  echo -e "${COLOR_GREEN}Building fast_float ${COLOR_OFF}"
  mkdir -p "$FASTFLOAT_BUILD_DIR"
  cd "$FASTFLOAT_BUILD_DIR" || exit

  cmake                                           \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"               \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"            \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo             \
    -DFASTFLOAT_TEST=OFF                          \
    -DFASTFLOAT_SANITIZE=OFF                      \
    ..
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}fast_float is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_fmt() {
  FMT_DIR=$DEPS_DIR/fmt
  FMT_BUILD_DIR=$DEPS_DIR/fmt/build/
  FMT_TAG=$(grep "subdir = " ../build/fbcode_builder/manifests/fmt | cut -d "-" -f 2)
  if [ ! -d "$FMT_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning fmt repo ${COLOR_OFF}"
    git clone https://github.com/fmtlib/fmt.git  "$FMT_DIR"
  fi
  cd "$FMT_DIR"
  git fetch --tags
  git checkout "${FMT_TAG}"
  echo -e "${COLOR_GREEN}Building fmt ${COLOR_OFF}"
  mkdir -p "$FMT_BUILD_DIR"
  cd "$FMT_BUILD_DIR" || exit

  cmake                                           \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"               \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"            \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo             \
    "$MAYBE_OVERRIDE_CXX_FLAGS"                   \
    -DFMT_DOC=OFF                                 \
    -DFMT_TEST=OFF                                \
    ..
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}fmt is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_googletest() {
  GTEST_DIR=$DEPS_DIR/googletest
  GTEST_BUILD_DIR=$DEPS_DIR/googletest/build/
  GTEST_TAG=$(grep "subdir = " ../build/fbcode_builder/manifests/googletest | cut -d "-" -f 2,3)
  if [ ! -d "$GTEST_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning googletest repo ${COLOR_OFF}"
    git clone https://github.com/google/googletest.git  "$GTEST_DIR"
  fi
  cd "$GTEST_DIR"
  git fetch --tags
  git checkout "${GTEST_TAG}"
  echo -e "${COLOR_GREEN}Building googletest ${COLOR_OFF}"
  mkdir -p "$GTEST_BUILD_DIR"
  cd "$GTEST_BUILD_DIR" || exit

  cmake                                           \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"               \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"            \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo             \
    ..
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}googletest is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_zstd() {
  ZSTD_DIR=$DEPS_DIR/zstd
  ZSTD_BUILD_DIR=$DEPS_DIR/zstd/build/cmake/builddir
  ZSTD_INSTALL_DIR=$DEPS_DIR
  ZSTD_TAG=$(grep "subdir = " ../build/fbcode_builder/manifests/zstd | cut -d "-" -f 2 | cut -d "/" -f 1)
  if [ ! -d "$ZSTD_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning zstd repo ${COLOR_OFF}"
    git clone https://github.com/facebook/zstd.git "$ZSTD_DIR"
  fi
  cd "$ZSTD_DIR"
  git fetch --tags
  git checkout "v${ZSTD_TAG}"
  echo -e "${COLOR_GREEN}Building Zstd ${COLOR_OFF}"
  mkdir -p "$ZSTD_BUILD_DIR"
  cd "$ZSTD_BUILD_DIR" || exit
  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo           \
    -DBUILD_TESTS=OFF                               \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5              \
    -DCMAKE_PREFIX_PATH="$ZSTD_INSTALL_DIR"         \
    -DCMAKE_INSTALL_PREFIX="$ZSTD_INSTALL_DIR"      \
    ${CMAKE_EXTRA_ARGS[@]+"${CMAKE_EXTRA_ARGS[@]}"} \
    ..
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}Zstd is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_folly() {
  FOLLY_DIR=$DEPS_DIR/folly
  FOLLY_BUILD_DIR=$DEPS_DIR/folly/build/

  if [ ! -d "$FOLLY_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning folly repo ${COLOR_OFF}"
    git clone https://github.com/facebook/folly.git "$FOLLY_DIR"
  fi

  synch_dependency_to_commit "$FOLLY_DIR" "$BASE_DIR"/build/deps/github_hashes/facebook/folly-rev.txt
  if [ "$PLATFORM" = "Mac" ]; then
    # Homebrew installs OpenSSL in a non-default location on MacOS >= Mojave
    # 10.14 because MacOS has its own SSL implementation.  If we find the
    # typical Homebrew OpenSSL dir, load OPENSSL_ROOT_DIR so that cmake
    # will find the Homebrew version.
    dir=/usr/local/opt/openssl
    if [ -d $dir ]; then
        export OPENSSL_ROOT_DIR=$dir
    fi
  fi
  echo -e "${COLOR_GREEN}Building Folly ${COLOR_OFF}"
  mkdir -p "$FOLLY_BUILD_DIR"
  cd "$FOLLY_BUILD_DIR" || exit
  MAYBE_DISABLE_JEMALLOC=""
  if [ "$NO_JEMALLOC" == true ] ; then
    MAYBE_DISABLE_JEMALLOC="-DFOLLY_USE_JEMALLOC=0"
  fi

  MAYBE_USE_STATIC_DEPS=""
  MAYBE_USE_STATIC_BOOST=""
  MAYBE_BUILD_SHARED_LIBS=""
  if [ "$BUILD_FOR_FUZZING" == true ] ; then
    MAYBE_USE_STATIC_DEPS="-DUSE_STATIC_DEPS_ON_UNIX=ON"
    MAYBE_USE_STATIC_BOOST="-DBOOST_LINK_STATIC=ON"
    MAYBE_BUILD_SHARED_LIBS="-DBUILD_SHARED_LIBS=OFF"
  fi

  # We need to add C++ v20 to activate coroutines
  cmake                                           \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"               \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"            \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo             \
    -DBUILD_TESTS=OFF                             \
    -DCMAKE_CXX_STANDARD=20                       \
    "$MAYBE_USE_STATIC_DEPS"                      \
    "$MAYBE_USE_STATIC_BOOST"                     \
    "$MAYBE_BUILD_SHARED_LIBS"                    \
    "$MAYBE_OVERRIDE_CXX_FLAGS"                   \
    $MAYBE_DISABLE_JEMALLOC                       \
    ..
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}Folly is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_fizz() {
  FIZZ_DIR=$DEPS_DIR/fizz
  FIZZ_BUILD_DIR=$DEPS_DIR/fizz/build/
  if [ ! -d "$FIZZ_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning fizz repo ${COLOR_OFF}"
    git clone https://github.com/facebookincubator/fizz "$FIZZ_DIR"
  fi
  synch_dependency_to_commit "$FIZZ_DIR" "$BASE_DIR"/build/deps/github_hashes/facebookincubator/fizz-rev.txt
  echo -e "${COLOR_GREEN}Building Fizz ${COLOR_OFF}"
  mkdir -p "$FIZZ_BUILD_DIR"
  cd "$FIZZ_BUILD_DIR" || exit

  MAYBE_USE_STATIC_DEPS=""
  MAYBE_USE_SODIUM_STATIC_LIBS=""
  MAYBE_BUILD_SHARED_LIBS=""
  if [ "$BUILD_FOR_FUZZING" == true ] ; then
    MAYBE_USE_STATIC_DEPS="-DUSE_STATIC_DEPS_ON_UNIX=ON"
    MAYBE_USE_SODIUM_STATIC_LIBS="-Dsodium_USE_STATIC_LIBS=ON"
    MAYBE_BUILD_SHARED_LIBS="-DBUILD_SHARED_LIBS=OFF"
  fi

  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"             \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"          \
    -DBUILD_TESTS=OFF                           \
    "$MAYBE_USE_STATIC_DEPS"                    \
    "$MAYBE_BUILD_SHARED_LIBS"                  \
    "$MAYBE_OVERRIDE_CXX_FLAGS"                 \
    "$MAYBE_USE_SODIUM_STATIC_LIBS"             \
    "$FIZZ_DIR/fizz"
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}Fizz is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_wangle() {
  WANGLE_DIR=$DEPS_DIR/wangle
  WANGLE_BUILD_DIR=$DEPS_DIR/wangle/build/
  if [ ! -d "$WANGLE_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning wangle repo ${COLOR_OFF}"
    git clone https://github.com/facebook/wangle "$WANGLE_DIR"
  fi
  synch_dependency_to_commit "$WANGLE_DIR" "$BASE_DIR"/build/deps/github_hashes/facebook/wangle-rev.txt
  echo -e "${COLOR_GREEN}Building Wangle ${COLOR_OFF}"
  mkdir -p "$WANGLE_BUILD_DIR"
  cd "$WANGLE_BUILD_DIR" || exit

  MAYBE_USE_STATIC_DEPS=""
  MAYBE_BUILD_SHARED_LIBS=""
  if [ "$BUILD_FOR_FUZZING" == true ] ; then
    MAYBE_USE_STATIC_DEPS="-DUSE_STATIC_DEPS_ON_UNIX=ON"
    MAYBE_BUILD_SHARED_LIBS="-DBUILD_SHARED_LIBS=OFF"
  fi

  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"             \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"          \
    -DBUILD_TESTS=OFF                           \
    "$MAYBE_USE_STATIC_DEPS"                    \
    "$MAYBE_BUILD_SHARED_LIBS"                  \
    "$MAYBE_OVERRIDE_CXX_FLAGS"                 \
    "$WANGLE_DIR/wangle"
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}Wangle is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_mvfst() {
  MVFST_DIR=$DEPS_DIR/mvfst
  MVFST_BUILD_DIR=$DEPS_DIR/mvfst/build/
  if [ ! -d "$MVFST_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning mvfst repo ${COLOR_OFF}"
    git clone https://github.com/facebook/mvfst "$MVFST_DIR"
  fi
  synch_dependency_to_commit "$MVFST_DIR" "$BASE_DIR"/build/deps/github_hashes/facebook/mvfst-rev.txt
  echo -e "${COLOR_GREEN}Building Mvfst ${COLOR_OFF}"
  mkdir -p "$MVFST_BUILD_DIR"
  cd "$MVFST_BUILD_DIR" || exit

  MAYBE_USE_STATIC_DEPS=""
  MAYBE_BUILD_SHARED_LIBS=""
  if [ "$BUILD_FOR_FUZZING" == true ] ; then
    MAYBE_USE_STATIC_DEPS="-DUSE_STATIC_DEPS_ON_UNIX=ON"
    MAYBE_BUILD_SHARED_LIBS="-DBUILD_SHARED_LIBS=OFF"
  fi


  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"             \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"          \
    -DBUILD_TESTS=OFF                           \
    "$MAYBE_USE_STATIC_DEPS"                    \
    "$MAYBE_BUILD_SHARED_LIBS"                  \
    "$MAYBE_OVERRIDE_CXX_FLAGS"                 \
    "$MVFST_DIR"
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}Mvfst is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

function setup_proxygen() {
  PROXYGEN_DIR=$DEPS_DIR/proxygen
  PROXYGEN_BUILD_DIR=$DEPS_DIR/proxygen/build/
  if [ ! -d "$PROXYGEN_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning proxygen repo ${COLOR_OFF}"
    git clone https://github.com/facebook/proxygen.git "$PROXYGEN_DIR"
  fi
  synch_dependency_to_commit "$PROXYGEN_DIR" "$BASE_DIR"/build/deps/github_hashes/facebook/proxygen-rev.txt
  echo -e "${COLOR_GREEN}Building proxygen ${COLOR_OFF}"
  mkdir -p "$PROXYGEN_BUILD_DIR"
  cd "$PROXYGEN_BUILD_DIR" || exit

  MAYBE_USE_STATIC_DEPS=""
  MAYBE_BUILD_SHARED_LIBS=""
  if [ "$BUILD_FOR_FUZZING" == true ] ; then
    MAYBE_USE_STATIC_DEPS="-DUSE_STATIC_DEPS_ON_UNIX=ON"
    MAYBE_BUILD_SHARED_LIBS="-DBUILD_SHARED_LIBS=OFF"
  fi


  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"             \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"          \
    -DBUILD_TESTS=OFF                           \
    "$MAYBE_USE_STATIC_DEPS"                    \
    "$MAYBE_BUILD_SHARED_LIBS"                  \
    "$MAYBE_OVERRIDE_CXX_FLAGS"                 \
    "$PROXYGEN_DIR"
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}Moxygen is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

# Parse args
JOBS=8
INSTALL_DEPENDENCIES=true
INSTALL_LIBRARIES=true
FETCH_DEPENDENCIES=true
PREFIX=""
COMPILER_FLAGS=""
USAGE="./build.sh [-j num_jobs] [-m|--no-jemalloc] [--no-install-dependencies] [-p|--prefix] [-x|--compiler-flags] [--no-fetch-dependencies]"
while [ "$1" != "" ]; do
  case $1 in
    -j | --jobs ) shift
                  JOBS=$1
                  ;;
    -m | --no-jemalloc )
                  NO_JEMALLOC=true
                  ;;
    --no-install-dependencies )
                  INSTALL_DEPENDENCIES=false
          ;;
    --no-install-libraries )
                  INSTALL_LIBRARIES=false
          ;;
    --no-fetch-dependencies )
                  FETCH_DEPENDENCIES=false
          ;;
    --build-for-fuzzing )
                  BUILD_FOR_FUZZING=true
      ;;
    -t | --no-tests )
                  NO_BUILD_TESTS=true
      ;;
    -p | --prefix )
                  shift
                  PREFIX=$1
      ;;
    -x | --compiler-flags )
                  shift
                  COMPILER_FLAGS=$1
      ;;
    * )           echo "$USAGE"
                  exit 1
esac
shift
done

detect_platform

if [ "$INSTALL_DEPENDENCIES" == true ] ; then
  install_dependencies
fi

MAYBE_OVERRIDE_CXX_FLAGS=""
if [ -n "$COMPILER_FLAGS" ] ; then
  MAYBE_OVERRIDE_CXX_FLAGS="-DCMAKE_CXX_FLAGS=$COMPILER_FLAGS"
fi

BUILD_DIR=_build
mkdir -p $BUILD_DIR

set -e nounset
trap 'cd $BASE_DIR' EXIT
cd $BUILD_DIR || exit
BWD=$(pwd)
DEPS_DIR=$BWD/deps
mkdir -p "$DEPS_DIR"

# Must execute from the directory containing this script
cd "$(dirname "$0")"

if [ "$INSTALL_LIBRARIES" == true ] ; then
  setup_fast_float
  setup_fmt
  setup_googletest
  setup_zstd
  setup_folly
  setup_fizz
  setup_wangle
  setup_mvfst
  setup_proxygen
fi

MAYBE_BUILD_FUZZERS=""
MAYBE_USE_STATIC_DEPS=""
MAYBE_LIB_FUZZING_ENGINE=""
MAYBE_BUILD_SHARED_LIBS=""
MAYBE_BUILD_TESTS="-DBUILD_TESTS=ON"
if [ "$NO_BUILD_TESTS" == true ] ; then
  MAYBE_BUILD_TESTS="-DBUILD_TESTS=OFF"
fi
if [ "$BUILD_FOR_FUZZING" == true ] ; then
  MAYBE_BUILD_FUZZERS="-DBUILD_FUZZERS=ON"
  MAYBE_USE_STATIC_DEPS="-DUSE_STATIC_DEPS_ON_UNIX=ON"
  MAYBE_LIB_FUZZING_ENGINE="-DLIB_FUZZING_ENGINE='$LIB_FUZZING_ENGINE'"
  MAYBE_BUILD_SHARED_LIBS="-DBUILD_SHARED_LIBS=OFF"
fi

if [ -z "$PREFIX" ]; then
  PREFIX=$BWD
fi

if [ -z "$PREFIX" ]; then
  PREFIX=$BWD
fi

# Build moxygen with cmake
cd "$BWD" || exit

cd "$BASE_DIR"

echo "Current: $(pwd)"
echo "Deps dir: $DEPS_DIR"
echo "Prefix dir: $PREFIX"
echo "MAYBE_BUILD_TESTS: $MAYBE_BUILD_TESTS"

cmake                                     \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
  -DCMAKE_PREFIX_PATH="$DEPS_DIR"         \
  -DCMAKE_INSTALL_PREFIX="$PREFIX"        \
  "$MAYBE_BUILD_TESTS"                    \
  "$MAYBE_BUILD_FUZZERS"                  \
  "$MAYBE_BUILD_SHARED_LIBS"              \
  "$MAYBE_OVERRIDE_CXX_FLAGS"             \
  "$MAYBE_USE_STATIC_DEPS"                \
  "$MAYBE_LIB_FUZZING_ENGINE"             \
  .

echo "Current: $(pwd)"
echo "BWD: $BWD"
make -j "$JOBS"
make install
echo -e "${COLOR_GREEN}Moxygen build is complete${COLOR_OFF}"
