FROM ubuntu:22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG NEKTAR_REF=v5.9.0
ARG NEKTAR_SOURCE_URL=https://gitlab.nektar.info/nektar/nektar/-/archive/${NEKTAR_REF}/nektar-${NEKTAR_REF}.tar.gz
ARG BUILD_JOBS=4

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        git \
        patch \
        python3 \
        build-essential \
        cmake \
        gfortran \
        libboost-iostreams-dev \
        libboost-program-options-dev \
        libboost-system-dev \
        libfftw3-dev \
        libtinyxml-dev \
        libblas-dev \
        liblapack-dev \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN mkdir -p /src/nektar && \
    wget -q -O /tmp/nektar.tar.gz "${NEKTAR_SOURCE_URL}" && \
    tar -xf /tmp/nektar.tar.gz --strip-components=1 -C /src/nektar && \
    rm /tmp/nektar.tar.gz

COPY scripts/patch_moving_body.py /tmp/patch_moving_body.py
RUN python3 /tmp/patch_moving_body.py /src/nektar

RUN cmake -S /src/nektar -B /build/nektar \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/nektar \
        -DNEKTAR_BUILD_TESTS=OFF \
        -DNEKTAR_BUILD_DEMOS=OFF \
        -DNEKTAR_BUILD_DOC=OFF \
        -DNEKTAR_BUILD_UNIT_TESTS=OFF \
        -DNEKTAR_USE_MPI=OFF \
        -DNEKTAR_USE_HDF5=OFF \
        -DNEKTAR_USE_SCOTCH=OFF \
        -DNEKTAR_USE_FFT=ON && \
    cmake --build /build/nektar --target IncNavierStokesSolver -j "${BUILD_JOBS}" && \
    cmake --install /build/nektar

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        bash \
        vim-tiny \
        libgfortran5 \
        libgomp1 \
        libstdc++6 \
        libfftw3-3 \
        libtinyxml2.6.2v5 \
        libboost-iostreams1.74.0 \
        libboost-program-options1.74.0 \
        libboost-system1.74.0 \
        libblas3 \
        liblapack3 \
        zlib1g && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/nektar /opt/nektar
COPY scripts/start.sh /opt/start.sh

ENV NEKTAR_HOME=/opt/nektar
ENV PATH=/opt/nektar/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/nektar/lib:${LD_LIBRARY_PATH}
WORKDIR /workspace

ENTRYPOINT ["/bin/bash", "-lc"]
CMD ["source /opt/start.sh && IncNavierStokesSolver --help"]
