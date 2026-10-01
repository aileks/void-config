#!/usr/bin/env bash

[[ $- == *i* ]] || return

# Environment
export PATH="$HOME/.config/emacs/bin:$HOME/.local/bin:$PATH"
export NPM_CONFIG_PREFIX="$HOME/.local"
export GREP_COLORS='mt=1;36'
export LS_COLORS='rs=0:fi=37:di=35:ln=36:ex=32:pi=33:so=33:bd=33:cd=33:or=31:mi=31:su=32:sg=32:tw=35:ow=35:st=35:*.tar=35:*.gz=35:*.bz2=35:*.xz=35:*.zst=35:*.zip=35:*.7z=35:*.rar=35:*.conf=33:*.ini=33:*.toml=33'
export EDITOR='emacsclient -t --alternate-editor='
export VISUAL="$EDITOR"
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
unset MANPAGER
. "$HOME/.config/nnn/env"

# Aliases
alias sudo="doas"
alias sudoedit="doasedit"
alias ls='ls --color=auto --group-directories-first'
alias la='ls -lah --color=auto --group-directories-first'
alias lt="tree -C -a -L 2 --dirsfirst -I '.*'"
alias rm='trash'
alias c='clear'
alias ff='fastfetch && echo'
alias vim='emacsclient -t --alternate-editor='
alias ..="echo 'cd ..'; cd .."
alias hl='rg --passthru'
alias n='nnn -e'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gcl='git clone'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gc='git commit --verbose'
alias gcm='git commit -m'
alias gm='git merge'
alias gd='git diff'
alias gf='git fetch'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias gss='git status --short'
alias gsw='git switch'
alias xup='doas xbps-install -Su'
alias xr='doas xbps-remove -R'
alias xro='doas xbps-remove -O'
alias xqo='xbps-query -o'

