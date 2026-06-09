FROM ubuntu:22.04 AS builder

LABEL org.opencontainers.image.title="Nektar++ VIV container"
LABEL org.opencontainers.image.description="Nektar++ 5.9.0 with patched MovingBody forcing for flexible-cylinder VIV"
LABEL org.opencontainers.image.source="https://github.com/jianxunz/nektar-viv-container"

ARG DEBIAN_FRONTEND=noninteractive
ARG NEKTAR_REF=v5.9.0
ARG NEKTAR_SOURCE_URL=https://gitlab.nektar.info/nektar/nektar/-/archive/${NEKTAR_REF}/nektar-${NEKTAR_REF}.tar.gz
ARG BUILD_JOBS=2

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        git \
        patch \
        python3 \
        build-essential \
        bison \
        flex \
        gfortran \
        tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q -nc --no-check-certificate -P /var/tmp \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh && \
    bash /var/tmp/Miniforge3-Linux-x86_64.sh -b -p /opt/conda && \
    rm /var/tmp/Miniforge3-Linux-x86_64.sh

SHELL ["/bin/bash", "-lc"]

ENV TZ="Europe/Oslo"
ENV PATH="/opt/conda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/conda/lib:${LD_LIBRARY_PATH}"
ENV BOOST_ROOT=/opt/conda
ENV Boost_ROOT=/opt/conda
ENV BOOST_INCLUDEDIR=/opt/conda/include
ENV BOOST_LIBRARYDIR=/opt/conda/lib
ENV FFTW_HOME=/opt/conda

RUN . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    mamba install -y -c conda-forge \
        blas \
        "boost-cpp>=1.71,<1.85" \
        "cmake>=3.24,<3.30" \
        fftw \
        libblas \
        liblapack \
        mvapich=4.1 \
        tinyxml \
        vim \
        zlib && \
    conda clean -afy

WORKDIR /src
RUN mkdir -p /src/nektar && \
    wget -q -O /tmp/nektar.tar.gz "${NEKTAR_SOURCE_URL}" && \
    tar -xf /tmp/nektar.tar.gz --strip-components=1 -C /src/nektar && \
    rm /tmp/nektar.tar.gz

COPY scripts/patch_moving_body.py /tmp/patch_moving_body.py
RUN python3 /tmp/patch_moving_body.py /src/nektar

RUN . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    command -v cmake && \
    command -v mpicc && \
    command -v mpicxx && \
    command -v gfortran && \
    cmake -S /src/nektar -B /build/nektar \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/nektar \
        -DCMAKE_PREFIX_PATH=/opt/conda \
        -DBOOST_ROOT=/opt/conda \
        -DBoost_ROOT=/opt/conda \
        -DBoost_NO_SYSTEM_PATHS=ON \
        -DBoost_NO_WARN_NEW_VERSIONS=ON \
        -DFFTW_INCLUDE_DIR=/opt/conda/include \
        -DFFTW_LIBRARY=/opt/conda/lib/libfftw3.so \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_CXX_COMPILER=mpicxx \
        -DCMAKE_Fortran_COMPILER=gfortran \
        -DNEKTAR_BUILD_TESTS=OFF \
        -DNEKTAR_BUILD_DEMOS=OFF \
        -DNEKTAR_BUILD_DOC=OFF \
        -DNEKTAR_BUILD_UNIT_TESTS=OFF \
        -DNEKTAR_BUILD_UTILITIES=OFF \
        -DNEKTAR_SOLVER_ACOUSTIC=OFF \
        -DNEKTAR_SOLVER_ADR=OFF \
        -DNEKTAR_SOLVER_CARDIAC_EP=OFF \
        -DNEKTAR_SOLVER_COMPRESSIBLE_FLOW=OFF \
        -DNEKTAR_SOLVER_DIFFUSION=OFF \
        -DNEKTAR_SOLVER_DUMMY=OFF \
        -DNEKTAR_SOLVER_ELASTICITY=OFF \
        -DNEKTAR_SOLVER_INCNAVIERSTOKES=ON \
        -DNEKTAR_SOLVER_MMF=OFF \
        -DNEKTAR_SOLVER_PULSEWAVE=OFF \
        -DNEKTAR_SOLVER_REVIEWSOLUTION=OFF \
        -DNEKTAR_SOLVER_SHALLOW_WATER=OFF \
        -DNEKTAR_USE_MPI=ON \
        -DNEKTAR_USE_HDF5=OFF \
        -DNEKTAR_USE_SCOTCH=ON \
        -DTHIRDPARTY_BUILD_SCOTCH=ON \
        -DNEKTAR_USE_FFTW=ON || \
    (echo "===== CMakeOutput.log ====="; \
     cat /build/nektar/CMakeFiles/CMakeOutput.log 2>/dev/null || true; \
     echo "===== CMakeError.log ====="; \
     cat /build/nektar/CMakeFiles/CMakeError.log 2>/dev/null || true; \
     false)

RUN . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    cmake --build /build/nektar --target install -j "${BUILD_JOBS}"

FROM ubuntu:22.04

LABEL org.opencontainers.image.title="Nektar++ VIV container"
LABEL org.opencontainers.image.description="Nektar++ 5.9.0 with patched MovingBody forcing for flexible-cylinder VIV"
LABEL org.opencontainers.image.source="https://github.com/jianxunz/nektar-viv-container"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        bash \
        vim-tiny \
        libgfortran5 \
        libgomp1 \
        libstdc++6 \
        tzdata && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/nektar /opt/nektar
COPY scripts/start.sh /opt/start.sh
COPY scripts/check_nektar_viv.sh /opt/check_nektar_viv.sh

ENV TZ="Europe/Oslo"
ENV NEKTAR_HOME=/opt/nektar
ENV PATH=/opt/nektar/bin:/opt/conda/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/nektar/lib:/opt/conda/lib:${LD_LIBRARY_PATH}
RUN chmod +x /opt/start.sh /opt/check_nektar_viv.sh && \
    /opt/check_nektar_viv.sh

WORKDIR /workspace

ENTRYPOINT ["/bin/bash", "-lc"]
CMD ["source /opt/start.sh && IncNavierStokesSolver --help"]
