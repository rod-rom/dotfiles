#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# File paths
COMPLETION_URL="https://raw.githubusercontent.com/git/git/refs/heads/master/contrib/completion/git-completion.bash"
PROMPT_URL="https://raw.githubusercontent.com/mathiasbynens/dotfiles/refs/heads/main/.bash_prompt"
COMPLETION_FILE="$HOME/.git-completion.bash"
PROMPT_FILE="$HOME/.bash-prompt"
BASHRC_FILE="$HOME/.bashrc"
COMPLETION_SOURCE_LINE="source ~/.git-completion.bash"
PROMPT_SOURCE_LINE="source ~/.bash-prompt"

print_status "Starting Git completion and prompt setup..."

# Check if curl or wget is available
if command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -fsSL"
    print_status "Using curl for download"
elif command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -q -O -"
    print_status "Using wget for download"
else
    print_error "Neither curl nor wget is available. Please install one of them."
    exit 1
fi

# Download git-completion.bash
print_status "Downloading git-completion.bash to $COMPLETION_FILE..."
if $DOWNLOAD_CMD "$COMPLETION_URL" > "$COMPLETION_FILE"; then
    print_status "Successfully downloaded git-completion.bash"
else
    print_error "Failed to download git-completion.bash"
    exit 1
fi

# Download git-prompt.sh
print_status "Downloading .bash_prompt to $PROMPT_FILE..."
if $DOWNLOAD_CMD "$PROMPT_URL" > "$PROMPT_FILE"; then
    print_status "Successfully downloaded .bash_prompt"
else
    print_error "Failed to download .bash_prompt"
    exit 1
fi

# Check if .bashrc exists
if [ ! -f "$BASHRC_FILE" ]; then
    print_warning ".bashrc not found. Creating a new one..."
    touch "$BASHRC_FILE"
fi

# Check if the source lines already exist in .bashrc
COMPLETION_EXISTS=$(grep -Fxq "$COMPLETION_SOURCE_LINE" "$BASHRC_FILE" && echo "true" || echo "false")
PROMPT_EXISTS=$(grep -Fxq "$PROMPT_SOURCE_LINE" "$BASHRC_FILE" && echo "true" || echo "false")

if [ "$COMPLETION_EXISTS" = "true" ] && [ "$PROMPT_EXISTS" = "true" ]; then
    print_warning "Both git completion and prompt are already configured in .bashrc"
else
    # Add the source lines to .bashrc
    print_status "Adding source lines to .bashrc..."
    echo "" >> "$BASHRC_FILE"
    echo "# Git completion and prompt" >> "$BASHRC_FILE"
    
    if [ "$COMPLETION_EXISTS" = "false" ]; then
        echo "$COMPLETION_SOURCE_LINE" >> "$BASHRC_FILE"
        print_status "Added git completion to .bashrc"
    else
        print_warning "Git completion already configured, skipping..."
    fi
    
    if [ "$PROMPT_EXISTS" = "false" ]; then
        echo "$PROMPT_SOURCE_LINE" >> "$BASHRC_FILE"
        print_status "Added bash prompt to .bashrc"
    else
        print_warning "Bash prompt already configured, skipping..."
    fi
fi

# Verify the downloaded files
if [ -f "$COMPLETION_FILE" ] && [ -s "$COMPLETION_FILE" ] && [ -f "$PROMPT_FILE" ] && [ -s "$PROMPT_FILE" ]; then
    print_status "Git completion file is ready at $COMPLETION_FILE"
    print_status "Bash prompt file is ready at $PROMPT_FILE"
else
    print_error "Something went wrong with the downloads"
    exit 1
fi

print_status "Setup complete!"
echo ""
echo "To activate git completion and prompt in your current session, run:"
echo "  source ~/.bashrc"
echo ""
echo "Or simply open a new terminal window."
echo ""
echo "After activation, you'll have:"
echo "  - Tab completion for git commands (git che<TAB> → git checkout)"
echo "  - Tab completion for branch names (git checkout <TAB>)"
echo "  - Tab completion for remote names, tags, and more!"
echo "  - Git status in your prompt (showing current branch, dirty state, etc.)"
echo ""
