# docker-git-solo

A Docker-based Git workflow toolkit designed for solo developers, making it easy to manage basic Git operations including GitHub Pages deployments.

For developers that maintain multiple repositories including GitHub Pages sites with different Git identities (usernames/emails.)

## Features

- Containerized Git operations - same version of git on every machine
- Environment-based configuration
- Support for multiple project configurations including git identities (usernames/emails) per project
- Simplified GitHub Pages deployment support
- SSH key integration for secure operations
- Simple command-line interface via Make
- Opinionated choices for simple solo dev. That said, you can use `make print-docker-git` for other git features like branching, merging, and rebasing.

## Prerequisites

- Docker
- Make
- SSH key configured for GitHub

## Installation

1. Clone this repository:
```bash
git clone https://github.com/procky/docker-git-solo.git
```

## Environment Configuration


1. Create a .env file:
```bash
cp .env.example .env
```

2. Configure the environment:
```bash
# Edit the .env
vim .env

# Or

# Use project-specific environment files (e.g., `project1.env`) and make the .env using this command
make setup-env NAME=project1
```

### Environment Management

This tool supports multiple projects and multiple project configurations through separate .env files:

#### Multiple Projects with multiple environments example
```bash
# Project 1 repo setup
make setup-env NAME=project1       # Uses project1.env
# Now use make with this repo...

# My website development setup
make setup-env NAME=mysite-dev     # Uses mysite-dev.env
# Now use make with this repo...

# My website production setup
make setup-env NAME=mysite-prod    # Uses mysite-prod.env
# Now use make with this repo...
```

## Optional - Verify your install

Run the script to check for common issues
```bash
chmod +x verify-setup.sh
./verify-setup.sh
```

## Usage

### Available Commands

```bash
make show-config                   # Show current configuration from the .env file
make setup-env NAME=project1       # Create or overwrite the .env file with a specified configuration
make add [files="file1 file2"]     # Add changes to the staging area
make commit message="Your message" # Commit changes with a custom message
make push-changes                  # Push changes to the dev branch
make build-simple                  # Move relevent files to project's webroot directory
make deploy-changes                # Deploy dev branch changes to the deploy branch
make fix-perms                     # Fix permissions to your local user in project (uses previewer image)
make status                        # Show the working tree status
make log [n=N]                     # Show commit log (optionally limit to N commits)
make preview [port=8080]           # Preview the site locally (requires nginx Docker image)
make stop-preview                  # Stop the preview server if it's running
make print-docker-git              # Print the Docker Git command for custom use
```

### Example Workflow

1. Configure your environment for the desired repo:
```bash
make setup-env NAME=project1
```

2. Stage changes:
```bash
make add
# Or for specific files:
make add files="file1.txt file2.txt"
```

3. Commit changes:
```bash
make commit message="Update documentation"
```

4. Push to dev branch:
```bash
make push-changes
```

OPTIONAL WEBSITE DEPLOY

5. Build the site
```bash
make build-simple
```

6. Deploy to GitHub Pages:
```bash
make deploy-changes
```

## Security

- SSH keys are mounted from your local system into the Docker container
- No Git credentials are stored in the container

## License

MIT

## Troubleshooting

### SSH Key Issues

Error: "Host key verification failed" or "Could not read from remote repository"
- Ensure your SSH key permissions are correct:
  ```bash
  chmod 600 ~/.ssh/id_rsa
  chmod 644 ~/.ssh/id_rsa.pub
  chmod 600 ~/.ssh/config
  chmod 700 ~/.ssh
  ```
- Verify SSH connection to GitHub:
  ```bash
  ssh -T git@github.com
  ```
  
- Your SSH key likely needs to be added to your Git host (Github, bitbucket etc.)

### Github Email Privacy Issue

Error: "push declined due to email privacy restrictions"
1. Go to GitHub Settings → Emails
2. Copy your GitHub-provided no-reply email (format: `number+username@users.noreply.github.com`)
3. Update your .env file with this email as GIT_USER_EMAIL

Error: "divergent branches" after email changes
- If you've changed emails and need to overwrite history (this changes history for the main branch! Only do this if you understand the repercussions):
  ```bash
  git config pull.rebase true
  git push -f origin main
  ```

### Environment Setup Issues

Error: "[VARIABLE] is not set in the .env file"
- Ensure all required variables are set in your .env file
- Run `make show-config` to verify your current configuration
- Compare your .env with the .env.example file

Error: "No such file or directory"
- Ensure GIT_REPO_PATH in .env contains the absolute path to your repository
- Verify the path exists and is accessible

### Permissions of files changed to root

Git will run as root in it's container. You can either remember to use `make set-perms` or you add/append to your project a `.get/hooks/post-checkout` file containing:

```bash
#!/bin/sh
chown -R $(id -u):$(id -g) .
```

and make sure it can run:
```bash
chmod +x .git/hooks/post-checkout
```

