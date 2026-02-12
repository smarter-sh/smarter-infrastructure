SHELL := /bin/bash
include .env
export PATH := /usr/local/bin:$(PATH)
export

ifeq ($(OS),Windows_NT)
    PYTHON := python.exe
    ACTIVATE_VENV := venv\Scripts\activate
else
    PYTHON := python3.13
    ACTIVATE_VENV := source venv/bin/activate
endif
PIP := $(PYTHON) -m pip

ifneq ("$(wildcard .env)","")
else
    $(shell cp ./doc/example-dot-env .env)
endif

.PHONY: init clean lint analyze release pre-commit-init pre-commit-run python-init terraform-build terraform-clean

# Default target executed when no arguments are given to make.
all: help

# initialize local development environment.
# takes around 5 minutes to complete
init:
	make tear-down			# start w a clean environment
	make pre-commit-init	# install and configure pre-commit

clean:
	make terraform-clean


# ---------------------------------------------------------
# Code management
# ---------------------------------------------------------

lint:

analyze:
	cloc . --exclude-ext=svg,json,zip --fullpath --not-match-d=smarter/smarter/static/assets/ --vcs=git

pre-commit-init:
	$(PYTHON) -m venv venv && \
	$(ACTIVATE_VENV) && \
	$(PIP) install --upgrade pip && \
	$(PIP) install pre-commit && \
	npm install  && \
	pre-commit install && \
	pre-commit autoupdate && \
	pre-commit run --all-files

pre-commit-run:
	pre-commit run --all-files

release:
	git commit -m "fix: force a new release" --allow-empty && git push


# -------------------------------------------------------------------------
# AWS and deployment
# -------------------------------------------------------------------------
terraform-build:
	cd aws
	terraform init
	terraform apply

terraform-clean:
	find ./ -name .terragrunt-cache -type d -exec rm -rf {} +
	find ./ -name .terraform.lock.hcl -type f -exec rm {} +

terraform-lint:
	cd aws
	terraform fmt -recursive

######################
# HELP
######################

help:
	@echo '===================================================================='
	@echo 'init                   - Initialize local and Docker environments'
	@echo 'activate               - activates Python virtual environment'
	@echo 'build                  - Build Docker containers'
	@echo 'run                    - run web application from Docker'
	@echo 'clean                  - delete all local artifacts, virtual environment, node_modules, and Docker containers'
	@echo 'tear-down              - destroy all docker build and local artifacts'
	@echo '<************************** Code Management **************************>'
	@echo 'lint                   - Run all code linters and formatters'
	@echo 'analyze                - Generate code analysis report using cloc'
	@echo 'coverage               - Generate Docker-based code coverage analysis report'
	@echo 'pre-commit-init        - install and configure pre-commit'
	@echo 'pre-commit-run         - runs all pre-commit hooks on all files'
	@echo 'release                - Force a new Github release'
	@echo '<************************** AWS **************************>'
	@echo 'terraform-build        - Run Terraform to create AWS infrastructure'
	@echo 'terraform-clean        - Prune Terraform cache and lock files'
	@echo 'helm-update            - Update Helm chart dependencies'
	@echo '===================================================================='
