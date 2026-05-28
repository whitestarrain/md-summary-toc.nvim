local parser = require("md-summary-toc.parser")

local M = {}

local ns_id = vim.api.nvim_create_namespace("MdSummaryToc")

local config = {
  width = nil,
  position = "right",
  section_hl = "mkdHeading",
  icons = {
    folder = "  ",
    file = "󰈙 ",
  },
}

vim.api.nvim_set_hl(0, "MdSummaryTocSection", { link = config.section_hl, default = true })

local state = {
  buf = nil,
  win = nil,
  base_dir = nil,
  filepath = nil,
  node_by_line = {},
  prev_win = nil,
  autocmd_id = nil,
}

function M.set_config(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  vim.api.nvim_set_hl(0, "MdSummaryTocSection", { link = config.section_hl, default = true })
end

local function tree_prefix(is_last, depth_bits)
  local parts = {}
  for i = 1, #depth_bits do
    parts[i] = depth_bits[i] and "│  " or "   "
  end
  local prefix = table.concat(parts)
  if #depth_bits > 0 then
    return prefix .. (is_last and "└─ " or "├─ ")
  end
  return ""
end

local function render_nodes(nodes, depth_bits, lines)
  local n = #nodes
  for i, node in ipairs(nodes) do
    local is_last = (i == n)

    if node.type == "section" then
      local hashes = string.rep("#", node.depth + 1)
      table.insert(lines, { text = hashes .. " " .. node.title, hl = "MdSummaryTocSection", node = node })
      render_nodes(node.children, {}, lines)
    else
      local icon = (#node.children > 0) and config.icons.folder or config.icons.file
      local prefix = tree_prefix(is_last, depth_bits)
      table.insert(lines, { text = prefix .. icon .. node.title, node = node })

      if #node.children > 0 then
        local child_bits = vim.deepcopy(depth_bits)
        child_bits[#child_bits + 1] = not is_last
        render_nodes(node.children, child_bits, lines)
      end
    end
  end
end

local function build_display_lines(nodes)
  local lines = {}
  render_nodes(nodes, {}, lines)
  return lines
end

local function jump_to_link(node, cmd)
  if not node or not node.path or node.type ~= "link" then
    return
  end
  local full = vim.fn.fnamemodify(state.base_dir .. "/" .. node.path, ":p")
  if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
    vim.api.nvim_set_current_win(state.prev_win)
  else
    vim.cmd("wincmd p")
  end
  vim.cmd(cmd .. " " .. vim.fn.fnameescape(full))
end

local function node_at_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return state.node_by_line[lnum]
end

local function close_or_quit()
  local win_count = #vim.api.nvim_tabpage_list_wins(0)
  if win_count <= 1 then
    vim.cmd("qa")
  else
    M.close()
  end
end

local function set_buffer_mappings(buf)
  local opts = { noremap = true, silent = true, buffer = buf }

  vim.keymap.set("n", "<CR>", function()
    jump_to_link(node_at_cursor(), "edit")
  end, opts)

  vim.keymap.set("n", "q", close_or_quit, opts)
  vim.keymap.set("n", "<Esc>", close_or_quit, opts)

  vim.keymap.set("n", "o", function()
    jump_to_link(node_at_cursor(), "split")
  end, opts)

  vim.keymap.set("n", "s", function()
    jump_to_link(node_at_cursor(), "vsplit")
  end, opts)

  vim.keymap.set("n", "t", function()
    jump_to_link(node_at_cursor(), "tabedit")
  end, opts)

  vim.keymap.set("n", "P", function()
    local node = node_at_cursor()
    if node and node.path then
      local full = vim.fn.fnamemodify(state.base_dir .. "/" .. node.path, ":p")
      vim.ui.open(full)
    end
  end, opts)

  vim.keymap.set("n", "K", function()
    local node = node_at_cursor()
    if node then
      vim.notify(vim.inspect(node), vim.log.levels.INFO)
    end
  end, opts)

  vim.keymap.set("n", "r", function()
    if state.filepath then
      M.refresh()
    end
  end, opts)
end

function M.open(filepath)
  if not filepath then
    vim.ui.input({ prompt = "SUMMARY.md path: ", completion = "file" }, function(input)
      if not input or input == "" then
        return
      end
      M.open(input)
    end)
    return
  end

  filepath = vim.fn.fnamemodify(filepath, ":p")

  if vim.fn.filereadable(filepath) ~= 1 then
    vim.notify("md-summary-toc: file not found: " .. filepath, vim.log.levels.ERROR)
    return
  end

  local nodes = parser.parse(filepath)
  if not nodes or #nodes == 0 then
    vim.notify("md-summary-toc: no entries found", vim.log.levels.WARN)
    return
  end

  local base_dir = vim.fn.fnamemodify(filepath, ":h")

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_close(state.win, true)
    end
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  state.win = nil
  state.base_dir = base_dir
  state.filepath = filepath
  state.node_by_line = {}
  state.prev_win = vim.api.nvim_get_current_win()

  if state.autocmd_id then
    vim.api.nvim_del_autocmd(state.autocmd_id)
  end
  state.autocmd_id = vim.api.nvim_create_autocmd("WinClosed", {
    callback = vim.schedule_wrap(function()
      if not state.win or not vim.api.nvim_win_is_valid(state.win) then
        return
      end
      local wins = vim.api.nvim_tabpage_list_wins(0)
      if #wins == 1 and wins[1] == state.win then
        vim.cmd("qa")
      end
    end),
  })

  local display_lines = build_display_lines(nodes)

  local text_lines = {}
  for _, dl in ipairs(display_lines) do
    table.insert(text_lines, dl.text)
  end

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, text_lines)
  vim.bo[state.buf].modifiable = false
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].filetype = "md-summary-toc"

  for lnum, dl in ipairs(display_lines) do
    state.node_by_line[lnum] = dl.node
    if dl.hl then
      vim.api.nvim_buf_add_highlight(state.buf, ns_id, dl.hl, lnum - 1, 0, -1)
    end
  end

  local width = config.width or math.min(30, math.floor(vim.o.columns * 0.3))
  local position_cmd = config.position == "left" and "topleft" or "botright"
  vim.cmd(position_cmd .. " " .. width .. "vnew")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"
  vim.wo[state.win].foldcolumn = "0"
  vim.wo[state.win].cursorline = true
  vim.wo[state.win].winfixwidth = true

  set_buffer_mappings(state.buf)
end

function M.close()
  if state.autocmd_id then
    vim.api.nvim_del_autocmd(state.autocmd_id)
    state.autocmd_id = nil
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end
  state.node_by_line = {}
  state.prev_win = nil
end

function M.refresh()
  if state.filepath then
    M.open(state.filepath)
  end
end

function M.toggle(filepath)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
  elseif not filepath then
    vim.ui.input({ prompt = "SUMMARY.md path: ", completion = "file" }, function(input)
      if not input or input == "" then
        return
      end
      M.open(input)
    end)
  else
    M.open(filepath)
  end
end

return M
