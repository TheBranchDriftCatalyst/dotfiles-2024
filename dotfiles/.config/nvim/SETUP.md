# 🔥 Cyberpunk NvChad Development Environment

## 🎯 Overview
This is a comprehensive Neovim configuration built on NvChad with a cyberpunk aesthetic, optimized for Go, Python, and Ansible development.

## 🎨 Theme & Aesthetics
- **Primary Theme**: [2077.nvim](https://github.com/akai54/2077.nvim) - Cyberpunk 2077 inspired
- **UI Enhancements**: Custom notifications, dressing, and cyberpunk color scheme
- **Visual Style**: Neon colors, dark backgrounds, futuristic appearance

## 📦 Installed Plugins

### 🎨 Theme & UI
- `akai54/2077.nvim` - Cyberpunk 2077 theme
- `rcarriga/nvim-notify` - Enhanced notifications
- `stevearc/dressing.nvim` - Better UI elements

### 📚 Beginner Tools
- `folke/which-key.nvim` - Discover keybindings as you type
- `sudormrfbin/cheatsheet.nvim` - Built-in cheatsheet (:Cheatsheet)
- `m4xshen/hardtime.nvim` - Learn better Vim habits
- `folke/flash.nvim` - Fast navigation with 2-character search

### 🐹 Go Development
- `ray-x/go.nvim` - Comprehensive Go tooling
- `yanskun/gotests.nvim` - Generate Go tests
- `romus204/go-tagger.nvim` - Manage struct tags
- **Language Server**: gopls with enhanced configuration

### 🐍 Python/Ansible
- `mfussenegger/nvim-ansible` - Ansible support
- `pearofducks/ansible-vim` - Ansible syntax
- `linux-cultist/venv-selector.nvim` - Python virtual environment management
- **Language Servers**: pylsp, ansiblels, yamlls

### 📝 Language Support
- `nvim-treesitter/nvim-treesitter` - Enhanced syntax highlighting
- **Language Servers**:
  - gopls (Go)
  - pylsp (Python)
  - ansiblels (Ansible)
  - yamlls (YAML)
  - jsonls (JSON)
  - bashls (Bash)
  - tsserver (TypeScript/JavaScript)
  - marksman (Markdown)

### 🚀 Development Tools
- `NeogitOrg/neogit` - Git interface
- `akinsho/toggleterm.nvim` - Terminal management
- `stevearc/overseer.nvim` - Task runner
- `cuducos/yaml.nvim` - YAML utilities

### 🧪 Testing & Debugging
- `nvim-neotest/neotest` - Testing framework
- `mfussenegger/nvim-dap` - Debug Adapter Protocol
- `rcarriga/nvim-dap-ui` - Debug UI
- `theHamsta/nvim-dap-virtual-text` - Debug virtual text

## ⌨️ Key Mappings

### 📚 Beginner Essentials
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ch` | `:Cheatsheet` | Open built-in cheatsheet |
| `<leader>?` | `:WhichKey` | Show all available keymaps |
| `<leader>nh` | Clear highlights | Remove search highlights |

### 💾 File Operations
| Key | Action | Description |
|-----|--------|-------------|
| `Ctrl+s` | Save | Save current file |
| `<leader>q` | Quit | Quit current buffer |
| `<leader>Q` | Force quit all | Quit without saving |

### 🪟 Window Management
| Key | Action | Description |
|-----|--------|-------------|
| `Ctrl+h/j/k/l` | Navigate | Move between windows |
| `Ctrl+arrows` | Resize | Resize current window |
| `Tab/Shift+Tab` | Buffer nav | Next/previous buffer |

### 🐹 Go Development
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>gr` | `:GoRun` | Run Go program |
| `<leader>gt` | `:GoTest` | Run tests |
| `<leader>gtf` | `:GoTestFunc` | Test current function |
| `<leader>gc` | `:GoCoverage` | Show test coverage |
| `<leader>gif` | `:GoIfErr` | Add if err != nil |
| `<leader>gfs` | `:GoFillStruct` | Fill struct fields |

### 🧪 Testing
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>tt` | Test nearest | Run test under cursor |
| `<leader>tf` | Test file | Run all tests in file |
| `<leader>ts` | Test summary | Toggle test summary |
| `<leader>to` | Test output | Show test output |

### 🐛 Debugging
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>db` | Toggle breakpoint | Set/remove breakpoint |
| `<leader>dc` | Continue | Continue debugging |
| `<leader>di` | Step into | Step into function |
| `<leader>do` | Step over | Step over line |
| `<leader>du` | Debug UI | Toggle debug interface |

### 🌳 Git
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>gg` | `:Neogit` | Open Git interface |
| `<leader>gc` | Git commit | Open commit interface |
| `<leader>gp` | Git push | Push changes |

### 💻 Terminal
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>tf` | Float terminal | Open floating terminal |
| `<leader>th` | Horizontal | Horizontal terminal |
| `<leader>tv` | Vertical | Vertical terminal |

### 🐍 Python
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>vs` | `:VenvSelect` | Select Python virtual environment |

## 🚀 Quick Start Guide

### 1. Basic Vim Movements
```
h/j/k/l - Left/Down/Up/Right
w/b     - Word forward/backward
0/$     - Beginning/End of line
gg/G    - First/Last line
```

### 2. Essential Commands
```
i/a     - Insert before/after cursor
o/O     - New line below/above
dd/yy   - Delete/Copy line
p/P     - Paste below/above
u       - Undo
Ctrl+r  - Redo
```

### 3. File Navigation
```
<leader>ff - Find files
<leader>fw - Find word in files
<leader>fb - Find buffers
<leader>e  - Toggle file explorer
```

### 4. Getting Help
```
<leader>ch - Open cheatsheet
<leader>?  - Show all keymaps
:help      - Vim help system
:Tutor     - Built-in tutorial
```

## 🛠️ Development Workflow

### Go Development
1. Open a `.go` file to trigger Go tooling
2. Use `<leader>gr` to run your program
3. `<leader>gt` to run tests
4. `<leader>gc` to check coverage
5. Set breakpoints with `<leader>db` for debugging

### Python Development
1. Select your virtual environment with `<leader>vs`
2. Use built-in LSP for code completion and diagnostics
3. Format on save with Black and isort

### Ansible Development
1. Open `.yml` files in Ansible projects
2. Get syntax highlighting and validation
3. Use YAML folding and navigation tools

## 🎓 Learning Resources

### Built-in Help
- `:Cheatsheet` - Custom cheatsheet with all commands
- `:help nvim` - Neovim documentation
- `:Tutor` - Interactive Vim tutorial
- `<leader>?` - Which-Key popup showing available commands

### Recommended Learning Path
1. **Master basic navigation** (hjkl, w, b, 0, $)
2. **Learn insert modes** (i, a, o, I, A, O)
3. **Practice copy/paste** (yy, dd, p, P)
4. **Use file finder** (`<leader>ff`)
5. **Explore language features** (LSP, testing, debugging)

## 🔧 Customization

### Adding New Plugins
Edit `lua/plugins/init.lua` and add your plugin configuration.

### Changing Themes
Use `<leader>th` to browse available themes or modify `lua/chadrc.lua`.

### Custom Keymaps
Add your keymaps to `lua/mappings.lua`.

### Language Servers
Modify `lua/configs/lspconfig.lua` to add or configure language servers.

## 🐛 Troubleshooting

### Plugin Issues
```bash
# Clear plugin cache
rm -rf ~/.local/share/nvim/lazy
nvim # Restart to reinstall
```

### LSP Issues
```bash
# Check LSP status
:LspInfo
:Mason # Install/update language servers
```

### Theme Issues
```bash
# Regenerate theme cache
:lua require('base46').load_all_highlights()
```

### Treesitter Issues (Currently Disabled)
⚠️ **Note**: Treesitter is currently disabled due to directive conflicts with Neovim 0.11.4. This is a known issue with newer versions. Syntax highlighting still works through Vim's built-in highlighting.

If you need treesitter features:
```bash
# Wait for treesitter plugin updates or downgrade neovim
# Alternative: Use built-in vim syntax highlighting
```

## 📊 Performance
- **Startup time**: ~0.02-0.07 seconds
- **Plugin count**: ~55 plugins
- **Memory usage**: Optimized with lazy loading
- **Language servers**: Auto-installed via Mason

## 🎉 Features Summary
- ✅ Cyberpunk 2077 theme
- ✅ Beginner-friendly with cheatsheet and which-key
- ✅ Complete Go development environment
- ✅ Python and Ansible support
- ✅ Advanced testing and debugging
- ✅ Git integration
- ✅ Terminal integration
- ✅ Task runner support
- ✅ Comprehensive LSP setup
- ✅ Format on save
- ✅ Auto-completion
- ✅ Syntax highlighting

Enjoy your cyberpunk coding experience! 🚀🔥