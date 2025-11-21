return {
  {
    "oncomouse/lushwal.nvim",
    -- make sure it's loaded when you set colorscheme or compile
    lazy = false,
    dependencies = {
      "rktjmp/lush.nvim",
      "rktjmp/shipwright.nvim",
    },
    config = function()
      -- set the colorscheme
      vim.cmd("colorscheme lushwal")
      -- add a reload hook so Lushwal re-compiles when needed
      require("lushwal").add_reload_hook({
        vim.cmd("LushwalCompile"),
      })
      -- optionally, compile at startup (if you want)
      -- vim.cmd("LushwalCompile")
    end,
    -- if you want a command to compile manually
    cmd = { "LushwalCompile" },
  },
}
