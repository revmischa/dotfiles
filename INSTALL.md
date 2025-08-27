# Installation Guide

This guide will help you set up your new chezmoi-based dotfiles.

## Prerequisites

- Git
- curl or wget
- A Unix-like system (macOS, Linux, WSL)

## Installation

### 1. Install chezmoi

**macOS:**

```bash
brew install chezmoi
```

**Linux:**

```bash
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### 2. Initialize dotfiles

```bash
chezmoi init https://github.com/revmischa/dotfiles.git
```

### 3. Review changes (optional)

```bash
chezmoi diff
```

### 4. Apply dotfiles

```bash
chezmoi apply -v
```

This will:

- Install all configuration files
- Run the bootstrap script to install tools
- Set up Zsh with standalone plugins (no Oh My Zsh)
- Configure Starship prompt
- Clone and set up Neovim configuration
- Install development tools

### 5. Restart your shell

```bash
exec zsh
```

## What gets installed

- **Zsh** with standalone plugins (autosuggestions, syntax highlighting, history search)
- **Neovim** with custom configuration from your nvim-config repository
- **Starship** prompt
- **Modern CLI tools**: bat, eza, fd, ripgrep, fzf, zoxide
- **Node.js** via NVM
- **Git** configuration with useful aliases
- **Shell aliases** for productivity

## Customization

To edit your dotfiles:

```bash
# Edit zsh config
chezmoi edit ~/.zshrc

# Edit git config
chezmoi edit ~/.gitconfig

# Edit aliases
chezmoi edit ~/.aliases

# Apply changes
chezmoi apply
```

## Updating

To update your dotfiles:

```bash
chezmoi update
```

## Troubleshooting

If you encounter issues:

1. Check the bootstrap log for errors
2. Manually run: `~/.config/chezmoi/.chezmoiscripts/run_once_bootstrap.sh`
3. Ensure you have proper permissions for installation

## Uninstalling

To remove chezmoi and dotfiles:

```bash
chezmoi purge
```
