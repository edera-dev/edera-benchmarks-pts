# Edera Protect – Benchmarks Container

## Overview

This container image provides a **fixed, reproducible set of benchmarks** used
to track performance characteristics of **Edera Protect** over time. The
primary goal is to make performance changes *measurable*, *comparable*, and
*repeatable* as the Edera Protect runtime evolves.

All benchmarks included in the image are installed at **known, pinned
versions** at image build time. When the container is executed, no network
access is required, and no benchmark payloads are downloaded or rebuilt. This
eliminates a large class of noise and drift that typically makes long‑term
performance tracking unreliable.

## Why This Image Exists

Performance regressions are often subtle, cumulative, and easy to miss without
consistent baselines. This image exists to address several common failure
modes:

* **Regression detection** – Catch performance regressions early as changes are
  made to Edera Protect.
* **Baseline drift control** – Avoid changes caused by updated benchmark
  versions, new test data, or OS package updates.
* **Repeatability** – Ensure that a benchmark run today is directly comparable
  to one from weeks or months ago.
* **Isolation** – Remove network dependencies and external state from benchmark
  execution.

By freezing both the benchmark versions and their build artifacts inside the
container image, results are attributable to *runtime changes*, not
environmental churn.

## Runtime Comparison Use Case

In addition to tracking Edera Protect internally, this image is designed to
make **cross‑runtime comparisons** straightforward.

Because the container:

* requires **no network configuration**, and
* performs all setup work at image build time,

it can be executed under a wide variety of container runtimes with minimal
friction, including:

* `runc`
* `runsc` (gVisor)
* `kata`
* Edera Protect
* other OCI‑compatible runtimes

This is particularly useful for runtimes such as Kata Containers, where
networking and guest configuration can be more complex. The benchmarks can be
run in fully isolated environments without needing additional runtime plumbing.

## Benchmark Selection Philosophy

Only benchmarks that are **reasonably sized** and suitable for **frequent
execution** are included. Extremely large benchmarks (e.g. full media encoders
or large rendering workloads) are intentionally excluded to keep image size
manageable and execution time bounded.

The included benchmarks provide coverage across:

* CPU compute and algorithmic performance
* Memory bandwidth and latency
* System call and scheduler behavior
* Filesystem and storage performance ("scratch" workloads)
* GPU compute workloads

The intent is to maximize **signal‑to‑size**: tests that meaningfully
differentiate container runtimes without inflating the image to tens of
gigabytes.

## Phoronix Test Suite Focus

This revision of the image is focused specifically on **Phoronix Test Suite
(PTS)** benchmarks.

PTS is used because:

* Benchmarks are **strongly versioned** and self‑contained.
* Test definitions are independent of distribution packaging.
* Results are comparable across systems and over time.

While OS‑level dependencies are still provided by the base image, the
**benchmarks themselves are locked** to the versions dictated by the PTS
release used to build the image. This prevents silent behavior changes caused
by updated test code.

## GPU Benchmark Support

The container includes **`xvfb`** to allow GPU benchmarks to run in headless
environments.

The container entrypoint automatically wraps `phoronix-test-suite` with
`xvfb-run`, so GPU benchmarks that expect to create a window (e.g. OpenGL or
OpenCL workloads) can execute without a real X11 server.

This allows GPU tests to run consistently in CI, virtualized environments, and
minimal hosts.

## Usage

### Capturing Results

Phoronix Test Suite writes results to the container’s results directory. This
image is configured to use:

* `/opt/pts-results`

Mount a host directory at `/opt/pts-results` to persist results across
container runs. e.g. with Docker, use:

```bash
docker run ... -v ${PWD}/results:/opt/pts-results ...
```

### Running Benchmarks (Batch Mode)

Benchmarks are intended to be run via `batch-run` so that execution is
non-interactive and consistent across automated runs.

#### CPU benchmark example (results captured)

```bash
docker run --rm \
  -v ${PWD}/results:/opt/pts-results \
  -it edera-benchmarks:latest \
  batch-run pts/compress-zstd
```

#### GPU benchmark example (NVIDIA + OpenCL ICD passthrough, results captured)

This example runs an OpenCL GPU benchmark using Docker with NVIDIA GPU access.
It mounts the NVIDIA OpenCL ICD file into the container.

```bash
docker run --gpus all --rm \
  -v /etc/OpenCL/vendors/nvidia.icd:/etc/OpenCL/vendors/nvidia.icd \
  -v ${PWD}/results:/opt/pts-results \
  -it edera-benchmarks:latest \
  batch-run pts/mandelgpu
```

### Notes

* The container is intended to be run **without networking enabled** for
  reproducibility. Use `--network=none` where practical.
* GPU benchmarks run under `xvfb` automatically via the container entrypoint,
  so tests that expect to create a window should work in headless environments.
