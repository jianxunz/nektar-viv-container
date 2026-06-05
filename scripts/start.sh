#!/usr/bin/env bash
export NEKTAR_HOME="${NEKTAR_HOME:-/opt/nektar}"
export PATH="${NEKTAR_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${NEKTAR_HOME}/lib:${LD_LIBRARY_PATH:-}"
