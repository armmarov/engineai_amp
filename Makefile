# engineai_amp helper Makefile
#
# Usage:
#   make convert SRC=/path/to/source.npz [NAME=output_basename]

REPO_ROOT := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
DATA_DIR  := $(REPO_ROOT)dataset/data
PYTHON    := $(REPO_ROOT)venv/bin/python
NAME      ?= $(basename $(notdir $(SRC)))

.PHONY: help convert

help:
	@echo "engineai_amp helper targets"
	@echo ""
	@echo "  make convert SRC=/path/to/source.npz [NAME=basename]"
	@echo "      Trim a unitree-style 24-DOF PM01 motion file to engineai_amp's"
	@echo "      23-DOF schema. Output lands at dataset/data/<NAME>.npz."
	@echo "      NAME defaults to the source filename without extension."

convert:
ifndef SRC
	$(error SRC is required. Run 'make help' for usage.)
endif
	@$(PYTHON) $(REPO_ROOT)scripts/convert_npz.py "$(SRC)" "$(DATA_DIR)/$(NAME).npz"
	@echo ""
	@echo "To use this clip, add to dataset/config/dataset.yaml:"
	@echo "  - file: ../data/$(NAME).npz"
