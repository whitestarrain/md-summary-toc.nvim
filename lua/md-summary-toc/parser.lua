local M = {}

local function skip_line(line)
  return vim.trim(line) == ""
    or vim.trim(line) == "---"
    or vim.trim(line):match("^%s*$") ~= nil
end

local function is_html_comment_start(line)
  return vim.trim(line):match("^<!%-%-") ~= nil
end

local function is_html_comment_end(line)
  return line:match("%-%-%>") ~= nil
end

local function get_heading_level(line)
  local hashes = vim.trim(line):match("^(#+)%s+")
  return hashes and #hashes or nil
end

local function is_list_item(line)
  return vim.trim(line):match("^[%*%+%-]%s*%[") ~= nil
end

local function parse_link(text)
  local title, path = text:match("%[([^%]]+)%]%(([^%)]*)%)")
  if not title then
    return nil
  end
  return vim.trim(title), vim.trim(path)
end

local function leading_spaces(line)
  local spaces = line:match("^(%s*)")
  return #spaces
end

local function build_tree(lines)
  local root = { type = "root", title = "ROOT", path = nil, depth = -1, children = {} }
  local stack = { root }

  local in_comment = false

  for i, line in ipairs(lines) do
    if in_comment then
      if is_html_comment_end(line) then
        in_comment = false
      end
    elseif is_html_comment_start(line) then
      if not is_html_comment_end(line) then
        in_comment = true
      end
    elseif not skip_line(line) then
      local heading_level = get_heading_level(line)
      if heading_level then
        local title = vim.trim(line):match("^#+%s+(.+)")
        local section_depth = heading_level - 1
        local node = { type = "section", title = title, path = nil, depth = section_depth, linenr = i, children = {} }

        while #stack >= 2 and stack[#stack].type ~= "section" do
          table.remove(stack)
        end
        while #stack >= 2 and stack[#stack].type == "section" and stack[#stack].depth >= section_depth do
          table.remove(stack)
        end

        local parent = stack[#stack]
        table.insert(parent.children, node)
        table.insert(stack, node)
      else
        local title, path = parse_link(line)
        if title then
          local depth = math.floor(leading_spaces(line) / 2)
          local node = {
            type = "link",
            title = title,
            path = path ~= "" and path or nil,
            depth = depth,
            children = {},
          }

          if is_list_item(line) then
            while
              #stack >= 2
              and stack[#stack].depth >= depth
              and stack[#stack].type ~= "section"
            do
              table.remove(stack)
            end
            local parent = stack[#stack]
            table.insert(parent.children, node)
            table.insert(stack, node)
          else
            while
              #stack >= 2
              and stack[#stack].depth >= depth
              and stack[#stack].type ~= "section"
            do
              table.remove(stack)
            end
            local parent = stack[#stack]
            table.insert(parent.children, node)
          end
        end
      end
    end
  end

  return root.children
end

function M.parse(filepath)
  local lines = vim.fn.readfile(filepath)
  if not lines or #lines == 0 then
    vim.notify("md-summary-toc: empty or unreadable file: " .. filepath, vim.log.levels.WARN)
    return {}
  end

  return build_tree(lines)
end

return M
