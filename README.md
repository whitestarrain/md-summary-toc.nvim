# md-summary-toc.nvim

A Neovim plugin that parses Markdown `SUMMARY.md` files (commonly used by tools like [mdBook](https://github.com/rust-lang/mdBook)) and displays the table of contents in a sidebar for quick navigation.

## Features

- Parse `SUMMARY.md` files into a hierarchical tree
- Display the tree in a sidebar with Nerd Font icons and Unicode tree-drawing characters
- Navigate to linked files with a single keypress (`<CR>`, `o`, `s`, `t`)
- Open files in the system default application (`P`)
- Configurable sidebar position (left/right) and width
- Section heading highlighting
- No external dependencies — uses only Neovim built-in APIs

## Installation

### lazy.nvim

```lua
{
  "wsain/md-summary-toc.nvim",
  keys = {
    { "<leader>mt", "<Cmd>MdSummaryTocToggle<CR>", desc = "Toggle SUMMARY.md sidebar" },
  },
  config = function()
    require("md-summary-toc").setup({
      -- your options here
    })
  end,
}
```

### packer.nvim

```lua
use {
  "wsain/md-summary-toc.nvim",
  config = function()
    require("md-summary-toc").setup()
  end,
}
```

## Configuration

```lua
require("md-summary-toc").setup({
  -- Default SUMMARY.md file path. If set, no prompt is shown.
  default_file = nil,

  -- Sidebar width in columns. nil = auto (min(30, 30% of screen width)).
  width = nil,

  -- Sidebar position: "right" or "left".
  position = "right",

  -- Highlight group for section headings in the sidebar.
  section_hl = "mkdHeading",

  -- Nerd Font icons. Set to "" to disable icons.
  icons = {
    folder = "  ",
    file   = "󰈙 ",
  },
})
```

## Commands

| Command | Description |
|---|---|
| `:MdSummaryToc [file]` | Open the sidebar with the given (or default) SUMMARY.md |
| `:MdSummaryTocClose` | Close the sidebar |
| `:MdSummaryTocToggle [file]` | Toggle the sidebar open/closed |

## Keymaps (in the sidebar buffer)

| Key | Action |
|---|---|
| `<CR>` | Open the file under cursor for editing (in the previous window) |
| `o` | Open in a horizontal split |
| `s` | Open in a vertical split |
| `t` | Open in a new tab |
| `P` | Open with the system default application |
| `r` | Refresh (re-parse) the sidebar |
| `K` | Show node metadata (debug info) |
| `q` / `<Esc>` | Close the sidebar (or quit Neovim if it's the last window) |

## Lua API

```lua
local mst = require("md-summary-toc")

mst.setup(opts)   -- Configure and initialize the plugin
mst.open(path)    -- Open the sidebar (prompts if path is nil and default_file is not set)
mst.close()       -- Close the sidebar
mst.toggle(path)  -- Toggle the sidebar
mst.parse(path)   -- Parse a SUMMARY.md file, returns a tree of nodes
```

## Example SUMMARY.md

```markdown
# Summary

- [Introduction](./intro.md)
- [Getting Started](./getting-started.md)
  - [Installation](./installation.md)
  - [Quick Start](./quick-start.md)
- [Advanced Usage](./advanced.md)
  - [Configuration](./config.md)
  - [API Reference](./api.md)
- [Appendix](./appendix.md)
```

The sidebar will render this as:

```
# Summary
├─ 󰈙 Introduction
├─ 󰈙 Getting Started
│  ├─ 󰈙 Installation
│  └─ 󰈙 Quick Start
├─ 󰈙 Advanced Usage
│  ├─ 󰈙 Configuration
│  └─ 󰈙 API Reference
└─ 󰈙 Appendix
```

File paths in `SUMMARY.md` are resolved relative to the directory containing the `SUMMARY.md` file itself.

## Requirements

- Neovim 0.8+ (for `vim.ui.input`)
- A [Nerd Font](https://www.nerdfonts.com/) (for tree icons; or set `icons` to `""` in config)
