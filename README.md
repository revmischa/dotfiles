# Dotfiles

A minimal, clean dotfiles setup using [chezmoi](https://www.chezmoi.io/) for managing configuration files across macOS and Linux environments.

## What's Included

- **Zsh configuration** with modern shell enhancements (no Oh My Zsh bloat)
- **Starship prompt** for a beautiful, fast shell prompt
- **Neovim configuration** with modern IDE features
- **Git configuration** with useful aliases and settings
- **Shell aliases** for productivity
- **Cross-platform support** for macOS and Linux/devcontainers

## Quick Start

1. Install chezmoi:

   ```bash
   # macOS
   brew install chezmoi

   # Linux
   sh -c "$(curl -fsLS get.chezmoi.io)"
   ```

2. Initialize with this repository:

   ```bash
   chezmoi init https://github.com/revmischa/dotfiles.git
   ```

3. Review the changes:

   ```bash
   chezmoi diff
   ```

4. Apply the dotfiles:

   ```bash
   chezmoi apply -v
   ```

## What it does

- Sets up Zsh with standalone plugins (autosuggestions, syntax highlighting, history search)
- Installs and configures Starship prompt
- Clones and sets up Neovim configuration from https://github.com/revmischa/nvim-config
- Configures Git with useful aliases and settings
- Sets up shell aliases for common tasks
- Installs development tools and packages

## Customization

Edit files in the chezmoi source directory:

```bash
chezmoi edit ~/.zshrc
chezmoi edit ~/.gitconfig
```

Then apply changes:

```bash
chezmoi apply
```

## Platform Support

This setup automatically detects and configures for:

- macOS (with Homebrew)
- Linux (with apt/yum)
- Development containers

## Requirements

- Git
- curl or wget
- A shell (bash/zsh)
