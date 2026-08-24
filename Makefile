.DEFAULT_GOAL := help
CLI := ./tf-importer
ENV ?=
ACCOUNT ?=
PROJECT ?= $(shell grep '^PROJECT_NAME=' config/environments.conf 2>/dev/null | cut -d'=' -f2)

.PHONY: help doctor validate version discover auto build split plan full pipeline test ci clean clean-all check-env

check-env:
ifeq ($(ENV),)
	$(error ENV is required. Usage: make full ENV=dev)
endif

help:
	@$(CLI)

doctor:
	@ACCOUNT="$(ACCOUNT)" $(CLI) doctor $(ENV)

validate:
	@$(CLI) validate

version:
	@$(CLI) version

discover: check-env
	@ACCOUNT="$(ACCOUNT)" $(CLI) discover $(ENV)

auto: check-env
	@ACCOUNT="$(ACCOUNT)" $(CLI) auto $(ENV)

split: check-env
	@ACCOUNT="$(ACCOUNT)" $(CLI) split $(ENV)

build: check-env
	@ACCOUNT="$(ACCOUNT)" $(CLI) build $(ENV)

full: check-env
	@ACCOUNT="$(ACCOUNT)" $(CLI) auto $(ENV)
	@ACCOUNT="$(ACCOUNT)" $(CLI) build $(ENV)

pipeline: check-env
	@ACCOUNT="$(ACCOUNT)" $(CLI) pipeline $(ENV)

plan: check-env
	@ACCOUNT="$(ACCOUNT)" $(CLI) plan $(ENV)

test:
	@python3 -m unittest discover -s tests -v

ci:
	@bash scripts/ci/validate.sh

clean:
	rm -rf logs/*
	rm -rf reports/*
	rm -rf output/*

clean-all: check-env clean
	rm -rf work/$(PROJECT)/$(if $(ACCOUNT),$(ACCOUNT)/,)$(ENV)
	@echo "WARNING: clean-all removed the environment directory and local state for $(if $(ACCOUNT),$(ACCOUNT)/,)$(ENV)."
