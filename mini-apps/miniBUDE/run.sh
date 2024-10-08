#!/usr/bin/env bash

set -eu
BASE="$PWD"
BM=big5

# Downloading source code
if [ ! -e minibude/CMakeLists.txt ]; then
  if ! git clone -b main https://github.com/UoB-HPC/minibude; then
    echo "\n Failed to fetch source code. \n"
    exit 1
  fi
fi

# Setting the environment
source $BASE/../../environment/$1.env $2

# Compiling the code
cd "$BASE/minibude"
# Fix CUDA compilation error
sed -i "s/\-fast/\-use_fast_math/g" CMakeLists.txt

CMAKE_OPTS+="-DCMAKE_VERBOSE_MAKEFILE=ON "

if [ "$VENDOR" = "INTEL" ]; then
  MODEL="sycl"
  CMAKE_OPTS+="-DSYCL_COMPILER=ONEAPI-ICPX "
  CMAKE_OPTS+="-DCXX_EXTRA_FLAGS=-march=native "
elif [ "$VENDOR" = "NVIDIA" ]; then
  MODEL="cuda"
  CMAKE_OPTS+="-DCMAKE_CUDA_COMPILER=$(which nvcc) "
  CMAKE_OPTS+="-DCUDA_ARCH=$ARCH "
  CMAKE_OPTS+="-DCMAKE_CXX_COMPILER=nvc++ "
  #MODEL="acc"
  #CMAKE_OPTS+="-DCUDA_ARCH=cc90 "
  #CMAKE_OPTS+="-DCMAKE_CXX_COMPILER=nvc++ "
  #CMAKE_OPTS+="-DTARGET_DEVICE=gpu "
  #CMAKE_OPTS+="-DTARGET_PROCESSOR=native "
  CMAKE_OPTS+="-DCXX_EXTRA_FLAGS=-march=native "
elif [ "$VENDOR" = "AMD" ]; then
  MODEL="hip"
  CMAKE_OPTS+="-DCMAKE_C_COMPILER=gcc "
  CMAKE_OPTS+="-DCMAKE_CXX_COMPILER=hipcc "
  CMAKE_OPTS+="-DCXX_EXTRA_FLAGS=-march=native;--offload-arch=gfx90a;--gcc-toolchain=/soft/compilers/gcc/12.2.0/x86_64-suse-linux/ "
else
  echo "VENDOR variable is either unset or not set to INTEL/NVIDIA/AMD"
fi

CMAKE_OPTS+="-DMODEL=$MODEL "
BENCHMARK_EXE="$MODEL-bude"


rm -rf build

cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=RELEASE $CMAKE_OPTS
cmake --build build --config RELEASE -j "$NCPUS"
ldd "$BASE/minibude/build/$BENCHMARK_EXE"

# Running the code
OUT=$BASE/$MODEL-bude-$BM.out

RUN() {
  cd "$BASE/minibude"
  mkdir -p results
  BENCHMARK_EXE="$PWD/build/$MODEL-bude"
  DECK="$PWD/data/$1"

  cd "$BASE"
  $MPICOMMAND\
    $BASE/../gpu_tile_compact.sh\
    sh -c "$BENCHMARK_EXE --deck $DECK --wgsize 4,8,16,32,64,128,256,512,1024 --ppwi 1,2,4,8,16,32,64 --csv | tee $OUT\${RANK}"
}

RUN $BM

# FOM
cd $BASE
result=${OUT}0
best=$(tail -n1 $result)
ppwi=$(echo "$best" | grep -oP '(?<=ppwi: )\d+')
wgsize=$(echo "$best" | grep -oP '(?<=wgsize: )\d+')
echo ========================================
echo best gflops/s = $(echo $(grep "^$ppwi,$wgsize" $result) | awk -F',' '{print $9}')
echo ========================================

