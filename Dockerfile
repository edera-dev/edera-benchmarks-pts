# ---- builder: compile everything here ----
FROM nvcr.io/nvidia/cuda:13.1.1-devel-ubuntu24.04 AS edera-benchmarks-dev

ENV HOME=/opt/pts-home
RUN mkdir -p ${HOME} /opt/pts-results

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y \
        apt-file \
        autoconf \
        automake \
        bc \
        bison \
        build-essential \
        ca-certificates \
        clinfo \
        cmake \
        fftw-dev \
        flex \
        gfortran \
        git \
        libaio-dev \
        libapparmor-dev \
        libatlas-base-dev \
        libblas-dev \
        libdw-dev \
        libelf-dev \
        libfftw3-dev \
        libglew-dev \
        libglut-dev \
        libjpeg8-dev \
        libjpeg-turbo8-dev \
        liblapack-dev \
        libmpich-dev \
        libnuma-dev \
        libopenblas-dev \
        libopenmpi-dev \
        libperl-dev \
        libslang2-dev \
        libssl-dev \
        libvulkan-dev \
        lz4 \
        mesa-opencl-icd \
        mesa-utils \
        meson \
        ncdu \
        ninja-build \
        numactl \
        ocl-icd-libopencl1 \
        ocl-icd-opencl-dev \
        opencl-headers \
        openmpi-bin \
        php-cli \
        php-gd \
        php-xml \
        php-zip \
        pkg-config \
        pocl-opencl-icd \
        python-dev-is-python3 \
        python-is-python3 \
        spirv-tools \
        tini \
        unzip \
        vim-nox \
        vulkan-tools \
        xorg-dev \
        xvfb \
        xz-utils \
        zstd

# Divert llvmpipe ICD so we don't use it for Vulkan tests
RUN dpkg-divert \
    --add \
    --rename \
    --divert /usr/share/vulkan/icd.d/lvp_icd.json.disabled \
    /usr/share/vulkan/icd.d/lvp_icd.json

# Pin to a tag or commit for reproducibility
# TODO: Add a tag (e.g. 'v10.8.6-edera') once we have our test definitions sorted out.
ARG PTS_REF=v10.8.4-edera
RUN git clone --depth 1 --branch ${PTS_REF} https://github.com/tycho/phoronix-test-suite.git /opt/pts && \
    cd /opt/pts && \
    ./install-sh && \
    command -v phoronix-test-suite

# Copy in a known-good phoronix-test-suite.xml generated via
# `phoronix-test-suite batch-setup` (with auto-upload = n, no browser, etc.)
COPY phoronix-test-suite.xml /etc/phoronix-test-suite.xml

# Entrypoint wrapping phoronix-test-suite in xvfb-run
COPY --chmod=755 entrypoint /entrypoint

# Conservative defaults (no “agreement” interruptions, disables anonymous reporting, etc.)
RUN phoronix-test-suite enterprise-setup

# Cache OpenBenchmarking metadata for offline use
RUN mkdir -p /usr/share/phoronix-test-suite/ob-cache && \
    cp -R /opt/pts/ob-cache/. /usr/share/phoronix-test-suite/ob-cache/.

# Install + build the tests
RUN xvfb-run phoronix-test-suite batch-install \
    pts/cachebench \
    pts/clpeak \
    pts/compress-zstd \
    local/fio-2.2.0 \
    pts/fs-mark \
    local/hammerdb-postgresql-1.1.1 \
    pts/hpcc \
    local/juliagpu-1.3.1 \
    local/mandelgpu-1.3.1 \
    pts/mbw \
    local/nginx-3.0.1 \
    pts/openssl \
    local/perf-bench-1.1.0 \
    local/pgbench-1.17.0 \
    pts/redis \
    pts/sqlite \
    local/stream-1.3.4 \
    pts/stress-ng \
    pts/sysbench \
    pts/tinymembench \
    pts/vkfft \
    local/vkpeak-1.3.0 \
    pts/xsbench-cl \
    && rm -rf \
        /var/lib/phoronix-test-suite/installed-tests/pts/openssl-*/openssl-*/{fuzz,test} \
        /var/lib/phoronix-test-suite/installed-tests/pts/nginx-*/wrk-*/obj

