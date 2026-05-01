# engineai_amp helper Makefile
#
# Usage:
#   make help
#   make convert SRC=/path/to/source.npz [NAME=output_basename]
#   make train-ppo [RUN_NAME=...] [NUM_ENVS=...] [MAX_ITERATIONS=...]
#   make train-amp [RUN_NAME=...] [MOTION=path/to/file.npz] [NUM_ENVS=...] [MAX_ITERATIONS=...]
#   make play-ppo  RUN_NAME=...  [NUM_ENVS=...]
#   make play-amp  RUN_NAME=...  [NUM_ENVS=...]

REPO_ROOT := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
DATA_DIR  := $(REPO_ROOT)dataset/data
PYTHON    := $(REPO_ROOT)venv/bin/python
NAME      ?= $(basename $(notdir $(SRC)))

# Training defaults
NUM_ENVS       ?= 4096
RUN_NAME       ?= test
MAX_ITERATIONS ?=
MOTION         ?=

# Optional flag fragments built from the variables above.
# Empty MOTION/MAX_ITERATIONS means the flag is omitted entirely (script uses its own default).
MOTION_FLAG    := $(if $(MOTION),--motion-file $(MOTION))
MAX_ITER_FLAG  := $(if $(MAX_ITERATIONS),--max_iterations $(MAX_ITERATIONS))

.PHONY: help convert train-ppo train-amp play-ppo play-amp

help:
	@echo "engineai_amp helper targets"
	@echo ""
	@echo "Data:"
	@echo "  make convert SRC=/path/to/source.npz [NAME=basename]"
	@echo "      Trim a unitree-style 24-DOF PM01 motion file to the 23-DOF schema."
	@echo "      Output lands at dataset/data/<NAME>.npz."
	@echo ""
	@echo "Training (defaults: NUM_ENVS=$(NUM_ENVS), RUN_NAME=$(RUN_NAME)):"
	@echo "  make train-ppo [RUN_NAME=...] [NUM_ENVS=...] [MAX_ITERATIONS=...]"
	@echo "      Pure PPO velocity-tracking on Flat-PM01-v0."
	@echo ""
	@echo "  make train-amp [RUN_NAME=...] [MOTION=...] [NUM_ENVS=...] [MAX_ITERATIONS=...]"
	@echo "      PPO+AMP on Flat-AMP-PM01-v0. MOTION accepts .npz, .yaml manifest, or a folder."
	@echo "      Omit MOTION to use the default agent_cfg.dataset_path (dataset/config/dataset.yaml)."
	@echo ""
	@echo "Rollout:"
	@echo "  make play-ppo RUN_NAME=<run_folder> [NUM_ENVS=16]"
	@echo "  make play-amp RUN_NAME=<run_folder> [NUM_ENVS=16]"
	@echo "      RUN_NAME here must be a folder name under logs/rsl_rl/<exp>/."

convert:
ifndef SRC
	$(error SRC is required. Run 'make help' for usage.)
endif
	@$(PYTHON) $(REPO_ROOT)scripts/convert_npz.py "$(SRC)" "$(DATA_DIR)/$(NAME).npz"
	@echo ""
	@echo "To use this clip with AMP, train via:"
	@echo "  make train-amp MOTION=dataset/data/$(NAME).npz RUN_NAME=$(NAME)"

train-ppo:
	$(PYTHON) $(REPO_ROOT)scripts/train.py \
		--task=Flat-PM01-v0 \
		--num_envs $(NUM_ENVS) --headless \
		--run_name $(RUN_NAME) \
		$(MAX_ITER_FLAG)

train-amp:
	$(PYTHON) $(REPO_ROOT)scripts/train.py \
		--task=Flat-AMP-PM01-v0 \
		--num_envs $(NUM_ENVS) --headless \
		--run_name $(RUN_NAME) \
		$(MOTION_FLAG) \
		$(MAX_ITER_FLAG)

play-ppo:
	$(PYTHON) $(REPO_ROOT)scripts/play.py \
		--task=Flat-PM01-v0 \
		--num_envs $(NUM_ENVS) \
		--load_run $(RUN_NAME)

play-amp:
	$(PYTHON) $(REPO_ROOT)scripts/play.py \
		--task=Flat-AMP-PM01-v0 \
		--num_envs $(NUM_ENVS) \
		--load_run $(RUN_NAME)
