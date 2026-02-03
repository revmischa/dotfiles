#!/bin/bash
# Bootstrap script for dotfiles setup
# This script is run by chezmoi to install dependencies and tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
OS=""
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    log_error "Unsupported OS: $OSTYPE"
    exit 1
fi

log_info "Detected OS: $OS"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Safe sudo - use sudo if available, otherwise run directly (for containers)
safe_sudo() {
    if command_exists sudo && sudo -n true 2>/dev/null; then
        # sudo is available and can run without password
        sudo "$@"
    elif [[ $EUID -eq 0 ]]; then
        # Running as root, no sudo needed
        "$@"
    elif command_exists sudo; then
        # sudo is available but may need password
        sudo "$@"
    else
        # No sudo available, try to run directly (might fail)
        log_warning "No sudo available, trying to run directly: $*"
        "$@"
    fi
}

# Check if we're in a devcontainer or similar environment
is_container() {
    [[ -n "$REMOTE_CONTAINERS" ]] || [[ -n "$CODESPACES" ]] || [[ -f "/.dockerenv" ]] || [[ -n "$DEVCONTAINER" ]]
}

# Check if we can install packages system-wide
can_install_packages() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    elif command_exists sudo && sudo -n true 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Install package manager
install_package_manager() {
    if [[ "$OS" == "macos" ]]; then
        if ! command_exists brew; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Add Homebrew to PATH for Apple Silicon Macs
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi

            log_success "Homebrew installed"
        else
            log_info "Homebrew already installed"
        fi
    elif [[ "$OS" == "linux" ]]; then
        # Skip system package installation if we don't have permissions
        if ! can_install_packages; then
            log_warning "Cannot install system packages without root/sudo access"
            log_info "Skipping system package installation - assuming they're already available"
        else
            # Update package lists only if we have permission
            if command_exists apt-get; then
                log_info "Updating apt packages..."
                if ! safe_sudo apt-get update -y; then
                    log_warning "Failed to update apt packages. Continuing anyway..."
                fi
            elif command_exists yum; then
                log_info "Updating yum packages..."
                if ! safe_sudo yum update -y; then
                    log_warning "Failed to update yum packages. Continuing anyway..."
                fi
            fi
        fi

    fi
}

# Install essential packages
install_essentials() {
    log_info "Installing essential packages..."

    if [[ "$OS" == "macos" ]]; then
        # macOS packages
        local packages=(
            "git"
            "curl"
            "wget"
            "zsh"
            "neovim"
            "starship"
            "fzf"
            "ripgrep"
            "fd"
            "bat"
            "eza"
            "zoxide"
            "git-delta"
            "lazygit"
        )

        for package in "${packages[@]}"; do
            if brew list "$package" >/dev/null 2>&1; then
                log_info "$package already installed"
            else
                log_info "Installing $package..."
                brew install "$package"
            fi
        done

    elif [[ "$OS" == "linux" ]]; then
        # Linux packages via system package manager
        if can_install_packages && command_exists apt-get; then
            local packages=(
                "git"
                "curl"
                "wget"
                "zsh"
                "neovim"
                "build-essential"
                "unzip"
                "zooxide"
                "eza"
                "ripgrep"
                "fzf"
                "bat"
                "lazygit"
            )

            for package in "${packages[@]}"; do
                if dpkg -l | grep -q "^ii  $package " 2>/dev/null; then
                    log_info "$package already installed"
                else
                    log_info "Installing $package..."
                    if ! safe_sudo apt-get install -y "$package"; then
                        log_warning "Failed to install $package. You may need to install it manually."
                    fi
                fi
            done
        elif ! can_install_packages; then
            log_info "Cannot install system packages - assuming essential tools are available"
            # Check if essential tools are available
            local essential=("git" "curl" "wget" "zsh")
            for tool in "${essential[@]}"; do
                if command_exists "$tool"; then
                    log_info "$tool is available"
                else
                    log_warning "$tool is not available - some features may not work"
                fi
            done
        fi

        # Manual installation of modern tools
        if ! command_exists starship; then
            log_info "Installing Starship manually..."
            # Create local bin directory
            mkdir -p "$HOME/.local/bin"

            # Install starship to user directory
            if can_install_packages; then
                curl -sS https://starship.rs/install.sh | sh -s -- --yes
            else
                log_info "Installing Starship to user directory..."
                curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir="$HOME/.local/bin" --yes
                # Ensure .local/bin is in PATH
                export PATH="$HOME/.local/bin:$PATH"
            fi
            log_success "Starship installed"
        fi
    fi
}