# Create download cache from the now-downloaded assets (and can prefetch for named suites)
RUN phoronix-test-suite make-download-cache \
    pts/cachebench \
    pts/clpeak \
    pts/compress-zstd \
    local/fio-2.2.0 \
    pts/fs-mark \
    local/hammerdb-postgresql-1.1.1 \
    pts/hpcc \
    local/juliagpu-1.3.1 \
    local/mandelgpu-1.3.1 \
    pts/mbw \
    local/nginx-3.0.1 \
    pts/openssl \
    local/perf-bench-1.1.0 \
    local/pgbench-1.17.0 \
    pts/redis \
    pts/sqlite \
    local/stream-1.3.4 \
    pts/stress-ng \
    pts/sysbench \
    pts/tinymembench \
    pts/vkfft \
    local/vkpeak-1.3.0 \
    pts/xsbench-cl


# ---- runtime: small image; just run the already-built tests ----
FROM nvcr.io/nvidia/cuda:13.1.1-runtime-ubuntu24.04 AS edera-benchmarks

ENV HOME=/opt/pts-home
RUN mkdir -p ${HOME} /opt/pts-results

ENV DEBIAN_FRONTEND=noninteractive

# Minimal runtime deps:
# - PTS is PHP
# - many tests need OpenCL loader, Vulkan loader/tools, MPI runtime, etc.
# - vim and ncdu included for debugging purposes
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y \
        bc \
        ca-certificates \
        clinfo \
        libaio1t64 \
        libapparmor1 \
        libatlas3-base \
        libblas3 \
        libdw1t64 \
        libelf1t64 \
        libfftw3-bin \
        libglew2.2 \
        libglut3.12 \
        libjpeg8 \
        libjpeg-turbo8 \
        liblapack3 \
        libmpich12 \
        libnuma1 \
        libopenblas0 \
        libopenmpi3t64 \
        libslang2 \
        libssl3t64 \
        libvulkan1 \
        lz4 \
        mesa-utils \
        mesa-opencl-icd \
        numactl \
        ocl-icd-libopencl1 \
        ncdu \
        openmpi-bin \
        php-cli \
        php-gd \
        php-xml \
        php-zip \
        pocl-opencl-icd \
        python-is-python3 \
        spirv-tools \
        tini \
        unzip \
        libvulkan1 \
        vim-nox \
        vulkan-tools \
        xvfb \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Divert llvmpipe ICD so we don't use it for Vulkan tests
RUN dpkg-divert \
    --add \
    --rename \
    --divert /usr/share/vulkan/icd.d/lvp_icd.json.disabled \
    /usr/share/vulkan/icd.d/lvp_icd.json

# Bring over PTS installation + installed tests/assets + config/entrypoint
COPY --from=edera-benchmarks-dev /usr/bin/phoronix-test-suite /usr/bin/phoronix-test-suite
COPY --from=edera-benchmarks-dev /usr/share/phoronix-test-suite /usr/share/phoronix-test-suite
COPY --from=edera-benchmarks-dev /var/lib/phoronix-test-suite /var/lib/phoronix-test-suite
COPY --from=edera-benchmarks-dev /entrypoint /entrypoint

# Copy in our no-internet config
COPY phoronix-test-suite-nonet.xml /etc/phoronix-test-suite.xml

# Runtime: no prompts
ENV PTS_SILENT_MODE=1

# Enable support for NVIDIA container runtime
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Run benchmarks anywhere from 11 to 17 times to get a clear box-and-whisker
# plot from the data
ENV FORCE_ABSOLUTE_MIN_TIMES_TO_RUN=11
ENV FORCE_ABSOLUTE_MAX_TIMES_TO_RUN=17

WORKDIR /opt/pts-results
ENTRYPOINT ["/entrypoint"]

# vim: set ts=4 sts=4 sw=4 et:
