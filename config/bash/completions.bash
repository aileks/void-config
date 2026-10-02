#!/usr/bin/env bash

bind 'set completion-ignore-case on'
bind 'set completion-map-case on'
bind 'set show-all-if-ambiguous on'

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
fi

if declare -F _comp_command_offset > /dev/null; then
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
    read -r -a expanded_words <<< "$expansion"

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
