#!/bin/bash
# Note: this file is also sourced from ~/.profile by non-bash shells

export EDITOR=vim
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_COLLATE=C
export LESS=-FRSXi
export LESSHISTFILE=-
export PAGER=less
export QT_AUTO_SCREEN_SCALE_FACTOR=1

# Paths {{{

if [ -z "$CUDA_ROOT$CUDA_PATH" ] && [ -d /usr/local/cuda ]; then
  export CUDA_ROOT=/usr/local/cuda
  export CUDA_PATH=/usr/local/cuda
fi

if [ -z "$GOPATH" ] && [ -d ~/.go ]; then
  export GOPATH=~/.go
fi

if [ -z "$CONDA_ROOT" ]; then
  if [ -x ~/.conda/bin/conda ] && ! [ ~/.conda/bin/conda -ef /opt/conda/bin/conda ]; then
    export CONDA_ROOT=~/.conda
  elif [ -x /opt/conda/bin/conda ]; then
    export CONDA_ROOT=/opt/conda
  fi
fi

_maybe_prepend_path() {
  case :$PATH: in *:$1:*) return;; esac  # for dash
  if ! [ -d "$1" ]; then return; fi
  PATH="$1:$PATH"
}

# higher priority last
_maybe_prepend_path "$CUDA_ROOT/bin"
_maybe_prepend_path "$CONDA_ROOT/bin"
_maybe_prepend_path ~/.go/bin
_maybe_prepend_path ~/.dotfiles/bin
_maybe_prepend_path ~/.private/bin
_maybe_prepend_path ~/.local/bin
_maybe_prepend_path ~/.bin
_maybe_prepend_path ~/bin

# }}}

if [ -z "$BASH_VERSION" ]; then
  return
fi

if [[ -z "$PS1" || -z "$HOME" ]]; then
  # non interactive
  return
fi

if [[ -z "$HIDPI" && -f "/run/user/$UID/dconf/user" ]]; then
  if [[ "$(dconf read /org/gnome/desktop/interface/scaling-factor 2>/dev/null)" == *2 ]]; then
    export HIDPI=1
  elif [[ "$(dconf read /org/gnome/desktop/interface/text-scaling-factor 2>/dev/null)" == 1.[2-9]* ]]; then
    export HIDPI=1
  else
    export HIDPI=0
  fi
fi

# Aliases {{{

alias ...='cd ...'
alias ..='cd ..'
alias R='R --no-save --no-restore --quiet'
alias b=byobu-tmux
alias bc='bc -q'
alias cd..='cd ..'
alias cd3='cd "$(scm-root)"'
alias cp='cp -i'
alias cx='chmod a+x'
alias d=docker
alias df='df -h'
alias diff='diff -u'
alias dokcer=docker
alias du='du -h'
alias e=egrep
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias g=grep
alias gdb='gdb --quiet'
alias got=git
alias grep='grep --color=auto'
alias gt=git
alias gti=git
alias issh='ssh -F ~/.dotfiles/ssh-config-insecure'
alias json_pp='python3 -m json.tool'
alias l='ls -l'
alias la='ls -la'
alias le='less'
alias ll='ls -l -h'
alias ls='ls --color=auto --group-directories-first'
alias mv='mv -i'
alias nb=jupyter-notebook
alias nvidia-mon='nvidia-smi dmon -s pucvmet -o T'
alias octave='octave -q'
alias parallel='parallel --will-cite'
alias py2=ipython
alias py3=ipython3
alias py=ipython3
alias rm='rm -i'
alias rsync='rsync --info=progress2'
alias rsyncp='rsync --info=progress2'
alias sqlite3='sqlite3 -header -column'
alias sqlite='sqlite3 -header -column'
alias susl='sort | uniq -c | sort -nr | less'
alias venv='python3 -m venv'
alias virt-manager='GDK_SCALE=1 virt-manager'

if hash python3 >/dev/null 2>&1 && ! hash python >/dev/null 2>&1; then
  alias python=python3
fi

mk() { mkdir -p "$@" && cd "$@"; }
mkd() { mkdir -p "$@" && cd "$@"; }

ts() {
  if [[ "$1" == "" ]]; then
    /usr/bin/ts "%.T"
  else
    /usr/bin/ts "$@"
  fi
}
alias tsd='ts "%Y-%m-%d %.T"'

# }}}

# History {{{
# * keep deduped in ~/.history/bash.YYYYMM files
# * load last few months on startup
# * append to last history file but don't read back
# * force to re-read history: h

shopt -s cmdhist histverify histreedit

HISTFILE=
if ! [[ -d ~/.history ]] && ([[ -f ~/.history ]] || ! mkdir -m 0700 -p ~/.history); then
  # history disabled
  HISTCONTROL=ignoreboth
  HISTSIZE=100000
