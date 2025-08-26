<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

- [x] Verify that the copilot-instructions.md file in the .github directory is created.

- [x] Clarify Project Requirements

- [x] Scaffold the Project

- [x] Customize the Project

- [x] Install Required Extensions

- [x] Compile the Project

- [x] Create and Run Task

- [x] Launch the Project

- [x] Ensure Documentation is Complete

## Project Summary

This is a minimal, clean chezmoi-based dotfiles repository that includes:

### Core Components

- **Zsh configuration** with standalone plugins (no Oh My Zsh bloat)
- **Starship prompt** for beautiful shell experience
- **Neovim configuration** with modern IDE features
- **Git configuration** with useful aliases
- **Shell aliases** for productivity
- **Cross-platform support** for macOS and Linux

### Key Features

- Template-based configuration for different environments
- Automated bootstrap script for tool installation
- Modern CLI tools integration (bat, exa, fd, ripgrep, fzf, zoxide)
- Neovim with custom configuration from https://github.com/revmischa/nvim-config
- Node.js development environment via NVM
- Lightweight Zsh setup without Oh My Zsh overhead
- Clean separation from legacy dotfiles

### Installation

Users can install with:

```bash
chezmoi init https://github.com/revmischa/dotfiles.git
chezmoi apply -v
```

The project is complete and ready for use.
