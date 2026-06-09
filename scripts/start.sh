#!/usr/bin/env bash
if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
    . /opt/conda/etc/profile.d/conda.sh
    conda activate base
fi

export NEKTAR_HOME="${NEKTAR_HOME:-/opt/nektar}"
export PATH="${NEKTAR_HOME}/bin:/opt/conda/bin:${PATH}"
export LD_LIBRARY_PATH="${NEKTAR_HOME}/lib:${NEKTAR_HOME}/lib/nektar++:/opt/conda/lib:${LD_LIBRARY_PATH:-}"
