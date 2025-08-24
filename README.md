Quickly jump to any project folder in neovim by typing `:J <bookmark-name>` where the bookmark name can be autocompleted. Requires `ohmyzsh` jump plugin: `https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/jump/README.md`

Example installation for lazyvim, add a new file `lua/plugins/zsh-bookmark-jumper.lua` to your neo-vim folder:
```
return {
  {
    url = "https://github.com/jesusmb1995/ohmyzsh-bookmark-jumper",
    lazy = false, -- we want to be able to quicly jump from the get-go
    config = function()
      require('zsh-bookmark-jumper')
    end
  }
}
```
