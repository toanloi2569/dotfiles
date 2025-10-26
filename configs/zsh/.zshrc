# ---------- Dotfiles bootstrap ----------
export ZSH="$HOME/.oh-my-zsh"

if [[ -z ${DOTFILES_DIR:-} ]]; then
    typeset -g __dotfiles_source="${(%):-%N}"
    if [[ -n $__dotfiles_source ]]; then
        export DOTFILES_DIR="${__dotfiles_source:A:h:h}"
    else
        export DOTFILES_DIR="$HOME/.dotfiles"
    fi
    unset __dotfiles_source
else
    export DOTFILES_DIR
fi

typeset -gU path fpath  # Avoid duplicated PATH/fpath entries early.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
command mkdir -p "$XDG_CACHE_HOME/zsh" 2> /dev/null

# Lightweight helper to add directories to PATH without duplicates.
path_add() {
    local dir
    for dir in "$@"; do
        [[ -d $dir ]] || continue
        path=("$dir" ${path:#$dir})
    done
}

# ---------- Theme & plugins ----------
ZSH_THEME="robbyrussell"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=180'

plugins=(
    git
    nvm
    poetry
    kube-ps1
    zsh-autosuggestions
    zsh-autocomplete
    fzf-tab
    zsh-expand
    zsh-syntax-highlighting
)

ZSH_DISABLE_COMPFIX=true  # Skip slow compaudit checks; we trust the shared config.
source "$ZSH/oh-my-zsh.sh"

zmodload zsh/zprof
zprof() {
  builtin zprof "$@"
}

# ---------- Completion & suggestions ----------
autoload -Uz colors && colors
zmodload zsh/complist 2> /dev/null

if [[ -r ~/.zcompdump && ( ! -r ~/.zcompdump.zwc || ~/.zcompdump -nt ~/.zcompdump.zwc ) ]]; then
    zcompile ~/.zcompdump &!  # Precompile completion cache in the background.
fi

ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

COMPLETION_WAITING_DOTS="true"  # Visual feedback while waiting for completion results.

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/compcache"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|=*' 'l:|=*'
zstyle -e ':autocomplete:*:*' list-lines 'reply=( $(( LINES / 3 )) )'

# ---------- Shell behaviour tweaks ----------
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt EXTENDED_GLOB INTERACTIVE_COMMENTS
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS INC_APPEND_HISTORY SHARE_HISTORY
setopt NO_BEEP

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=200000

unsetopt correct_all
unsetopt nomatch

[[ -r ~/.profile ]] && source ~/.profile  # Reuse environment exported in the login shell.

DISABLE_UNTRACKED_FILES_DIRTY="true"  # Speed up git prompts on large repositories.

NVM_LAZY_LOAD=true
POETRY_VIRTUALENVS_IN_PROJECT=true

path_add "$DOTFILES_DIR/bin"

# ---------- Custom functions & aliases ----------
DEFAULT_FUNCTIONS_DIR="$HOME/.config/zsh/functions"
[[ -d "$DOTFILES_DIR/zsh/functions" && ! -d "$DEFAULT_FUNCTIONS_DIR" ]] && DEFAULT_FUNCTIONS_DIR="$DOTFILES_DIR/zsh/functions"
FUNCTIONS_DIR="${DOTFILES_FUNCTIONS:-$DEFAULT_FUNCTIONS_DIR}"
if [[ -d "$FUNCTIONS_DIR" ]]; then
    for func_file in "$FUNCTIONS_DIR"/*.zsh; do
        [[ -r "$func_file" ]] && source "$func_file"
    done
fi

DEFAULT_ALIAS_DIR="$HOME/.config/zsh/alias"
[[ -d "$DOTFILES_DIR/zsh/alias" && ! -d "$DEFAULT_ALIAS_DIR" ]] && DEFAULT_ALIAS_DIR="$DOTFILES_DIR/zsh/alias"
ALIAS_DIR="${DOTFILES_ALIAS:-$DEFAULT_ALIAS_DIR}"
if [[ -d "$ALIAS_DIR" ]]; then
    for alias_file in "$ALIAS_DIR"/*.zsh; do
        [[ -e "$alias_file" && -r "$alias_file" ]] || continue
        source "$alias_file"
    done
fi

# ---------- Language & tooling bootstrap ----------
__conda_setup="$('$HOME/miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
elif [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
    . "$HOME/miniforge3/etc/profile.d/conda.sh"
else
    path_add "$HOME/miniforge3/bin"
fi
unset __conda_setup

path_add "${KREW_ROOT:-$HOME/.krew}/bin"

export CONDA_PROMPT_MODIFIER=""
PROMPT='$(kube_ps1)'$PROMPT  # Show Kubernetes context ahead of the main theme prompt.

[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"  # Go version manager.

if (( $+commands[yazi] )); then
    y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [[ -n $cwd && $cwd != $PWD ]]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

bindkey '^H' backward-kill-word  # Keep Ctrl+Backspace consistent with other shells.

if (( $+commands[starship] )); then
    eval "$(starship init zsh)"
fi

if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi

if [[ -s "$HOME/.bun/_bun" ]]; then
    source "$HOME/.bun/_bun"
fi
export BUN_INSTALL="$HOME/.bun"
path_add "$BUN_INSTALL/bin"

if [[ -d /usr/local/go ]]; then
    export GOROOT=/usr/local/go
    path_add "$GOROOT/bin"
fi
export GOPATH="${GOPATH:-$HOME/go}"
path_add "$GOPATH/bin"

path_add "$HOME/.cargo/bin"

compdef -d _python_argcomplete_global 2>/dev/null
compdef -d -P '*' 2>/dev/null
unfunction _python_argcomplete_global __python_argcomplete_scan_head __python_argcomplete_scan_head_noerr 2>/dev/null
_python_argcomplete_global() { return 1; }
__python_argcomplete_scan_head() { return 1; }
__python_argcomplete_scan_head_noerr() { return 1; }

autoload -Uz compinit && compinit

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"