else
  shopt -s histappend
  HISTCONTROL=ignoreboth
  HISTFILESIZE=-1
  HISTIGNORE='bg:fg:clear:ls:pwd:history:exit'
  HISTSIZE=100000
  HISTTIMEFORMAT='[%F %T] '

  # Flush history, dedup and reread recent history files
  __run_erasedup() {
    if [[ -n "$HISTFILE" ]]; then
      history -a
      history -c
    fi

    local interp=""
    if hash python2.7 >/dev/null 2>&1; then
      interp=python2.7
    elif hash python3 >/dev/null 2>&1; then
      interp=python3
    elif hash python >/dev/null 2>&1; then
      interp=python
    fi

    if [[ -n "$interp" && -f ~/.dotfiles/bin/erasedups.py ]]; then
      local histf
      for histf in $($interp ~/.dotfiles/bin/erasedups.py --bashrc "$HOME/.history/bash.%Y%m"); do
        history -r "$histf"
        HISTFILE="$histf"    # last month
      done
    elif [[ -n "$HISTFILE" ]]; then
      history -r
    fi
  }
  __run_erasedup

  # Hook for PROMPT_COMMAND
  __prompt_history() { history -a; }

  # Re-read history to synchronize with other shell instances
  # Also fix background color guess
  h() { __run_erasedup; hash -r; __guess_colorfgbg; }
fi

# }}}

# Prompt {{{

# For use in PROMPT_COMMAND: print last command's exit code if non zero.
__prompt_print_status() {
  local __status=$?
  if [[ $__status -ne 0 ]]; then
    echo -e "\033[31m\$? = ${__status}\033[m"
  fi
}

# Parameter: PS1_COLOR.
__setup_ps1() {
  # set variable identifying the chroot you work in (used in the prompt below)
  if [[ -z "$debian_chroot" && -r /etc/debian_chroot ]]; then
    debian_chroot=$(cat /etc/debian_chroot)
  fi

  if [[ -z "$PS1_COLOR" ]]; then
    local groups=" $(id -nG) "
    if [[ $UID == 0 ]]; then
      PS1_COLOR=31
    elif [[ "$groups" == *" sudo " && ! "$groups" == *" audio "* ]]; then
      PS1_COLOR=31
    else
      PS1_COLOR=32
    fi
  fi

  if [[ "$TERM" == "dumb" ]]; then
    PS1='\u@\h:\w\$ '
  else
    if ((PS1_COLOR < 0)); then  # 256 colors
      PS1_COLOR=$((-PS1_COLOR))
      PS1_COLOR="38;5;${PS1_COLOR}"
    fi
    PS1="\[\033[01;36m\]\A\[\033[m\] "                  # HH:MM
    PS1+="\[\033[01;${PS1_COLOR}m\]\u@${PS1_HOST:-\h}"  # user@host
    PS1+="\[\033[00m\]:"                                # :
    PS1+="\[\033[01;34m\]\w\[\033[00m\]"                # workdir
    if declare -f -F __git_ps1 >/dev/null; then
      PS1+='\[\033[35m\]$(__git_ps1)\[\033[00m\]'
    fi
    PS1+='\$ '
  fi

  # If this is an xterm set the title to user@host:dir
  if [[ "$TERM" == xterm* || "$TERM" == rxvt* ]]; then
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
  fi

  if [[ -n "$VIRTUAL_ENV" ]]; then
    PS1="(${VIRTUAL_ENV##*/}) $PS1"
  fi
  if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    PS1="(${CONDA_DEFAULT_ENV}) $PS1"
  fi

  unset PS1_COLOR
  unset PS1_HOST
}

__setup_prompt_command() {
  [[ ";$PROMPT_COMMAND;" == *__prompt_print_status* ]] && return

  declare -f -F __prompt_history >/dev/null 2>&1 &&
    PROMPT_COMMAND="__prompt_history;$PROMPT_COMMAND"

  # Has to be the first thing in PROMPT_COMMAND to get correct $?
  PROMPT_COMMAND="__prompt_print_status;$PROMPT_COMMAND"
}

unset PROMPT_COMMAND

# }}}

