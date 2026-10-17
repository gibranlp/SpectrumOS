local theme_root = vim.fn.expand("$XDG_CACHE_HOME/spectrumos/theme/current")
if vim.env.XDG_CACHE_HOME == nil or vim.env.XDG_CACHE_HOME == "" then
  theme_root = vim.fn.expand("~/.cache/spectrumos/theme/current")
end
vim.opt.runtimepath:prepend(theme_root)

require("config.lazy")