# Install Zsh plugins (without Oh My Zsh)
install_zsh_plugins() {
    local plugin_dir="$HOME/.zsh"
    mkdir -p "$plugin_dir"

    # zsh-autosuggestions
    if [[ ! -d "$plugin_dir/zsh-autosuggestions" ]]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
        log_success "zsh-autosuggestions installed"
    else
        log_info "zsh-autosuggestions already installed"
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$plugin_dir/zsh-syntax-highlighting" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir/zsh-syntax-highlighting"
        log_success "zsh-syntax-highlighting installed"
    else
        log_info "zsh-syntax-highlighting already installed"
    fi

    # zsh-history-substring-search
    if [[ ! -d "$plugin_dir/zsh-history-substring-search" ]]; then
        log_info "Installing zsh-history-substring-search..."
        git clone https://github.com/zsh-users/zsh-history-substring-search "$plugin_dir/zsh-history-substring-search"
        log_success "zsh-history-substring-search installed"
    else
        log_info "zsh-history-substring-search already installed"
    fi
}

# Clone Neovim configuration
install_neovim_config() {
    local nvim_config_dir="$HOME/.config/nvim"

    if [[ ! -d "$nvim_config_dir" ]]; then
        log_info "Cloning Neovim configuration..."
        git clone https://github.com/revmischa/nvim-config.git "$nvim_config_dir"
        log_success "Neovim configuration installed"
    else
        log_info "Neovim configuration already exists"
        log_warning "To update: cd ~/.config/nvim && git pull"
    fi
}

# Install Node.js via NVM
install_nodejs() {
    if [[ ! -d "$HOME/.nvm" ]]; then
        log_info "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

        # Source NVM
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

        # Install latest LTS Node.js
        nvm install --lts
        nvm use --lts

        log_success "NVM and Node.js installed"
    else
        log_info "NVM already installed"
    fi
}

# Set Zsh as default shell
set_zsh_default() {
    if [[ "$SHELL" != *"zsh"* ]]; then
        log_info "Setting Zsh as default shell..."

        # Add zsh to allowed shells if not present
        local zsh_path=$(which zsh)
        if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
            if echo "$zsh_path" | safe_sudo tee -a /etc/shells >/dev/null 2>&1; then
                log_info "Added $zsh_path to /etc/shells"
            else
                log_warning "Could not update /etc/shells. You may need to add $zsh_path manually."
            fi
        fi

        # Change default shell - try non-interactive first
        log_info "Attempting to change default shell to zsh..."
        if timeout 10s chsh -s "$zsh_path" </dev/null >/dev/null 2>&1; then
            log_success "Zsh set as default shell (restart terminal to take effect)"
        else
            log_warning "Could not change default shell automatically."
            log_info "To change manually, run: chsh -s $zsh_path"
            log_info "You may be prompted for your password."
        fi
    else
        log_info "Zsh is already the default shell"
    fi
}

# Main installation
main() {
    log_info "Starting dotfiles bootstrap..."

    # Check permissions
    if ! can_install_packages; then
        log_warning "Running without root/sudo access"
        log_info "Will install user-level tools only"
        log_info "System packages (git, curl, zsh, neovim) should be pre-installed or available"
    fi

    install_package_manager
    install_essentials
    install_zsh_plugins
    install_neovim_config
    install_nodejs
    set_zsh_default

    log_success "Bootstrap completed successfully!"
    if ! can_install_packages; then
        log_info "Note: Some system packages may need to be installed manually with appropriate permissions"
    fi
    log_info "Please restart your terminal or run: source ~/.zshrc"
}

# Run main function
main "$@"
