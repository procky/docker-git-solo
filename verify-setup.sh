#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for issues found
ISSUES=0

echo "🔍 Verifying docker-git-solo setup..."
echo

# Check if Docker is installed
echo "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker first:"
    echo "  - Linux: https://docs.docker.com/engine/install/"
    echo "  - macOS: https://docs.docker.com/desktop/mac/install/"
    echo "  - Windows: https://docs.docker.com/desktop/windows/install/"
    ISSUES=$((ISSUES + 1))
else
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker daemon is not running${NC}"
        echo "Please start Docker and try again"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✅ Docker is installed and running${NC}"
    fi
fi

# Check if Make is installed
echo -e "\nChecking Make installation..."
if ! command -v make &> /dev/null; then
    echo -e "${RED}❌ Make is not installed${NC}"
    echo "Please install Make:"
    echo "  - Linux: sudo apt-get install make"
    echo "  - macOS: xcode-select --install"
    echo "  - Windows: Install through chocolatey: choco install make"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ Make is installed${NC}"
fi

# Check if Git image can be pulled
echo -e "\nChecking Git Docker image..."
if ! docker pull alpine/git:latest &> /dev/null; then
    echo -e "${RED}❌ Cannot pull Git Docker image${NC}"
    echo "Please check your internet connection and Docker hub access"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ Git Docker image is available${NC}"
fi

# Check SSH setup
echo -e "\nChecking SSH setup..."
if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "${RED}❌ SSH key not found${NC}"
    echo "Please generate an SSH key:"
    echo "  ssh-keygen -t rsa -b 4096 -C \"your_email@example.com\""
    ISSUES=$((ISSUES + 1))
else
    # Check SSH key permissions
    SSH_PERMS=$(stat -c %a ~/.ssh/id_rsa 2>/dev/null || stat -f %Lp ~/.ssh/id_rsa)
    if [ "$SSH_PERMS" != "600" ]; then
        echo -e "${YELLOW}⚠️  SSH key permissions are incorrect${NC}"
        echo "Please run: chmod 600 ~/.ssh/id_rsa"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✅ SSH key setup looks good${NC}"
    fi
fi

# Check .env file
echo -e "\nChecking environment configuration..."
if [ ! -f .env ]; then
    echo -e "${RED}❌ No .env file found${NC}"
    echo "Please create a .env file with required variables:"
    echo "  GIT_REPO_PATH"
    echo "  GIT_REPO_URL"
    echo "  GIT_DEV_BRANCH"
    echo "  DEPLOY_BRANCH"
    echo "  BUILD_PATH"
    echo "  WEB_ROOT"
    echo "  GIT_USER_NAME"
    echo "  GIT_USER_EMAIL"
    echo "  LOGGING_ENABLED"
    ISSUES=$((ISSUES + 1))
else
    # Create array of required variables
    declare -a required_vars=("GIT_REPO_PATH" "GIT_REPO_URL" "GIT_DEV_BRANCH" "DEPLOY_BRANCH" "BUILD_PATH" "WEB_ROOT" "GIT_USER_NAME" "GIT_USER_EMAIL" "LOGGING_ENABLED")
    declare -a missing_vars=()
    
    # Check each required variable
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required variables in .env:${NC}"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✅ Environment configuration looks good${NC}"
    fi
fi

if [ -f .env ]; then
    # Parse the .env file
    eval $(cat .env | grep -v '^#' | grep -v '^$' | sed 's/^/export /')
    
    echo -e "\nChecking Git branches..."
    docker run --rm -v "${GIT_REPO_PATH}:/repo" \
        -v "$HOME/.ssh/id_rsa:/root/.ssh/id_rsa" \
        -v "$HOME/.ssh/known_hosts:/root/.ssh/known_hosts" \
        -w /repo alpine/git:latest -c safe.directory=/repo fetch origin "${GIT_DEV_BRANCH}:${GIT_DEV_BRANCH}";
    if ! docker run --rm -v "${GIT_REPO_PATH}:/repo" \
        -v "$HOME/.ssh/id_rsa:/root/.ssh/id_rsa" \
        -v "$HOME/.ssh/known_hosts:/root/.ssh/known_hosts" \
        -w /repo alpine/git:latest -c safe.directory=/repo rev-parse --verify refs/heads/"${GIT_DEV_BRANCH}"; then
        echo -e "${YELLOW}⚠️  Development branch '${GIT_DEV_BRANCH}' not found${NC}"
        echo "To create it, run:"
        echo "  git checkout -b ${GIT_DEV_BRANCH}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✅ Development branch exists${NC}"
    fi
    
    docker run --rm -v "${GIT_REPO_PATH}:/repo" \
        -v "$HOME/.ssh/id_rsa:/root/.ssh/id_rsa" \
        -v "$HOME/.ssh/known_hosts:/root/.ssh/known_hosts" \
        -w /repo alpine/git:latest -c safe.directory=/repo fetch origin "${DEPLOY_BRANCH}:${DEPLOY_BRANCH}";
    if ! docker run --rm -v "${GIT_REPO_PATH}:/repo" \
        -v "$HOME/.ssh/id_rsa:/root/.ssh/id_rsa" \
        -v "$HOME/.ssh/known_hosts:/root/.ssh/known_hosts" \
        -w /repo alpine/git:latest -c safe.directory=/repo rev-parse --verify refs/heads/"${DEPLOY_BRANCH}"; then
        echo -e "${YELLOW}⚠️  Deployment branch '${DEPLOY_BRANCH}' not found${NC}"
        echo "To create it, run:"
        echo "  git checkout -b ${DEPLOY_BRANCH}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✅ Deployment branch exists${NC}"
    fi
fi

echo -e "\n📋 Summary:"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Your setup is ready to use.${NC}"
else
    echo -e "${RED}❌ Found $ISSUES issue(s) that need to be resolved.${NC}"
    exit 1
fi