hf() {
  local selection
  selection=$(history | fzf --tac | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//') || return
  printf '%s' "$selection" | xclip -selection clipboard
}

# Shell Options
shopt -s cdspell
shopt -s checkwinsize
shopt -s extglob
shopt -s autocd 2>/dev/null || true
shopt -s dirspell 2>/dev/null || true
shopt -s histappend
shopt -s cmdhist
shopt -s lithist
shopt -s progcomp_alias

eval "$(zoxide init bash)"

# Why is this on by default?
stty -ixon

# History
HISTFILE="$HOME/.bash_history"
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups

# Completion
bind 'set completion-ignore-case on'
bind 'set completion-map-case on'
bind 'set show-all-if-ambiguous on'

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
fi

if declare -F _comp_command_offset >/dev/null; then
  _complete_doas() {
    # bash-completion reads and writes these locals through dynamic scope.
    local cur prev words cword comp_args
    _comp_initialize -- "$@" || return

    local i
    for ((i = 1; i < cword; i++)); do
      case ${words[i]} in
        -u | -C)
          if ((i + 1 == cword)); then
            if [[ ${words[i]} == -u ]]; then
              _comp_compgen -- -u
            else
              _comp_compgen_filedir
            fi
            return
          fi
          ((i++))
          ;;
        -s | -L) return ;;
        --)
          _comp_command_offset "$((i + 1))"
          return
          ;;
        -*) ;;
        *) break ;;
      esac
    done

    if ((i == cword)) && [[ $cur == -* ]]; then
      _comp_compgen -- -W '-C -L -n -s -u'
    else
      _comp_command_offset "$i"
    fi
  }
  complete -F _complete_doas doas

  # the default completion loader prevents bash's progcomp_alias fallback
  _complete_alias() {
    local expansion=${BASH_ALIASES[$1]}
    local -a expanded_words
    read -r -a expanded_words <<<"$expansion"

    local COMP_LINE=${COMP_LINE/"$1"/"$expansion"}
    local COMP_POINT=$((COMP_POINT + ${#expansion} - ${#1}))
    local COMP_CWORD=$((COMP_CWORD + ${#expanded_words[@]} - 1))
    local -a COMP_WORDS=("${expanded_words[@]}" "${COMP_WORDS[@]:1}")
    local words
    _comp_command_offset 0
  }

  for alias_name in "${!BASH_ALIASES[@]}"; do
    alias_expansion=${BASH_ALIASES[$alias_name]}
    # leave aliases containing shell syntax alone.
    if [[ $alias_expansion =~ ^[a-zA-Z0-9_./=[:space:]-]+$ &&
      ${alias_expansion%% *} != "$alias_name" ]]; then
      complete -o bashdefault -o default -F _complete_alias "$alias_name"
    fi
  done
  unset alias_name alias_expansion
fi

# fzf settings
export FZF_DEFAULT_OPTS="
  --color=fg:#f3f3f3
  --color=fg+:#090909
  --color=bg:#090909
  --color=bg+:#f3f3f3
  --color=hl:#978e86
  --color=hl+:#090909
  --color=info:#877e76
  --color=marker:#978e86
  --color=prompt:#978e86
  --color=spinner:#aaa198
  --color=pointer:#978e86
  --color=header:#f3f3f3
  --color=border:#514942
  --color=query:#f3f3f3
  --color=gutter:#090909
  --highlight-line
  --info=inline-right
  --layout=reverse
  --pointer='█'
  --scrollbar='▌'
  --multi
  --border=top
"

# Prompt
git_prompt_segment() {
  local output line
  local branch=''
  local ahead=0
  local behind=0
  local dirty=0

  output=$(git status --porcelain=v2 --branch 2>/dev/null) || return

  while IFS= read -r line; do
    case $line in
      '# branch.head '*)
        branch=${line#'# branch.head '}
        ;;

      '# branch.ab '*)
        local ab=${line#'# branch.ab '}
        local a b
        read -r a b <<<"$ab"
        ahead=${a#+}
        behind=${b#-}
        ;;

      *)
        if [[ -n $line && $line != \#* && $line != \!* ]]; then
          dirty=1
        fi
        ;;
    esac
  done <<<"$output"

  if [[ $branch == '(detached)' ]]; then
    branch=$(git rev-parse --short HEAD 2>/dev/null) || return
  fi

  printf ' %s' "$branch"

  ((ahead > 0)) && printf ' ⇡%d' "$ahead"
  ((behind > 0)) && printf ' ⇣%d' "$behind"
  ((dirty)) && printf ' *'
  return 0
}

venv_prompt_name() {
  local key value

  [[ -r $VIRTUAL_ENV/pyvenv.cfg ]] || return 1

  while IFS='=' read -r key value; do
    key=${key//[[:space:]]/}

    if [[ $key == prompt ]]; then
      value=${value#"${value%%[![:space:]]*}"}
      value=${value%"${value##*[![:space:]]}"}

      printf '%s' "$value"
      return
    fi
  done <"$VIRTUAL_ENV/pyvenv.cfg"
}

make_prompt() {
  local status=$1
  local reset=$'\e[0m'
  local bold=$'\e[1m'
  local error=$'\e[38;2;170;161;152m'
  local primary=$'\e[38;2;183;174;166m'
  local secondary=$'\e[38;2;142;133;125m'
  local bright_secondary=$'\e[38;2;174;165;157m'
  local tertiary=$'\e[38;2;170;161;152m'
  local muted=$'\e[38;2;135;126;118m'
  local info=$'\e[38;2;243;243;243m'
  local host=$'\e[38;2;224;215;206m'
  local git_segment=''
  local status_segment=''
  local venv_segment=''
  local jobs_segment=''

  if _prompt_git_text=$(git_prompt_segment); then
    git_segment=" \[${tertiary}\]"'${_prompt_git_text}'"\[${reset}\]"
  fi

  if ((status != 0)); then
    status_segment=" \[${error}\] ${status}\[${reset}\]"
  fi

  if [[ -n ${VIRTUAL_ENV:-} ]]; then
    _prompt_venv_text=$(venv_prompt_name)
    [[ -n $_prompt_venv_text ]] || _prompt_venv_text=${VIRTUAL_ENV##*/}
    venv_segment=" \[${secondary}\] "'${_prompt_venv_text}'"\[${reset}\]"
  fi

  local job_count
  job_count=$(jobs -p | wc -l)

  if ((job_count > 0)); then
    jobs_segment=" \[${info}\]󱑞 ${job_count}\[${reset}\]"
  fi

  PS1="\[${primary}${bold}\]\w\[${reset}\]"
  PS1+="${git_segment}\[${reset}\]"
  PS1+="${venv_segment}"
  PS1+="${jobs_segment}"
  PS1+=" \[${muted}\]• \[${host}\]\h\[${reset}\]"
  PS1+="${status_segment}"
  PS1+="\n\[${bright_secondary}${bold}\]❯\[${reset}\] "
}

_prompt_command() {
  local status=$?

  history -a
  history -n
  make_prompt "$status"

  return "$status"
}

if [[ " ${PROMPT_COMMAND[*]-} " != *' _prompt_command '* ]]; then
  PROMPT_COMMAND=(_prompt_command "${PROMPT_COMMAND[@]}")
fi

# >>> juliaup initialize >>>

# !! Contents within this block are managed by juliaup !!

case ":$PATH:" in
  *:/home/aileks/.juliaup/bin:*)
    ;;

  *)
    export PATH=/home/aileks/.juliaup/bin${PATH:+:${PATH}}
    ;;
esac
# Tab completion for juliaup and julia channel selection
[ -f "/home/aileks/.julia/juliaup/completions/bash.sh" ] && source "/home/aileks/.julia/juliaup/completions/bash.sh"

# <<< juliaup initialize <<<
