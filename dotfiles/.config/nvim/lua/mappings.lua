require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- 📚 Beginner-friendly mappings
map("n", "<leader>ch", "<cmd>Cheatsheet<CR>", { desc = "Open Cheatsheet" })
map("n", "<leader>?", "<cmd>WhichKey<CR>", { desc = "Show All Keymaps" })

-- 🔍 Better search and navigation
map("n", "<leader>nh", "<cmd>nohl<CR>", { desc = "Clear search highlights" })

-- 💾 Quick save and quit
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qa!<CR>", { desc = "Quit all without saving" })

-- 🪟 Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- 📏 Resize windows
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- 🔄 Buffer management
map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>bprev<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- 🎯 Better text manipulation
map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- 🔍 Better indenting
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- 🐹 Go Development
map("n", "<leader>gr", "<cmd>GoRun<CR>", { desc = "Go Run" })
map("n", "<leader>gt", "<cmd>GoTest<CR>", { desc = "Go Test" })
map("n", "<leader>gtf", "<cmd>GoTestFunc<CR>", { desc = "Go Test Function" })
map("n", "<leader>gtg", "<cmd>GoTestFile<CR>", { desc = "Go Test File" })
map("n", "<leader>gta", "<cmd>GoTestAll<CR>", { desc = "Go Test All" })
map("n", "<leader>gc", "<cmd>GoCoverage<CR>", { desc = "Go Coverage" })
map("n", "<leader>gd", "<cmd>GoDoc<CR>", { desc = "Go Documentation" })
map("n", "<leader>gif", "<cmd>GoIfErr<CR>", { desc = "Go If Error" })
map("n", "<leader>gfs", "<cmd>GoFillStruct<CR>", { desc = "Go Fill Struct" })

-- 🧪 Testing with Neotest
map("n", "<leader>tt", "<cmd>lua require('neotest').run.run()<CR>", { desc = "Test Nearest" })
map("n", "<leader>tf", "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<CR>", { desc = "Test File" })
map("n", "<leader>ts", "<cmd>lua require('neotest').summary.toggle()<CR>", { desc = "Test Summary" })
map("n", "<leader>to", "<cmd>lua require('neotest').output.open({ enter = true })<CR>", { desc = "Test Output" })

-- 🐛 Debugging
map("n", "<leader>db", "<cmd>lua require('dap').toggle_breakpoint()<CR>", { desc = "Debug Breakpoint" })
map("n", "<leader>dc", "<cmd>lua require('dap').continue()<CR>", { desc = "Debug Continue" })
map("n", "<leader>di", "<cmd>lua require('dap').step_into()<CR>", { desc = "Debug Step Into" })
map("n", "<leader>do", "<cmd>lua require('dap').step_over()<CR>", { desc = "Debug Step Over" })
map("n", "<leader>dr", "<cmd>lua require('dap').repl.open()<CR>", { desc = "Debug REPL" })
map("n", "<leader>du", "<cmd>lua require('dapui').toggle()<CR>", { desc = "Debug UI" })

-- 🌳 Git
map("n", "<leader>gg", "<cmd>Neogit<CR>", { desc = "Open Neogit" })
map("n", "<leader>gs", "<cmd>Neogit kind=split<CR>", { desc = "Neogit Split" })
map("n", "<leader>gc", "<cmd>Neogit commit<CR>", { desc = "Git Commit" })
map("n", "<leader>gp", "<cmd>Neogit push<CR>", { desc = "Git Push" })

-- 💻 Terminal
map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", { desc = "Float Terminal" })
map("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Horizontal Terminal" })
map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>", { desc = "Vertical Terminal" })

-- 🚀 Task Runner
map("n", "<leader>or", "<cmd>OverseerRun<CR>", { desc = "Run Task" })
map("n", "<leader>ot", "<cmd>OverseerToggle<CR>", { desc = "Toggle Overseer" })
map("n", "<leader>oo", "<cmd>OverseerOpen<CR>", { desc = "Open Overseer" })

-- 🐍 Python
map("n", "<leader>vs", "<cmd>VenvSelect<CR>", { desc = "Select Python Venv" })
