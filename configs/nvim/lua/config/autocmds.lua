local group = vim.api.nvim_create_augroup("spectrum_theme", { clear = true })
vim.api.nvim_create_autocmd("FocusGained", {
  group = group,
  callback = function()
    vim.cmd.colorscheme("spectrum")
  end,
})
