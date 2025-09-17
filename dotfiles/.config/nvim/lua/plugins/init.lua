return {
  -- Disable NvChad's default treesitter to fix conflicts
  {
    "nvim-treesitter/nvim-treesitter",
    enabled = false,
  },

  -- 🎨 Cyberpunk 2077 Theme
  {
    "akai54/2077.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("2077")
    end,
  },

  -- 📚 Beginner-Friendly Tools
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({
        preset = "modern",
        win = {
          border = "single",
          winblend = 10,
        },
        show_help = true,
        show_keys = true,
      })
    end,
  },

  {
    "sudormrfbin/cheatsheet.nvim",
    cmd = { "Cheatsheet", "CheatsheetEdit" },
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("cheatsheet").setup({
        bundled_cheatsheets = {
          enabled = { "default", "lua", "markdown", "regex", "netrw", "unicode" },
        },
        bundled_plugin_cheatsheets = {
          enabled = {
            "auto-session",
            "goto-preview",
            "octo.nvim",
            "telescope.nvim",
            "vim-easy-align",
            "vim-sandwich",
          },
        },
      })
    end,
  },

  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
    opts = {
      disabled_filetypes = { "qf", "netrw", "NvimTree", "lazy", "mason", "oil" },
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- Treesitter for better syntax highlighting (temporarily disabled due to directive conflicts)
  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   event = { "BufReadPost", "BufNewFile" },
  --   cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
  --   build = ":TSUpdate",
  --   opts = require "configs.treesitter",
  --   config = function(_, opts)
  --     require("nvim-treesitter.configs").setup(opts)
  --   end,
  -- },

  -- 🐹 Go Development Environment
  {
    "ray-x/go.nvim",
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      -- "nvim-treesitter/nvim-treesitter", -- Temporarily disabled
    },
    config = function()
      require("go").setup({
        -- goimports = 'gopls', -- Use gopls for imports
        fillstruct = 'gopls',
        dap_debug = true,
        dap_debug_gui = true,
        test_runner = 'go', -- richgo, go test, richgo, dlv, ginkgo, gotestsum
        verbose_tests = true, -- set to add verbose flag to tests
        run_in_floaterm = true, -- set to true to run in float window.
      })
    end,
    event = {"CmdlineEnter"},
    ft = {"go", 'gomod'},
    build = ':lua require("go.install").update_all_sync()'
  },

  -- Go testing utilities
  {
    "yanskun/gotests.nvim",
    ft = "go",
    config = function()
      require("gotests").setup()
    end,
  },

  -- Go struct tag management
  {
    "romus204/go-tagger.nvim",
    ft = "go",
    config = function()
      require("go-tagger").setup()
    end,
  },

  -- 🐍 Python/Ansible Development
  {
    "mfussenegger/nvim-ansible",
    ft = {"yaml.ansible", "ansible"},
  },

  {
    "pearofducks/ansible-vim",
    ft = {"yaml", "ansible"},
  },

  {
    "linux-cultist/venv-selector.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "mfussenegger/nvim-dap",
      "nvim-telescope/telescope.nvim"
    },
    ft = "python",
    config = function()
      require("venv-selector").setup()
    end,
  },

  -- 📝 YAML/Config Management
  {
    "cuducos/yaml.nvim",
    ft = {"yaml"},
    dependencies = {
      -- "nvim-treesitter/nvim-treesitter", -- Temporarily disabled
      "nvim-telescope/telescope.nvim",
    },
  },

  -- 🚀 Advanced Development Features
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = true,
  },

  {
    "akinsho/toggleterm.nvim",
    config = function()
      require("toggleterm").setup({
        direction = 'float',
        float_opts = {
          border = 'curved',
        },
      })
    end,
  },

  {
    "stevearc/overseer.nvim",
    config = function()
      require("overseer").setup({
        templates = { "builtin", "go", "make", "task" },
      })
    end,
  },

  -- 🧪 Testing Framework
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-neotest/neotest-go",
      "nvim-neotest/neotest-python",
      "antoinemadec/FixCursorHold.nvim",
      -- "nvim-treesitter/nvim-treesitter" -- Temporarily disabled
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-go"),
          require("neotest-python")({
            dap = { justMyCode = false },
          }),
        },
      })
    end,
  },

  -- 🐛 Debugging
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      require("dapui").setup()
      require("nvim-dap-virtual-text").setup()

      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },

  -- 🎨 UI Enhancements
  {
    "rcarriga/nvim-notify",
    config = function()
      require("notify").setup({
        background_colour = "#1a1a2e", -- Dark cyberpunk bg
        timeout = 3000,
        max_height = function()
          return math.floor(vim.o.lines * 0.75)
        end,
        max_width = function()
          return math.floor(vim.o.columns * 0.75)
        end,
      })
      vim.notify = require("notify")
    end,
  },

  {
    "stevearc/dressing.nvim",
    opts = {},
  },

  -- Enhanced Telescope configuration with FZF backend
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
    opts = function()
      return require "configs.telescope"
    end,
  },
}
