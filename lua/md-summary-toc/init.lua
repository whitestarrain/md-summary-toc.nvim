local sidebar = require("md-summary-toc.sidebar")

local M = {}

local defaults = {
  default_file = nil,
  width = nil,
  position = "right",
  section_hl = "mkdHeading",
  selected_hl = "Search",
  icons = {
    folder = "  ",
    file = "󰈙 ",
  },
}

M.config = vim.deepcopy(defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  sidebar.set_config(M.config)

  vim.api.nvim_create_user_command("MdSummaryToc", function(cmd_opts)
    local filepath = cmd_opts.args ~= "" and cmd_opts.args or M.config.default_file
    sidebar.open(filepath)
  end, { nargs = "?", complete = "file" })

  vim.api.nvim_create_user_command("MdSummaryTocClose", function()
    sidebar.close()
  end, {})

  vim.api.nvim_create_user_command("MdSummaryTocToggle", function(cmd_opts)
    local filepath = cmd_opts.args ~= "" and cmd_opts.args or M.config.default_file
    sidebar.toggle(filepath)
  end, { nargs = "?", complete = "file" })
end

M.open = sidebar.open

M.close = sidebar.close

M.toggle = sidebar.toggle

M.parse = require("md-summary-toc.parser").parse

return M
