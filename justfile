# TRELLIS.2 setup (uv). Replaces setup.sh + conda.
# Usage: just setup
# Or install pieces: just new-env basic flash-attn nvdiffrast nvdiffrec cumesh o-voxel flexgemm

python_version := "3.10"
venv_dir := ".venv"
workdir := justfile_directory()

export VIRTUAL_ENV := workdir / venv_dir
export PATH := VIRTUAL_ENV / "bin" + ":" + env_var("PATH")

platform := `if command -v nvidia-smi >/dev/null 2>&1; then echo cuda; elif command -v rocminfo >/dev/null 2>&1; then echo hip; else echo none; fi`

default:
    @just --list

# Full install (same as former setup.sh with all flags)
setup: new-env basic flash-attn nvdiffrast nvdiffrec cumesh o-voxel flexgemm
    @echo "Done. Activate with: source {{venv_dir}}/bin/activate"

# Create a new uv virtualenv and install PyTorch
new-env:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{platform}}" == "none" ]]; then
        echo "Error: No supported GPU found (need nvidia-smi or rocminfo)"
        exit 1
    fi
    uv venv --python {{python_version}} "{{venv_dir}}"
    if [[ "{{platform}}" == "cuda" ]]; then
        uv pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124
    else
        uv pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/rocm6.2.4
    fi
    echo "Created {{venv_dir}}. Activate with: source {{venv_dir}}/bin/activate"

# Install basic Python dependencies
basic:
    #!/usr/bin/env bash
    set -euo pipefail
    just _require-venv
    uv pip install imageio imageio-ffmpeg tqdm easydict "opencv-python-headless>=4.10,<5" ninja trimesh "transformers>=4.56,<5.4" gradio==6.0.1 tensorboard pandas lpips zstandard
    uv pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo apt install -y libjpeg-dev
        uv pip install pillow-simd
    else
        echo "[BASIC] No sudo permission; skipping libjpeg-dev/pillow-simd, installing Pillow instead"
        uv pip install Pillow
    fi
    uv pip install kornia timm

# Install flash-attention
flash-attn:
    #!/usr/bin/env bash
    set -euo pipefail
    just _require-venv
    just _require-platform
    if [[ "{{platform}}" == "cuda" ]]; then
        uv pip install packaging ninja psutil
        uv pip install flash-attn==2.7.3 --no-build-isolation
    elif [[ "{{platform}}" == "hip" ]]; then
        echo "[FLASHATTN] Prebuilt binaries not found. Building from source..."
        mkdir -p /tmp/extensions
        if [[ ! -d /tmp/extensions/flash-attention ]]; then
            git clone --recursive https://github.com/ROCm/flash-attention.git /tmp/extensions/flash-attention
        fi
        cd /tmp/extensions/flash-attention
        git fetch --tags
        git checkout tags/v2.7.3-cktile
        uv pip install packaging ninja psutil
        GPU_ARCHS=gfx942 uv pip install . --no-build-isolation
        cd "{{workdir}}"
    else
        echo "[FLASHATTN] Unsupported platform: {{platform}}"
        exit 1
    fi

# Install nvdiffrast (CUDA only)
nvdiffrast:
    #!/usr/bin/env bash
    set -euo pipefail
    just _require-venv
    if [[ "{{platform}}" != "cuda" ]]; then
        echo "[NVDIFFRAST] Unsupported platform: {{platform}}"
        exit 1
    fi
    mkdir -p /tmp/extensions
    if [[ ! -d /tmp/extensions/nvdiffrast ]]; then
        git clone -b v0.4.0 https://github.com/NVlabs/nvdiffrast.git /tmp/extensions/nvdiffrast
    fi
    uv pip install /tmp/extensions/nvdiffrast --no-build-isolation

# Install nvdiffrec (CUDA only)
nvdiffrec:
    #!/usr/bin/env bash
    set -euo pipefail
    just _require-venv
    if [[ "{{platform}}" != "cuda" ]]; then
        echo "[NVDIFFREC] Unsupported platform: {{platform}}"
        exit 1
    fi
    mkdir -p /tmp/extensions
    if [[ ! -d /tmp/extensions/nvdiffrec ]]; then
        git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/extensions/nvdiffrec
    fi
    uv pip install /tmp/extensions/nvdiffrec --no-build-isolation

# Install CuMesh
cumesh:
    #!/usr/bin/env bash
    set -euo pipefail
    just _require-venv
    mkdir -p /tmp/extensions
    if [[ ! -d /tmp/extensions/CuMesh ]]; then
        git clone https://github.com/JeffreyXiang/CuMesh.git /tmp/extensions/CuMesh --recursive
    fi
    uv pip install /tmp/extensions/CuMesh --no-build-isolation

# Install FlexGEMM
flexgemm:
    #!/usr/bin/env bash
    set -euo pipefail
    just _require-venv
    mkdir -p /tmp/extensions
    if [[ ! -d /tmp/extensions/FlexGEMM ]]; then
        git clone https://github.com/JeffreyXiang/FlexGEMM.git /tmp/extensions/FlexGEMM --recursive
    fi
    uv pip install /tmp/extensions/FlexGEMM --no-build-isolation

# Install o-voxel (local package)
o-voxel:
    #!/usr/bin/env bash
    set -euo pipefail
    just _require-venv
    mkdir -p /tmp/extensions
    rm -rf /tmp/extensions/o-voxel
    cp -r o-voxel /tmp/extensions/o-voxel
    uv pip install /tmp/extensions/o-voxel --no-build-isolation

[private]
_require-venv:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -d "{{venv_dir}}" ]]; then
        echo "Error: {{venv_dir}} not found. Run 'just new-env' first."
        exit 1
    fi

[private]
_require-platform:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{platform}}" == "none" ]]; then
        echo "Error: No supported GPU found (need nvidia-smi or rocminfo)"
        exit 1
    fi