# __guess_colorfgbg {{{
# Automatically determine terminal's background color and set rxvt's var for vim
function __guess_colorfgbg() {
  if [[ -n "$COLORFGBG" && -z "$COLORBG_GUESS" ]]; then
    # rxvt like
    return
  fi

  unset COLORBG_GUESS
  if [[ "$TERM" == "linux" ||
        "$TERM" == "screen" ||
        "$TERM" == "screen-256color" ||
        "$TERM" == "screen.linux" ||
        "$TERM" == "xterm-256color" ||
        "$TERM" == "cygwin" ||
        "$TERM" == "putty" ||
        -n "$GUAKE_TAB_UUID" ||      # guake
        -n "$PYXTERM_DIMENSIONS" ||  # jupyterlab
        -n "$CHROME_REMOTE_DESKTOP_DEFAULT_DESKTOP_SIZES"  # ssh applet
       ]]; then
    export COLORBG_GUESS="dark"
  else
    local prev_stty="$(stty -g)"
    stty raw -echo min 0 time 0
    printf "\033]11;?\033\\"

    # sometimes terminal can be slow to respond
    local response=""
    local i=0
    while ((i < 15)); do
      if [[ "$i" -le 10 ]]; then
        sleep 0.01
      else
        sleep 0.1
      fi
      read -r response
      if [[ "$response" != "" ]]; then
        break
      fi
      i=$((i + 1))
    done
    stty "$prev_stty"

    if [[ "$response" == *rgb:[0-8]* ]]; then
      export COLORBG_GUESS="dark"
    else
      export COLORBG_GUESS="light"
    fi
  fi

  if [[ "$COLORBG_GUESS" == "dark" ]]; then
    export COLORFGBG="15;default;0"
  elif [[ "$COLORBG_GUESS" == "light" ]]; then
    export COLORFGBG="0;default;15"
  else
    unset COLORFGBG
  fi
}

__guess_colorfgbg
# }}}

if [[ $UID == 0 ]]; then
  umask 027
fi

shopt -s autocd checkhash checkwinsize no_empty_cmd_completion

# Fix for 'Could not add identity "~/.ssh/id_ed25519": communication with agent failed'
#if [[ -x /usr/bin/keychain && -f ~/.ssh/id_ed25519 ]]; then
#  eval $(/usr/bin/keychain --eval -Q --quiet --agents ssh)
#fi

if [[ -z "$LS_COLORS" && -x /usr/bin/dircolors ]]; then
  eval $(dircolors ~/.dotfiles/dircolors)
fi

if [[ -n "$VTE_VERSION" ]]; then
  if [[ -f /etc/profile.d/vte.sh ]]; then
    source /etc/profile.d/vte.sh
  elif [[ -f /etc/profile.d/vte-2.91.sh ]]; then
    source /etc/profile.d/vte-2.91.sh
  fi
fi

if [[ -f /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi

if ! [[ -d ~/.ssh/socket ]]; then
  mkdir -p ~/.ssh/socket >/dev/null 2>&1
  chmod 0700 ~/.ssh ~/.ssh/socket >/dev/null 2>&1
fi

if [[ -f ~/.private/bashrc ]]; then
  source ~/.private/bashrc
elif [[ -f ~/.bashrc.local ]]; then
  source ~/.bashrc.local
fi

declare -f -F __setup_prompt_command >/dev/null 2>&1 && __setup_prompt_command
declare -f -F __setup_ps1 >/dev/null 2>&1 && __setup_ps1
unset __setup_prompt_command
unset __setup_ps1

if [[ ! -z "$CONDA_ROOT" && -f "$CONDA_ROOT/etc/profile.d/conda.sh" ]]; then
  source "$CONDA_ROOT/etc/profile.d/conda.sh"
fi

if [[ -d ~/.history ]]; then
  link_to_history() {
    local src="$1"
    local dst="$HOME/.history/$2"
    if [[ -L "$src" && ! -f "$src" ]]; then
      # broken symlink
      rm -f "$src"
    fi
    if [[ -f "$src" && ! -L "$src" ]]; then
      if [[ -f "$dst" ]]; then
        cat "$dst" "$src" >>"$dst.$$" &&
          mv -f "$dst.$$" "$dst" &&
          rm -f "$src" &&
          ln -s --relative "$dst" "$src"
      else
        mv "$src" "$dst" && ln -s --relative "$dst" "$src"
      fi
    fi
  }
  link_to_history ~/.julia/logs/repl_history.jl julia
  link_to_history ~/.mysql_history mysql
  link_to_history ~/.psql_history psql
  link_to_history ~/.python_history python
  link_to_history ~/.sqlite_history sqlite
  unset -f link_to_history

  if [[ -f ~/.history/sqlite ]]; then
    export SQLITE_HISTORY=~/.history/sqlite
  fi
fi

if hash bazel >/dev/null 2>&1 && [[ -d ~/.cache && ! -L ~/.cache/bazel && ! -d ~/.cache/bazel ]]; then
  ln -s /var/tmp ~/.cache/bazel
fi

for _f in ~/.lesshst ~/.wget-hsts ~/.xsel.log ~/.xsession-errors ~/.xsession-errors.old; do
  if [[ -f "$_f" ]]; then
    rm -f "$_f"
  fi
done
unset _f
