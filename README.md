# Nektar++ VIV Container

Container recipe for Nektar++ 5.9.0 with the patched `MovingBody` forcing used for pinned-pinned flexible-cylinder VIV runs.

This follows the compact style of `j34ni/nektar-container`: Miniforge, conda-forge `mvapich=4.1`, `/opt/start.sh`, and the `srun --mpi=pmi2 singularity exec ... source /opt/start.sh` launch pattern. Unlike the reference image, this image builds Nektar++ from source so it contains the updated `ForcingMovingBody.cpp` implementation instead of the unmodified conda-forge `nektar` package. The image is built with MPI, FFTW, and PT-Scotch enabled for homogeneous flexible-cylinder runs on Slurm clusters.

## What Is Patched

- Fixes the pinned-pinned sine-transform half-index integer-division bug.
- Adds `StructDampingRatio`.
- Adds `BendingStiffRatio`, for cases such as `EI = 0.02 T`.
- Adds `StructReducedVelocity`, so `CableTension` can be recomputed from `Ur = U / (fn1 d)` when `LZ` changes.

## Build Locally

```bash
docker build -t nektar-viv:5.9.0 .
```

For a smaller GitHub Actions runner, reduce parallelism:

```bash
docker build --build-arg BUILD_JOBS=2 -t nektar-viv:5.9.0 .
```

## Run

```bash
docker run --rm -it -v "$PWD:/workspace" nektar-viv:5.9.0 \
  'source /opt/start.sh && IncNavierStokesSolver --help'
```

The Docker build also runs `/opt/check_nektar_viv.sh`, which fails the build if
`IncNavierStokesSolver` is not linked to MPI/FFTW, `mpirun` is unavailable, or
the solver does not expose a Scotch/PtScotch partitioner.

Example case run:

```bash
docker run --rm -it -v "$PWD:/workspace" nektar-viv:5.9.0 \
  'source /opt/start.sh && cd /workspace && IncNavierStokesSolver base_flow_PIN.xml'
```

MPI smoke test:

```bash
docker run --rm -it -v "$PWD:/workspace" nektar-viv:5.9.0 \
  'source /opt/start.sh && mpirun -np 2 IncNavierStokesSolver --help'
```

## Publish On GitHub

Create a GitHub repository, push this folder to `main`, then GitHub Actions will publish:

```text
ghcr.io/jianxunz/nektar-viv:latest
ghcr.io/jianxunz/nektar-viv:5.9.0-viv
```

The workflow is in `.github/workflows/container.yml`.

## Apptainer/Singularity

After the GHCR image exists:

```bash
apptainer pull docker://ghcr.io/jianxunz/nektar-viv:latest
```

Or edit `mvapich.def` and replace `YOUR_GITHUB_USERNAME`.

On Betzy/Slurm, use the MPI-enabled image with `srun`, for example:

```bash
srun -n 8 --mpi=pmi2 singularity exec --bind "$PWD:/opt/uio" nektar-viv_latest.sif \
  bash -lc 'source /opt/start.sh && cd /opt/uio && IncNavierStokesSolver --npz 1 base_flow.xml'
```

If the Slurm log repeats the Nektar session summary hundreds of times and all ranks write the same `base_flow_0.chk`, the image is serial. Rebuild it after this repository change so `IncNavierStokesSolver` links against MPI. If the log says `Valid partitioner not found! Either Scotch or METIS should be used.`, rebuild after the PT-Scotch change so Nektar can split the mesh across in-plane MPI ranks. You can also check the image manually:

```bash
singularity exec nektar-viv_latest.sif /opt/check_nektar_viv.sh
```

## Notes

The Dockerfile currently builds the `IncNavierStokesSolver` target and installs Nektar++ into `/opt/nektar` in the runtime image. This keeps the image focused on the flexible-cylinder VIV workflow. The reference `j34ni/nektar-container` image is better when the unmodified conda-forge Nektar++ package is enough; this VIV image is better for running the patched solver. If you need all Nektar++ tools in the VIV image, change the build command in `Dockerfile` from:

```bash
cmake --build /build/nektar --target IncNavierStokesSolver
```

to:

```bash
cmake --build /build/nektar
```
