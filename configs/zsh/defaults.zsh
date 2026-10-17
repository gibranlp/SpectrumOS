export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME=""

CASE_SENSITIVE="true"
HYPHEN_INSENSITIVE="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
HIST_STAMPS="yyyy/mm/dd"
zstyle ':omz:update' mode disabled

plugins=(
    archlinux
    colored-man-pages
    zsh-autosuggestions
    zsh-syntax-highlighting
    git
    colorize
    command-not-found
)

[[ -r "$ZSH/oh-my-zsh.sh" ]] || {
    print -u2 "SpectrumOS: Oh My Zsh is missing from $ZSH"
    return 1
}
source "$ZSH/oh-my-zsh.sh"
source /usr/share/spectrumos/zsh/themes/spectrum.zsh-theme
eval "$(thefuck --alias)"

alias ..='cd ..'
alias ...='cd ../..'

transmission-cli() {
    mkdir -p -- "$HOME/Downloads"
    command transmission-cli -w "$HOME/Downloads" "$@"
}
