#!/usr/bin/env bash
set -euo pipefail

source /opt/start.sh

solver="$(command -v IncNavierStokesSolver)"
echo "Checking Nektar++ VIV solver: ${solver}"

ldd "${solver}" > /tmp/nektar-viv-ldd.txt

if ! grep -Eiq 'libmpi|libmpich' /tmp/nektar-viv-ldd.txt; then
    echo "ERROR: IncNavierStokesSolver is not linked to MPI."
    echo "Rebuild with -DNEKTAR_USE_MPI=ON and MPI compiler wrappers."
    cat /tmp/nektar-viv-ldd.txt
    exit 1
fi

if ! grep -Eiq 'libfftw3' /tmp/nektar-viv-ldd.txt; then
    echo "ERROR: IncNavierStokesSolver is not linked to FFTW."
    echo "Rebuild with -DNEKTAR_USE_FFTW=ON."
    cat /tmp/nektar-viv-ldd.txt
    exit 1
fi

IncNavierStokesSolver --help > /tmp/nektar-viv-help.txt

echo "Nektar++ VIV container check passed."
