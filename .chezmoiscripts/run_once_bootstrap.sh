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

# Install package manager
install_package_manager() {
    if [[ "$OS" == "macos" ]]; then
        if ! command_exists brew; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Add Homebrew to PATH for Apple Silicon Macs
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi

            log_success "Homebrew installed"
        else
            log_info "Homebrew already installed"
        fi
    elif [[ "$OS" == "linux" ]]; then
        # Update package lists
        if command_exists apt-get; then
            log_info "Updating apt packages..."
            sudo apt-get update -y
        elif command_exists yum; then
            log_info "Updating yum packages..."
            sudo yum update -y
        fi

        # Install Linuxbrew if not in a container
        if [[ ! "$REMOTE_CONTAINERS" ]] && ! command_exists brew; then
            log_info "Installing Linuxbrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Add Linuxbrew to PATH
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

            log_success "Linuxbrew installed"
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
            "exa"
            "zoxide"
            "git-delta"
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
        if command_exists apt-get; then
            local packages=(
                "git"
                "curl"
                "wget"
                "zsh"
                "neovim"
                "build-essential"
                "unzip"
            )

            for package in "${packages[@]}"; do
                if dpkg -l | grep -q "^ii  $package "; then
                    log_info "$package already installed"
                else
                    log_info "Installing $package..."
                    sudo apt-get install -y "$package"
                fi
            done
        fi

        # Install modern tools via brew if available, otherwise manual install
        if command_exists brew; then
            local brew_packages=(
                "neovim"
                "starship"
                "fzf"
                "ripgrep"
                "fd"
                "bat"
                "exa"
                "zoxide"
                "git-delta"
            )

            for package in "${brew_packages[@]}"; do
                if brew list "$package" >/dev/null 2>&1; then
                    log_info "$package already installed"
                else
                    log_info "Installing $package..."
                    brew install "$package"
                fi
            done
        else
            # Manual installation of starship
            if ! command_exists starship; then
                log_info "Installing Starship manually..."
                curl -sS https://starship.rs/install.sh | sh -s -- --yes
                log_success "Starship installed"
            fi
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
        if ! grep -q "$(which zsh)" /etc/shells; then
            echo "$(which zsh)" | sudo tee -a /etc/shells
        fi

        # Change default shell
        chsh -s "$(which zsh)"
        log_success "Zsh set as default shell (restart terminal to take effect)"
    else
        log_info "Zsh is already the default shell"
    fi
}

# Main installation
main() {
    log_info "Starting dotfiles bootstrap..."

    install_package_manager
    install_essentials
    install_zsh_plugins
    install_neovim_config
    install_nodejs
    set_zsh_default

    log_success "Bootstrap completed successfully!"
    log_info "Please restart your terminal or run: source ~/.zshrc"
}

# Run main function
main "$@"
