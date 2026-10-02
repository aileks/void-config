#!/usr/bin/env bash

[[ -r ~/.bashrc ]] && source ~/.bashrc

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
