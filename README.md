# Nektar++ VIV Container

Container recipe for Nektar++ 5.9.0 with the patched `MovingBody` forcing used for pinned-pinned flexible-cylinder VIV runs.

This follows the compact style of `j34ni/nektar-container`, but builds Nektar++ from source so the image contains the updated `ForcingMovingBody.cpp` implementation instead of the unmodified conda-forge binary package.

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

Example case run:

```bash
docker run --rm -it -v "$PWD:/workspace" nektar-viv:5.9.0 \
  'source /opt/start.sh && cd /workspace && IncNavierStokesSolver base_flow_PIN.xml'
```

## Publish On GitHub

Create a GitHub repository, push this folder to `main`, then GitHub Actions will publish:

```text
ghcr.io/<your-github-user-or-org>/nektar-viv:latest
ghcr.io/<your-github-user-or-org>/nektar-viv:5.9.0-viv
```

The workflow is in `.github/workflows/container.yml`.

## Apptainer/Singularity

After the GHCR image exists:

```bash
apptainer pull docker://ghcr.io/<your-github-user-or-org>/nektar-viv:latest
```

Or edit `mvapich.def` and replace `YOUR_GITHUB_USERNAME`.

## Notes

The Dockerfile currently builds the `IncNavierStokesSolver` target and copies the build-tree `dist` folder into the runtime image. This keeps the image focused on the flexible-cylinder VIV workflow. If you need all Nektar++ solvers, change the build command in `Dockerfile` from:

```bash
cmake --build /build/nektar --target IncNavierStokesSolver
```

to:

```bash
cmake --build /build/nektar
```
