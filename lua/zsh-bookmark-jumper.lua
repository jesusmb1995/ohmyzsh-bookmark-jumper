-- Let’s create a Neovim plugin that integrates with the Zsh zsh-autobookmarks plugin (or similar bookmarking tools like z.sh), allowing you to jump to bookmarked directories using a :C <bookmarkname> command with autocompletion. This plugin will leverage Lazy.nvim for plugin management and interact with Zsh’s bookmark system via shell commands.
local M = {}

local function parse_bookmakrs()
  -- Run `showmarks` in Zsh and capture output
  local handle = io.popen "zsh -c 'source ~/.zshrc; showmarks'"
  if not handle then
    vim.notify("Failed to run showmarks", vim.log.levels.ERROR)
    return {}
  end

  local result = handle:read "*a"
  handle:close()

  -- Parse the output of `showmarks` (assumes format: "bookmarkname    /path/to/dir")
  local bookmarks = {}
  for line in result:gmatch "[^\n]+" do
    local name, path = line:match "^(%S+)%s+(.+)$"
    if name and path then
      bookmarks[name] = path
    end
  end

  M.bookmarks_cache = bookmarks
  return bookmarks
end

local function get_bookmarks()
  if M.bookmarks_cache ~= nil then
    return M.bookmarks_cache
  end
  parse_bookmakrs()
end

-- Function to jump to a bookmark
local function jump_to_bookmark(bookmark_name)
  local bookmarks = get_bookmarks()
  local path = bookmarks[bookmark_name]
  if path then
    vim.cmd("cd " .. path)
    vim.notify("Changed directory to: " .. path, vim.log.levels.INFO)
  else
    vim.notify("Bookmark '" .. bookmark_name .. "' not found. Try updating with :CParse", vim.log.levels.ERROR)
  end
end

-- Autocompletion function for :C command
local function complete_bookmarks(arg_lead, _cmd_line, _cursor_pos)
  local bookmarks = get_bookmarks()
  local completions = {}
  for name in pairs(bookmarks) do
    if name:find(arg_lead, 1, true) == 1 then
      table.insert(completions, name)
    end
  end
  return completions
end

-- Setup function to define the :C command
function M.setup()
  vim.api.nvim_create_user_command("J", function(opts)
    jump_to_bookmark(opts.args)
  end, {
    nargs = 1, -- Expect exactly one argument (bookmark name)
    complete = complete_bookmarks, -- Enable autocompletion
  })
  vim.api.nvim_create_user_command("JParse", function()
    M.bookmarks_cache = nil
    parse_bookmakrs()
  end, {
    nargs = 0,
  })
end

return { setup = M.setup() }
