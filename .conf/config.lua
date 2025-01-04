-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

-- options
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus" -- allows neovim to access the system clipboard
vim.opt.cursorcolumn = true
vim.opt.relativenumber = true
vim.opt.wrap = true
lvim.colorscheme = "tokyonight"

-- toggleterm
lvim.builtin["terminal"].shell = "zsh"
lvim.builtin["terminal"].direction = "float"
lvim.builtin["terminal"].float_opts = {
  border = "double",
}

-- telescope
lvim.builtin.telescope.defaults = {
  layout_strategy = 'horizontal', -- or 'vertical', 'center', 'cursor'
  layout_config = {
    width = 0.85,
    height = 0.85,
    prompt_position = "top", -- or "bottom"
 }
}

-- bufferline
lvim.builtin.bufferline.keymap.normal_mode["<leader>1"] = ":BufferLineGoToBuffer 1<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>2"] = ":BufferLineGoToBuffer 2<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>3"] = ":BufferLineGoToBuffer 3<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>4"] = ":BufferLineGoToBuffer 4<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>5"] = ":BufferLineGoToBuffer 5<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>6"] = ":BufferLineGoToBuffer 6<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>7"] = ":BufferLineGoToBuffer 7<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>8"] = ":BufferLineGoToBuffer 8<CR>"
lvim.builtin.bufferline.keymap.normal_mode["<leader>9"] = ":BufferLineGoToBuffer 9<CR>"

-- install plugins
lvim.plugins = {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      terminal_colors = false,
    },
  },
  {
    "simrat39/symbols-outline.nvim",
    config = function()
      require('symbols-outline').setup({
        keymaps = {
          hover_symbol = "<C-s>",
        },
        auto_preview = true,
      })
    end,
  },
  {"ChristianChiarulli/swenv.nvim"},
  {"stevearc/dressing.nvim"},
  {"mfussenegger/nvim-dap-python"},
  -- {"nvim-neotest/neotest"},
  -- {"nvim-neotest/neotest-python"},
}
-- automatically install python syntax highlighting
lvim.builtin.treesitter.ensure_installed = {
  "python",
}

-- setup formatting
local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup { { name = "black" }, }
lvim.format_on_save.enabled = true
lvim.format_on_save.pattern = { "*.py" }

-- setup linting
local linters = require "lvim.lsp.null-ls.linters"
linters.setup { { command = "flake8", filetypes = { "python" } } }

-- setup debug adapter
lvim.builtin.dap.active = true
local mason_path = vim.fn.glob(vim.fn.stdpath "data" .. "/mason/")
pcall(function()
  require("dap-python").setup(mason_path .. "packages/debugpy/venv/bin/python")
end)

-- setup testing
--[[
require("neotest").setup({
  adapters = {
    require("neotest-python")({
      -- Extra arguments for nvim-dap configuration
      -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
      dap = {
        justMyCode = false,
        console = "integratedTerminal",
      },
      args = { "--log-level", "DEBUG", "--quiet" },
      runner = "pytest",
    })
  }
})
--]]

lvim.builtin.which_key.mappings["dm"] = { "<cmd>lua require('neotest').run.run()<cr>",
  "Test Method" }
lvim.builtin.which_key.mappings["dM"] = { "<cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>",
  "Test Method DAP" }
lvim.builtin.which_key.mappings["df"] = {
  "<cmd>lua require('neotest').run.run({vim.fn.expand('%')})<cr>", "Test Class" }
lvim.builtin.which_key.mappings["dF"] = {
  "<cmd>lua require('neotest').run.run({vim.fn.expand('%'), strategy = 'dap'})<cr>", "Test Class DAP" }
lvim.builtin.which_key.mappings["dS"] = { "<cmd>lua require('neotest').summary.toggle()<cr>", "Test Summary" }


-- binding for switching
lvim.builtin.which_key.mappings["C"] = {
  name = "Python",
  c = { "<cmd>lua require('swenv.api').pick_venv()<cr>", "Choose Env" },
}
