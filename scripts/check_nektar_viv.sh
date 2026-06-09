#!/usr/bin/env bash
set -euo pipefail

source /opt/start.sh

solver="$(command -v IncNavierStokesSolver)"
echo "Checking Nektar++ VIV solver: ${solver}"

if ! command -v mpirun >/dev/null; then
    echo "ERROR: mpirun is not available. The MPI runtime is missing from PATH."
    exit 1
fi

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

if ! grep -Eq -- '--use-ptscotch|--use-scotch' /tmp/nektar-viv-help.txt; then
    echo "ERROR: IncNavierStokesSolver was built without Scotch/PtScotch partitioner support."
    echo "Rebuild with -DNEKTAR_USE_SCOTCH=ON."
    cat /tmp/nektar-viv-help.txt
    exit 1
fi

echo "Nektar++ VIV container check passed."
