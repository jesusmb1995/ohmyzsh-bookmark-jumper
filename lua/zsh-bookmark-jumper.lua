-- Released by jesusmb1995 under MIT license
-- Let's create a Neovim plugin that integrates with the Zsh zsh-autobookmarks plugin (or similar bookmarking tools like z.sh), allowing you to jump to bookmarked directories using a :C <bookmarkname> command with autocompletion. This plugin will leverage Lazy.nvim for plugin management and interact with Zsh's bookmark system via shell commands.
local M = {}

-- Default configuration
local default_config = {
  -- Path to store usage statistics
  data_file = vim.fn.stdpath("data") .. "/zsh-bookmark-jumper.json",
  -- Whether to sort bookmarks by last used
  sort_by_last_used = true,
  -- Maximum number of bookmarks to show in autocompletion
  max_completions = 50,
  -- Whether to persist usage statistics
  persist_usage = true,
}

-- Configuration object
M.config = {}

-- Usage statistics storage
local usage_stats = {}

-- Function to get the data directory and ensure it exists
local function ensure_data_dir()
  local data_dir = vim.fn.fnamemodify(M.config.data_file, ":h")
  if vim.fn.isdirectory(data_dir) == 0 then
    vim.fn.mkdir(data_dir, "p")
  end
end

-- Function to load usage statistics from file
local function load_usage_stats()
  if not M.config.persist_usage then
    return
  end
  
  ensure_data_dir()
  
  local file = io.open(M.config.data_file, "r")
  if file then
    local content = file:read("*a")
    file:close()
    
    local success, data = pcall(vim.json.decode, content)
    if success and data then
      usage_stats = data
    end
  end
end

-- Function to save usage statistics to file
local function save_usage_stats()
  if not M.config.persist_usage then
    return
  end
  
  ensure_data_dir()
  
  local file = io.open(M.config.data_file, "w")
  if file then
    local content = vim.json.encode(usage_stats)
    file:write(content)
    file:close()
  end
end

-- Function to update usage statistics for a bookmark
local function update_usage_stats(bookmark_name)
  if not M.config.persist_usage then
    return
  end
  
  local current_time = os.time()
  usage_stats[bookmark_name] = current_time
  save_usage_stats()
end

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
end

local function get_bookmarks()
  if M.bookmarks_cache == nil then
    parse_bookmakrs()
  end
  return M.bookmarks_cache
end

-- Function to get sorted bookmarks by last used
local function get_sorted_bookmarks()
  local bookmarks = get_bookmarks()
  local bookmark_list = {}
  
  for name, path in pairs(bookmarks) do
    table.insert(bookmark_list, {
      name = name,
      path = path,
      last_used = usage_stats[name] or 0
    })
  end
  
  if M.config.sort_by_last_used then
    table.sort(bookmark_list, function(a, b)
      return a.last_used > b.last_used
    end)
  end
  
  return bookmark_list
end

-- Function to jump to a bookmark
local function jump_to_bookmark(bookmark_name, only_tab)
  local bookmarks = get_bookmarks()
  local path = bookmarks[bookmark_name]
  if path then
    -- Update usage statistics
    update_usage_stats(bookmark_name)
    
    if only_tab then
      vim.cmd("tcd " .. path)
    else
      vim.cmd("cd " .. path)
    end
    vim.notify("Changed directory to: " .. path, vim.log.levels.INFO)
  else
    vim.notify("Bookmark '" .. bookmark_name .. "' not found. Try updating with :JParse", vim.log.levels.ERROR)
  end
end

-- Autocompletion function for :C command
local function complete_bookmarks(arg_lead, _cmd_line, _cursor_pos)
  local sorted_bookmarks = get_sorted_bookmarks()
  local completions = {}
  local count = 0
  
  for _, bookmark in ipairs(sorted_bookmarks) do
    if count >= M.config.max_completions then
      break
    end
    
    if bookmark.name:find(arg_lead, 1, true) == 1 then
      table.insert(completions, bookmark.name)
      count = count + 1
    end
  end
  
  return completions
end

-- Setup function to define the :C command
function M.setup(opts)
  -- Merge configuration
  M.config = vim.tbl_deep_extend("force", default_config, opts or {})
  
  -- Load usage statistics
  load_usage_stats()
  
  vim.api.nvim_create_user_command("J", function(opts)
    jump_to_bookmark(opts.args, true)
  end, {
    nargs = 1, -- Expect exactly one argument (bookmark name)
    complete = complete_bookmarks, -- Enable autocompletion
  })
  vim.api.nvim_create_user_command("Jv", function(opts)
    jump_to_bookmark(opts.args, true)
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
  
  -- Add command to clear usage statistics
  vim.api.nvim_create_user_command("JClearStats", function()
    usage_stats = {}
    save_usage_stats()
    vim.notify("Usage statistics cleared", vim.log.levels.INFO)
  end, {
    nargs = 0,
  })
  
  -- Add command to show usage statistics
  vim.api.nvim_create_user_command("JStats", function()
    local sorted_bookmarks = get_sorted_bookmarks()
    local lines = {"Bookmark Usage Statistics:", ""}
    
    for i, bookmark in ipairs(sorted_bookmarks) do
      if i <= 20 then -- Show top 20
        local date_str = bookmark.last_used > 0 and os.date("%Y-%m-%d %H:%M:%S", bookmark.last_used) or "Never used"
        table.insert(lines, string.format("%2d. %-20s %s", i, bookmark.name, date_str))
      end
    end
    
    -- Create a new buffer to display stats
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = 60,
      height = math.min(#lines + 2, 25),
      row = 2,
      col = 2,
      style = "minimal",
      border = "rounded",
    })
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "filetype", "zsh-bookmark-stats")
    
    -- Set keymap to close the window
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, noremap = true })
  end, {
    nargs = 0,
  })
end

return M
