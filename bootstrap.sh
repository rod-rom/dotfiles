#!/bin/bash

# Dotfiles Setup Script
# Downloads git-completion.bash and syncs dotfiles to home directory

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly COMPLETION_URL="https://raw.githubusercontent.com/git/git/refs/heads/master/contrib/completion/git-completion.bash"
readonly COMPLETION_FILE="$HOME/.git-completion.bash"
readonly BASHRC_FILE="$HOME/.bashrc"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print colored output functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Download git completion with better error handling
download_git_completion() {
    print_step "Setting up Git completion..."
    
    # Check if already exists and is recent (less than 30 days old)
    if [[ -f "$COMPLETION_FILE" ]]; then
        local file_age
        file_age=$(find "$COMPLETION_FILE" -mtime -30 2>/dev/null | wc -l)
        if [[ $file_age -gt 0 ]]; then
            print_status "Git completion file is recent, skipping download"
            return 0
        fi
    fi
    
    # Determine download command
    local download_cmd
    if command_exists curl; then
        download_cmd="curl -fsSL --connect-timeout 10 --max-time 30"
        print_status "Using curl for download"
    elif command_exists wget; then
        download_cmd="wget -q -T 30 -O -"
        print_status "Using wget for download"
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        return 1
    fi
    

    
    # Download with better error handling
    print_status "Downloading git-completion.bash to $COMPLETION_FILE..."
    if ! $download_cmd "$COMPLETION_URL" > "$COMPLETION_FILE.tmp"; then
        print_error "Failed to download git-completion.bash"
        rm -f "$COMPLETION_FILE.tmp"
        return 1
    fi
    
    # Verify download (basic check)
    if [[ ! -s "$COMPLETION_FILE.tmp" ]]; then
        print_error "Downloaded file is empty"
        rm -f "$COMPLETION_FILE.tmp"
        return 1
    fi
    
    # Move temp file to final location
    mv "$COMPLETION_FILE.tmp" "$COMPLETION_FILE"
    chmod 644 "$COMPLETION_FILE"
    print_status "Successfully downloaded git-completion.bash"
}

# Update git repository
update_repository() {
    print_step "Updating repository..."
    
    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        print_warning "Not in a git repository, skipping git pull"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    # Check if we have uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "Uncommitted changes detected, skipping git pull"
        return 0
    fi
    
    # Check if we can reach the remote
    if ! git ls-remote origin &>/dev/null; then
        print_warning "Cannot reach remote repository, skipping git pull"
        return 0
    fi
    
    if git pull origin "$(git branch --show-current)" --ff-only; then
        print_status "Repository updated successfully"
    else
        print_warning "Failed to update repository (continuing anyway)"
    fi
}

# Sync dotfiles
sync_dotfiles() {
    print_step "Syncing dotfiles..."
    
    # Check if rsync is available
    if ! command_exists rsync; then
        print_error "rsync is not available. Please install rsync."
        return 1
    fi
    
    # Verify we're in the right directory
    if [[ ! -f "$SCRIPT_DIR/bootstrap.sh" ]]; then
        print_error "Cannot find bootstrap.sh - are you in the dotfiles directory?"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    
    # Create list of files to be synced (for user confirmation)
    local files_to_sync
    files_to_sync=$(find . -maxdepth 1 -type f -name ".*" ! -name ".git*" ! -name ".DS_Store" | sort)
    
    if [[ -n "$files_to_sync" ]]; then
        print_status "Files to be synced:"
        echo "$files_to_sync" | sed 's|^\./|  |'
    fi
    
    # Perform the sync
    if rsync \
        --exclude ".git/" \
        --exclude ".gitignore" \
        --exclude ".DS_Store" \
        --exclude ".osx" \
        --exclude "bootstrap.sh" \
        --exclude "README.md" \
        --exclude "LICENSE*" \
        --archive \
        --verbose \
        --human-readable \
        --no-perms \
        --itemize-changes \
        . ~; then
        print_status "Dotfiles synced successfully"
    else
        print_error "Failed to sync dotfiles"
        return 1
    fi
}

# Source bash profile
source_bash_profile() {
    print_step "Sourcing bash profile..."
    
    # Temporarily disable unbound variable checking for sourcing user files
    # since dotfiles may reference variables that aren't set in this context
    set +u
    
    local sourced=false
    if [[ -f "$HOME/.bash_profile" ]]; then
        # shellcheck disable=SC1091
        if source "$HOME/.bash_profile" 2>/dev/null; then
            print_status "Bash profile sourced successfully"
            sourced=true
        else
            print_warning "Bash profile sourcing encountered errors (this is often normal)"
            sourced=true
        fi
    elif [[ -f "$HOME/.bashrc" ]]; then
        # shellcheck disable=SC1091
        if source "$HOME/.bashrc" 2>/dev/null; then
            print_status "Bashrc sourced successfully"
            sourced=true
        else
            print_warning "Bashrc sourcing encountered errors (this is often normal)"
            sourced=true
        fi
    fi
    
    if [[ "$sourced" == false ]]; then
        print_warning "No .bash_profile or .bashrc found to source"
    fi
    
    # Re-enable unbound variable checking
    set -u
}

# Main execution function
main() {
    print_status "Starting dotfiles setup..."
    
    # Download git completion
    if ! download_git_completion; then
        print_error "Failed to download git completion"
        exit 1
    fi
    
    # Update repository
    update_repository
    
    # Sync dotfiles with confirmation
    if [[ "${1:-}" == "--force" ]] || [[ "${1:-}" == "-f" ]]; then
        print_status "Force mode enabled, skipping confirmation"
        if ! sync_dotfiles; then
            exit 1
        fi
    else
        echo
        print_warning "This may overwrite existing files in your home directory."
        read -p "Are you sure you want to continue? (y/N) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! sync_dotfiles; then
                exit 1
            fi
        else
            print_status "Sync cancelled by user"
            exit 0
        fi
    fi
    
    # Source bash profile
    source_bash_profile
    
    print_status "Setup completed successfully!"
    echo
    print_status "You may want to restart your terminal or run 'source ~/.bash_profile' to apply changes"
}

# Show help
show_help() {
    cat << EOF
Dotfiles Setup Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -f, --force     Skip confirmation prompt
    -h, --help      Show this help message

DESCRIPTION:
    This script downloads git-completion.bash and syncs dotfiles from the current
    directory to your home directory. It will ask for confirmation before 
    overwriting existing files unless --force is used.

EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -f|--force)
        main "$@"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac