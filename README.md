# Dotfiles

A minimal, clean dotfiles setup using [chezmoi](https://www.chezmoi.io/) for managing configuration files across macOS and Linux environments.

## What's Included

- **Zsh configuration** with [antidote](https://github.com/mattmc3/antidote) plugin manager
- **Comprehensive completions** for npm, pnpm, pip, uv, AWS CLI, Docker, kubectl, and more
- **Starship prompt** for a beautiful, fast shell prompt
- **[Neovim configuration](https://github.com/revmischa/nvim-config)** with modern IDE features
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

5. Install a [Nerd Font](https://www.nerdfonts.com/font-downloads) and use it in your terminal
   
   This gives you some icons.

## What it does

- Sets up Zsh with antidote plugin manager for fast, reliable plugin loading
- Installs comprehensive shell completions for development tools:
  - **Node.js ecosystem**: npm, pnpm, nvm
  - **Python ecosystem**: pip, uv
  - **Cloud tools**: AWS CLI, kubectl
  - **Containers**: Docker, Docker Compose
  - **Development**: cargo, terraform, git
- Installs and configures Starship prompt
- Clones and sets up Neovim configuration from https://github.com/revmischa/nvim-config
- Configures Git with useful aliases and settings
- Sets up shell aliases for common tasks
- Installs development tools and packages

## Plugin Management

This setup uses [antidote](https://github.com/mattmc3/antidote) for zsh plugin management, which provides:

- **Fast startup times** with static plugin loading
- **Automatic plugin updates** when `.zsh_plugins.txt` changes
- **No bloat** - only loads what you need
- **Easy customization** - just edit `.zsh_plugins.txt`

### Adding New Plugins

To add new plugins, edit the `.zsh_plugins.txt` file:

```bash
chezmoi edit ~/.zsh_plugins.txt
```

Then apply the changes:

```bash
chezmoi apply
# Restart your shell or run: source ~/.zshrc
```

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
