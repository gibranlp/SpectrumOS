setopt prompt_subst

SPECTRUM_PROMPT_SEPARATOR=$'\ue0b0'
SPECTRUM_PROMPT_BRANCH=$'\ue0a0'
SPECTRUM_PROMPT_BG=""

spectrum_prompt_segment() {
    local background=$1
    local foreground=$2
    local content=${3:-}
    local background_code="%K{$background}"
    local foreground_code="%F{$foreground}"

    if [[ -n $SPECTRUM_PROMPT_BG && $background != $SPECTRUM_PROMPT_BG ]]; then
        print -n -- " %{$background_code%F{$SPECTRUM_PROMPT_BG}%}$SPECTRUM_PROMPT_SEPARATOR%{$foreground_code%} "
    else
        print -n -- "%{$background_code%}%{$foreground_code%} "
    fi
    SPECTRUM_PROMPT_BG=$background
    [[ -n $content ]] && print -n -- "$content"
}

spectrum_prompt_end() {
    if [[ -n $SPECTRUM_PROMPT_BG ]]; then
        print -n -- " %{%k%F{$SPECTRUM_PROMPT_BG}%}$SPECTRUM_PROMPT_SEPARATOR%{%f%}"
    fi
    SPECTRUM_PROMPT_BG=""
}

spectrum_prompt_status() {
    local exit_code=$1
    local -a symbols=()
    (( exit_code != 0 )) && symbols+=("%F{1}✘ $exit_code%f")
    (( UID == 0 )) && symbols+=("%F{3}⚡%f")
    [[ -n $(jobs -p) ]] && symbols+=("%F{6}⚙%f")
    (( ${#symbols} )) && spectrum_prompt_segment 8 7 "${(j: :)symbols}"
}

spectrum_prompt_context() {
    spectrum_prompt_segment 8 7 "%F{5}󰣇%F{7} %n@%m"
}

spectrum_prompt_directory() {
    spectrum_prompt_segment 4 0 "%~"
}

spectrum_prompt_git() {
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

    local branch git_state upstream left right tracking=""
    branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) || \
        branch="$(command git rev-parse --short HEAD 2>/dev/null)"
    git_state=$(command git status --porcelain --ignore-submodules=dirty 2>/dev/null)
    upstream=$(command git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || upstream=""
    if [[ -n $upstream ]]; then
        read -r left right <<< "$(command git rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)"
        (( left > 0 && right > 0 )) && tracking=" ⇅${left}/${right}"
        (( left > 0 && right == 0 )) && tracking=" ↑${left}"
        (( right > 0 && left == 0 )) && tracking=" ↓${right}"
    fi

    branch=${branch//\%/%%}
    spectrum_prompt_segment 5 0 "$SPECTRUM_PROMPT_BRANCH $branch${git_state:+ ±}$tracking"
}

spectrum_build_prompt() {
    local exit_code=$?
    spectrum_prompt_status "$exit_code"
    spectrum_prompt_context
    spectrum_prompt_directory
    spectrum_prompt_git
    spectrum_prompt_end
}

PROMPT='%{%f%b%k%}$(spectrum_build_prompt) '
