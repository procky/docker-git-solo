# docker-git-solo
# Makefile that simplifies managing git repositories (including Github Pages websites) with multiple git identities using Docker and a .env file

# Load variables from .env
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Docker Git CLI image
GIT_CLI_IMAGE := alpine/git:latest

# Variables from .env
GIT_REPO_PATH := $(GIT_REPO_PATH)
GIT_REPO_URL := $(GIT_REPO_URL)
GIT_DEV_BRANCH := $(GIT_DEV_BRANCH)
DEPLOY_BRANCH := $(DEPLOY_BRANCH)
GIT_USER_NAME := $(GIT_USER_NAME)
GIT_USER_EMAIL := $(GIT_USER_EMAIL)
# Convert LOGGING_ENABLED to proper boolean
# This handles various truthy values like "true", "1", "yes", "on" (case insensitive)
LOGGING_ENABLED := $(shell echo $(LOGGING_ENABLED) | tr '[:upper:]' '[:lower:]' | grep -E '^(true|1|yes|on)$$' > /dev/null && echo true || echo false)

# Log file location (only used if logging is enabled)
LOG_FILE ?= build.log

# Optional website variables
BUILD_PATH ?= .
WEB_ROOT ?= .
PREVIEW_PORT ?= 8080

# Ensure required variables are set
ifndef GIT_REPO_PATH
$(error GIT_REPO_PATH is not set in the .env file)
endif
ifndef GIT_REPO_URL
$(error GIT_REPO_URL is not set in the .env file)
endif
ifndef GIT_DEV_BRANCH
$(error GIT_DEV_BRANCH is not set in the .env file)
endif
ifndef DEPLOY_BRANCH
$(error DEPLOY_BRANCH is not set in the .env file)
endif
ifndef GIT_USER_NAME
$(error GIT_USER_NAME is not set in the .env file)
endif
ifndef GIT_USER_EMAIL
$(error GIT_USER_EMAIL is not set in the .env file)
endif

# Logging function
define log
	@echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $(1)"
	@if [ "${LOGGING_ENABLED}" = "true" ]; then \
		echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $(1)" >> ${LOG_FILE}; \
	fi
endef

# Default target
.PHONY: all
all: help

# Help target
.PHONY: help
help:
	@echo "Available commands:"
	@grep -E '^# Command: ' $(MAKEFILE_LIST) | sed 's/# Command: //'

# Command to run Git using Docker
DOCKER_GIT := docker run --rm -v $(GIT_REPO_PATH):/repo -v $${HOME}/.ssh/id_rsa:/root/.ssh/id_rsa -v $${HOME}/.ssh/known_hosts:/root/.ssh/known_hosts -w /repo $(GIT_CLI_IMAGE) -c user.name="$(GIT_USER_NAME)" -c user.email="$(GIT_USER_EMAIL)"

# Command to check if directory is empty (excluding .git* files)
check_dir_empty = \
	if [ -z "$$(find $(1) -type f ! -name '.git*' -print -quit)" ]; then \
		echo "Error: $(1) is empty or contains only .git* files"; \
		exit 1; \
	fi

# Show configuration details
# Command: make show-config - Show current configuration from the .env file
.PHONY: show-config
show-config:
	@echo "Configuration Details:"
	@echo "  GIT_REPO_PATH: $(GIT_REPO_PATH)"
	@echo "  GIT_REPO_URL: $(GIT_REPO_URL)"
	@echo "  GIT_DEV_BRANCH: $(GIT_DEV_BRANCH)"
	@echo "  DEPLOY_BRANCH: $(DEPLOY_BRANCH)"
	@echo "  GIT_USER_NAME: $(GIT_USER_NAME)"
	@echo "  GIT_USER_EMAIL: $(GIT_USER_EMAIL)"
	@echo "  LOGGING_ENABLED: $(LOGGING_ENABLED)"

# Setup environment file
# Command: make setup-env NAME=project1 - Create or overwrite the .env file with a specified configuration
.PHONY: setup-env
setup-env:
	@if [ -z "$(NAME)" ]; then \
		echo "Error: NAME parameter is required (e.g., make setup-env NAME=project1)"; \
		exit 1; \
	fi
	@if [ -f .env ]; then \
		read -p ".env file exists. Overwrite with $(NAME).env? [y/N] " CONFIRM; \
		if [ "$$CONFIRM" != "y" ]; then \
			echo "Aborted."; \
			exit 1; \
		fi; \
	fi
	@if [ -f $(NAME).env ]; then \
		cp $(NAME).env .env; \
		echo "Environment set up using $(NAME).env."; \
	else \
		echo "Error: $(NAME).env does not exist."; \
		exit 1; \
	fi

# Add changes to staging area
# Command: make add [files="file1 file2"] - Add changes to the staging area
.PHONY: add
add:
	$(DOCKER_GIT) -c safe.directory=/repo add $(if $(files),$(files),.)
	@echo "Staged changes: $(if $(files),$(files),all files)"

# Commit changes with a custom message
# Command: make commit message="Your message" - Commit changes with a custom message
.PHONY: commit
commit:
	@if [ -z "$(message)" ]; then \
		echo "Error: message parameter is required (e.g., make commit message=\"Your message\")"; \
		exit 1; \
	fi
	$(DOCKER_GIT) -c safe.directory=/repo commit -m "$(message)"
	@echo "Committed changes with message: $(message)"

