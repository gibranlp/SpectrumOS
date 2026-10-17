local cache_home = vim.env.XDG_CACHE_HOME
if cache_home == nil or cache_home == "" then
  cache_home = vim.fn.expand("~/.cache")
end

local generated = cache_home .. "/spectrumos/theme/current/colors/spectrum.lua"
local theme, error_message = loadfile(generated)
if theme == nil then
  error("Cannot load the generated Spectrum theme: " .. error_message)
end
theme()
