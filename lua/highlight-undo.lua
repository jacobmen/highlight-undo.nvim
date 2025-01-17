-- This module highlights reference usages and the corresponding
-- definition on cursor hold.

local api = vim.api

local M = {
  config = {
    duration = 300,
    undo = {
      hlgroup = 'HighlightUndo',
      mode = 'n',
      lhs = 'u',
      map = 'undo',
      opts = {},
    },
    redo = {
      hlgroup = 'HighlightUndo',
      mode = 'n',
      lhs = '<C-r>',
      map = 'redo',
      opts = {},
    },
  },
  timer = (vim.uv or vim.loop).new_timer(),
  should_detach = true,
  current_hlgroup = nil,
}

local usage_namespace = api.nvim_create_namespace('highlight_undo')

function M.call_original_kemap(map)
  if type(map) == 'string' then
    vim.cmd(map)
  elseif type(map) == 'function' then
    map()
  end
end

function M.on_bytes(
  ignored, ---@diagnostic disable-line
  bufnr, ---@diagnostic disable-line
  changedtick, ---@diagnostic disable-line
  start_row, ---@diagnostic disable-line
  start_column, ---@diagnostic disable-line
  byte_offset, ---@diagnostic disable-line
  old_end_row, ---@diagnostic disable-line
  old_end_col, ---@diagnostic disable-line
  old_end_byte, ---@diagnostic disable-line
  new_end_row, ---@diagnostic disable-line
  new_end_col, ---@diagnostic disable-line
  new_end_byte ---@diagnostic disable-line
)
  if M.should_detach then
    return true
  end
  -- dump(
  --   {
  --     ignored = ignored,
  --     bufnr = bufnr,
  --     changedtick = changedtick,
  --     start_row = start_row,
  --     start_column = start_column,
  --     byte_off = byte_offset,
  --     old_end_row = old_end_row,
  --     old_end_col = old_end_col,
  --     old_end_byte = old_end_byte,
  --     new_end_row = new_end_row,
  --     new_end_col = new_end_col,
  --     new_end_byte = new_end_byte,
  --   }
  -- )
  -- defer highligh till after changes take place..
  vim.schedule(function()
    vim.highlight.range(bufnr, usage_namespace, M.current_hlgroup, { start_row, start_column }, {
      start_row + new_end_row,
      start_column + new_end_col,
    })
    M.clear_highlights(bufnr)
  end)
  --detach
  -- return true
end

function M.highlight_undo(bufnr, hlgroup, command)
  M.current_hlgroup = hlgroup
  api.nvim_buf_attach(bufnr, false, {
    on_bytes = M.on_bytes,
  })
  M.should_detach = false
  command()
  M.should_detach = true
end

function M.clear_highlights(bufnr)
  M.timer:stop()
  M.timer:start(
    M.config.duration,
    0,
    vim.schedule_wrap(function()
      api.nvim_buf_clear_namespace(bufnr, usage_namespace, 0, -1)
    end)
  )
end

function M.setup(config)
  api.nvim_set_hl(0, 'HighlightUndo', {
    fg = '#dcd7ba',
    bg = '#2d4f67',
    default = true,
  })

  M.config = vim.tbl_deep_extend('keep', config or {}, M.config)

  local undo = M.config.undo
  vim.keymap.set(undo.mode, undo.lhs, function()
    M.highlight_undo(0, undo.hlgroup, function()
      M.call_original_kemap(undo.map)
    end)
  end, undo.opts)

  local redo = M.config.redo
  vim.keymap.set(redo.mode, redo.lhs, function()
    M.highlight_undo(0, redo.hlgroup, function()
      M.call_original_kemap(redo.map)
    end)
  end, redo.opts)
end

return M