# Push changes to the dev branch
# Command: make push-changes - Push changes to the dev branch
.PHONY: push-changes
push-changes:
	$(call log,"Pushing changes to $(GIT_DEV_BRANCH)")
	$(DOCKER_GIT) -c safe.directory=/repo push $(GIT_REPO_URL) HEAD:$(GIT_DEV_BRANCH)
	$(call log,"Push completed")

# Build web files into project's web root directory for deployment
# Command: Make build-simple - move relevent files to project's webroot directory
.PHONY: build-simple
build-simple:
	$(call log,"Copy all files in .deployinclude in $(BUILD_PATH)")
	$(call log, "Building site into $(WEB_ROOT)")
	mkdir -p $(WEB_ROOT)  # Ensure webroot directory exists
	rsync -av --include-from='$(BUILD_PATH)/.deployinclude' --exclude='*' $(BUILD_PATH)/ $(WEB_ROOT) --delete
	$(call log, "Build complete")

# Deploy dev branch changes to the deploy branch
# Command: make deploy-changes - Deploy dev branch /dist to the deploy branch
.PHONY: deploy-changes
deploy-changes:
	$(call log,"Pushing changes to $(DEPLOY_BRANCH)")
	$(DOCKER_GIT) -c safe.directory=/repo checkout $(GIT_DEV_BRANCH)  # ensure we start from dev branch
	$(DOCKER_GIT) -c safe.directory=/repo checkout -B $(DEPLOY_BRANCH)  # create/switch to deploy branch
	$(DOCKER_GIT) -c safe.directory=/repo rm -r --cached .  # clear git cache
	$(DOCKER_GIT) -c safe.directory=/repo --git-dir=/repo/.git --work-tree=/repo/dist add .  # add contents of dist at root
	$(DOCKER_GIT) -c safe.directory=/repo commit -m "Deploy website to root of $(DEPLOY_BRANCH)"
	$(DOCKER_GIT) -c safe.directory=/repo push -f $(GIT_REPO_URL) $(DEPLOY_BRANCH)
	$(DOCKER_GIT) -c safe.directory=/repo clean -fd  # clean untracked files and directories
	$(DOCKER_GIT) -c safe.directory=/repo clean -fd  # repeate for directory .gitkeep if present
	$(DOCKER_GIT) -c safe.directory=/repo checkout $(GIT_DEV_BRANCH)  # switch back to dev branch
	$(call log,"Deploy completed")
	
# Fix permissions to your local user in project (uses previewer image)
# Command: make fix-perms - Fix permissions to your local user in project (uses previewer image)
.PHONY: fix-perms
fix-perms:
	docker run --rm -v $(GIT_REPO_PATH):/repo nginx:alpine chown -R $(shell id -u):$(shell id -g) /repo 

# Show git status
# Command: make status - Show the working tree status
.PHONY: status
status:
	$(DOCKER_GIT) -c safe.directory=/repo status

# Show git log
# Command: make log [n=N] - Show commit log (optionally limit to N commits)
.PHONY: log
log:
	$(DOCKER_GIT) -c safe.directory=/repo log $(if $(n),--oneline -n $(n),--oneline -n 10)

# Command: make preview [port=8080] - Preview the site locally (requires nginx Docker image). Use 'make stop-preview' to stop if CTRL+C doesn't.
.PHONY: preview
preview:
	$(call log,"Checking web root directory...")
	$(call check_dir_empty,$(WEB_ROOT))
	@echo "Starting preview server on http://localhost:$(if $(port),$(port),$(PREVIEW_PORT))"
	@docker run --rm -d \
		-v $(WEB_ROOT):/usr/share/nginx/html:ro \
		-p $(if $(port),$(port),$(PREVIEW_PORT)):80 \
		--name git-solo-preview \
		nginx:alpine
	@echo "Started preview server on http://localhost:$(if $(port),$(port),$(PREVIEW_PORT))"
	@echo "Press Ctrl+C to stop"
	@trap 'docker stop git-solo-preview' INT; docker logs -f git-solo-preview || true

# Command: make stop-preview - Stop the preview server if it's running
.PHONY: stop-preview
stop-preview:
	@docker stop git-solo-preview 2>/dev/null || echo "Preview server not running"

# Print the Docker Git command for custom use
# Command: make print-docker-git - Print the Docker Git command for custom use
.PHONY: print-docker-git
print-docker-git:
	@echo "Copy this command and add your git commands at the end:"
	@echo ""
	@echo "docker run --rm -v $(GIT_REPO_PATH):/repo -v $${HOME}/.ssh/id_rsa:/root/.ssh/id_rsa -v $${HOME}/.ssh/known_hosts:/root/.ssh/known_hosts -w /repo $(GIT_CLI_IMAGE) -c user.name=\"$(GIT_USER_NAME)\" -c user.email=\"$(GIT_USER_EMAIL)\" -c safe.directory=/repo"
	@echo ""
	@echo "Example usage:"
	@echo "... status"
	@echo "... log --oneline"
	@echo "... branch -a"

# Clean up docker container (if necessary)
# Command: make clean - Clean up any temporary files (currently a placeholder)
.PHONY: clean
clean:
	@echo "No temporary files to clean."

