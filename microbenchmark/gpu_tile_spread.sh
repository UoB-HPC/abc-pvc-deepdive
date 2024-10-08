#!/usr/bin/env bash

num_gpu=6
num_tile=2

_MPI_RANKID=$PALS_LOCAL_RANKID
gpu_id=$((_MPI_RANKID % num_gpu))
tile_id=$((_MPI_RANKID / num_gpu))

export ZE_ENABLE_PCI_ID_DEVICE_ORDER=1
# Pleasing MPI by using ONEAPI_DEVICE_SELECTOR
#export ZE_AFFINITY_MASK=$gpu_id.$tile_id
export ONEAPI_DEVICE_SELECTOR=level_zero:$gpu_id.$tile_id
#https://stackoverflow.com/a/28099707/7674852
"$@"

