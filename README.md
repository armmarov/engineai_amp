# EngineAI-Lab

**EngineAI Lab** is a python package for training and deploying policies for EngineAI Robots using Isaac Lab and Isaac Sim.

# Structure

```
engineai-lab
├── config
├── dataset
│   ├── config
│   └── data
├── scripts
└── source
    └── engineai_lab
        ├── algorithms      
        ├── assets
        │   └── pm01
        │       ├── meshes
        │       └── urdf
        ├── robots
        ├── tasks
        │   └── velocity
        │       ├── config
        │       │   └── pm01
        │       └── mdp
        └── utils
```

## QUICKSTART

### 1. Create a Conda Environment

Create and activate a new environment with Python 3.11:

  ```bash
  conda create -n engineai_lab python=3.11
  conda activate engineai_lab
  ```

### 2. Install Prerequisites

- **Install Isaac Sim**

  Follow the official installation guide: [Isaac Lab - Pip Installation](https://isaac-sim.github.io/IsaacLab/main/source/setup/installation/pip_installation.html#installing-dependencies).

    *Since you've already created the engineai_lab environment, follow the guide from "Installing Dependencies" up to (but not including) the "Installing Isaac Lab" section.*

- **Clone & Setup Isaac Lab**

  Clone the repository and switch to the recommended branch:

  ```bash
  git clone https://github.com/isaac-sim/IsaacLab.git
  cd IsaacLab
  git checkout 4df6560e
  ./isaaclab -i rsl_rl   # Install rsl-rl dependency
  ```

We highly recommend using the main branch`(4df6560e)` of Isaac Lab, as it can support rsl-rl-lib >= 5.0 and Isaac Sim >= 5.0 .

### 3. Install this Package

Once the prerequisites are set up, install the package in editable mode:

```bash
pip install -e .
```

## Usage

### Supported Robots

This repository currently supports the following environments from the EngineAI Robots family:

|Robot| Task |Description|
|--------|--------|--------|
PM01|`Flat-PM01-v0`|Basic flat-terrain locomotion
PM01|`Flat-AMP-PM01-v0`|AMP-based motion imitation on flat terrain

*More robots and environments are coming soon!*

### Training a Policy

```
 python scripts/train.py --task=Flat-PM01-v0  --num_envs 4096 --headless --run_name <name>  
 python scripts/play.py  --task=Flat-PM01-v0 --num_envs 128 --load_run <name> 
```

### Evaluating a Policy

```
 python scripts/train.py --task=Flat-AMP-PM01-v0  --num_envs 4096 --headless --run_name <name> 
 python scripts/play.py --task=Flat-AMP-PM01-v0 --num_envs 128 --load_run <name>
```

Replace `<name>` with the name of your training run (found in logs/rsl_rl/).

### Makefile shortcuts

A `Makefile` at the repo root wraps the most common training/rollout invocations. Run `make help` to see everything.

| Command | What it does |
|---|---|
| `make train-ppo RUN_NAME=<name>` | Pure PPO velocity-tracking on `Flat-PM01-v0`. |
| `make train-amp RUN_NAME=<name> [MOTION=<path>]` | PPO+AMP on `Flat-AMP-PM01-v0`. Picks the AMP reference from `MOTION` (`.npz`, `.yaml` manifest, or directory). Falls back to `dataset/config/dataset.yaml` when omitted. |
| `make play-ppo RUN_NAME=<run_folder>` | Replay a PPO checkpoint. `RUN_NAME` here is the timestamped folder under `logs/rsl_rl/<exp>/`. |
| `make play-amp RUN_NAME=<run_folder>` | Replay an AMP checkpoint. |

Common overrides: `NUM_ENVS=2048`, `MAX_ITERATIONS=5000`. Examples:

```bash
# Train PPO+AMP using a specific running motion
make train-amp MOTION=dataset/data/accad_male2_run.npz RUN_NAME=run-001

# Train pure PPO with a shorter run for a quick smoke test
make train-ppo RUN_NAME=ppo-smoke MAX_ITERATIONS=1500

# Roll out the trained AMP policy
make play-amp RUN_NAME=2026-04-30_15-35-23_run-001 NUM_ENVS=16
```

The Makefile uses `venv/bin/python`. If your interpreter lives elsewhere, run `PYTHON=/path/to/python make ...` to override.

### Custom AMP motion data

AMP training picks reference motions from `dataset/config/dataset.yaml` (the default) or any `--motion-file` you pass at the CLI. Each `.npz` must follow the PM01 schema below:

| Key | Shape | Required | Notes |
|---|---|---|---|
| `fps` | `(1,)` int64 | yes | Sampling rate of the clip. |
| `joint_pos` | `(N, 23)` float32 | **yes** | 23-DOF PM01 joint positions, ordered as `PM_WAIST_DFS_JOINT_NAMES` in `source/engineai_lab/robots/pm01.py`. |
| `joint_vel` | `(N, 23)` float32 | **yes** | Matching joint velocities. |
| `body_pos_w`, `body_quat_w`, `body_lin_vel_w`, `body_ang_vel_w` | `(N, 24, …)` float32 | optional | Present in the shipped reference; not used by the AMP discriminator today. |

To add a new motion to the AMP corpus:

1. **Drop a compatible `.npz` into `dataset/data/`** (or convert one — see below).
2. **Train with it** by passing `--motion-file` (or `MOTION=…` via the Makefile). Or list it in `dataset/config/dataset.yaml` to make it the new default.

#### Converting unitree-style PM01 motions

`unitree_rl_mjlab` ships PM01 motions in a 24-DOF schema (it includes a head joint). Use `make convert` to trim them to this repo's 23-DOF schema:

```bash
make convert SRC=/path/to/unitree_rl_mjlab/src/assets/motions/pm01/some_motion.npz
# → dataset/data/some_motion.npz
```

Optionally override the output basename:

```bash
make convert SRC=/path/to/long_filename.npz NAME=my_clip
# → dataset/data/my_clip.npz
```

Once converted, plug the file into AMP training:

```bash
make train-amp MOTION=dataset/data/some_motion.npz RUN_NAME=some_motion-001
```

### Deployment

To deploy a trained policy on real hardware, convert it to the MNN format for efficient inference.

#### 1. Export PyTorch Policy to ONNX

(Ensure your training script supports ONNX export)

#### 2. Build [MNN-Converter](https://mnn-docs.readthedocs.io/en/latest/start/quickstart_cpp.html?highlight=mnn+converter)

```bash
git clone https://github.com/alibaba/mnn
cd mnn
mkdir build && cd build
cmake .. -DMNN_BUILD_CONVERTER=ON
make -j8
```

#### 3. Convert ONNX into MNN

```bash
./MNNConvert -f ONNX \
  --modelFile path_to_your_policy.onnx \
  --MNNModel your_policy.mnn \
  --bizCode MNN
```

For detailed instructions on integrating the MNN model with EngineAI robots, see:
[engineai_robotics_native_sdk](https://github.com/engineai-robotics/engineai_robotics_native_sdk).

## Support

If you have any questions about using this repository, we're here to help!

- **Report Issues**: Found a bug or have a feature request. Please open a new issue on our [GitHub Issues](https://github.com/engineai-robotics/engineai_lab/issues) page.
- **Email Us**: For general inquiries or collaboration opportunities, feel free to reach out at [info@engineai.com.cn](mailto:info@engineai.com.cn).

## License

EngineAI-Lab is released under [BSD-3 License](LICENSE).

## Acknowledgement

This repository is built upon the support and contributions of the following open-source projects. Special thanks to:

- [**IsaacLab**](https://github.com/isaac-sim/IsaacLab) — The foundational framework for training and running simulation experiments.
- [**rsl_rl**](https://github.com/leggedrobotics/rsl_rl) — High-performance reinforcement learning library for legged robots.
- [**AMP_for_hardware**](https://github.com/escontra/AMP_for_hardware) — Implementation of Adversarial Motion Priors (AMP) for sim-to-real transfer.
- [**BeyondMimic**](https://github.com/HybridRobotics/whole_body_tracking) — Inspiration for project structure and valuable feature implementations.
- [**MNN**](https://github.com/alibaba/mnn) — Lightweight, high-performance inference engine for on-device deployment.
- [**engineai_robotics_native_sdk**](https://github.com/engineai-robotics/engineai_robotics_native_sdk) — Official SDK for deploying policies on EngineAI robotic hardware.
