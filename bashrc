#!/usr/bin/env bash

# Use bash-completion, if available
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck source=/dev/null
  source /usr/share/bash-completion/bash_completion
fi

# Used to set default commands to others/enable other functionality
check_command() {
  if [[ -n "$(command -v "$1")" ]]; then
    return 0
  else
    return 1
  fi
}

# Print time since past pacman -Syu
if check_command pacman; then
  last_pac=$(tac /var/log/pacman.log | grep -m1 -F "[PACMAN] starting full system upgrade" | cut -d "[" -f2 | cut -d "]" -f1)
  time_since=$((($(date +%s)-$(date --date="${last_pac}" +%s))/3600))
  [[ "${time_since}" -gt 23 ]] && printf "\nIt has been %s%s hour%s%s since your last system upgrade\n" "${YELLOW}" "${time_since}" "$([ ${time_since} -ne 1 ] && printf s)" "${NC}"
fi

##########
# Colors #
##########

readonly GREEN=$(tput bold && tput setaf 2)
readonly RED=$(tput bold && tput setaf 1)
readonly YELLOW=$(tput sgr0 && tput setaf 3)
readonly BLUE=$(tput sgr0 && tput setaf 4)
readonly PURPLE=$(tput sgr0 && tput setaf 5)
readonly CYAN=$(tput sgr0 && tput setaf 6)
readonly NC=$(tput sgr0) # No color/turn off all tput attributes


PS1="\n \$([[ \$? != 0 ]] && printf \"%sX \" \"\${RED}\")\$(if [[ ${EUID} == 0 ]]; then printf \"%s\" \"\${RED}\"; else printf \"%s\" \"\${GREEN}\"; fi)\u\[${BLUE}\]@\h \[${NC}\]\w \[${YELLOW}\]\$(if git branch --show-current &> /dev/null; then git branch --show-current; fi)\n \[${NC}\]> "
# Looks like:
#  anders@desktop ~/git/dots master
#  >

#############
# Variables #
#############

export EDITOR="nano"

# Set XDG dirs
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"

# Move things out of base $HOME
export CCACHE_DIR="${HOME}/.cache/ccache"
export MPV_HOME="${XDG_CONFIG_HOME}/mpv"
export HISTFILE="${XDG_DATA_HOME}/bash_history"
alias irssi='irssi --home="${XDG_CONFIG_HOME}/irssi" --config="${XDG_CONFIG_HOME}/irssi/config"'

###########
# Aliases #
###########

# Keep aliases when using sudo
alias sudo="sudo "

# git
alias gits="git status"
alias gitlog="git log --pretty=oneline --abbrev-commit --show-signature"
alias diff="diff --color"

# Make commands have default flags/args
alias ip="ip --color=auto"
alias rsync="rsync -a --progress"
alias stow="stow --target=\${HOME}"

if [[ -d "/var/lib/makechrootpkg" ]]; then
  alias arch-nspawn="arch-nspawn /var/lib/makechrootpkg/root"
  alias makechrootpkg="makechrootpkg -c -u -d /home/anders/.cache/ccache/:/ccache -r /var/lib/makechrootpkg -- CCACHE_DIR=/ccache"
  alias mkarchiso="sudo rm -rf /tmp/mkarchiso && sudo mkdir /tmp/mkarchiso && mkdir -p ${HOME}/isos && sudo mkarchiso -v -o ${HOME}/isos -w /tmp/mkarchiso ~/git/archiso/; sudo rm -rf /tmp/mkarchiso"
fi


# Redirect some commands to others
if check_command bat; then
  alias cat="bat"
  alias less="bat"
  alias tree="exa --long --tree"
  export PAGER="bat"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
if check_command exa; then
  alias ls="exa --group-directories-first"
  alias lsa="exa -la --group-directories-first"
else
  alias ls="ls --group-directories-first --color=auto"
fi
if check_command rg; then
  alias rg="rg --hidden -g '!**/.git/**'"
  alias grep="rg"
fi

alias sl="ls"
alias s="ls"
alias l="ls"

#############
# Functions #
#############

clean_pkgbuild_dirs()
{
  local -r dirsToClean=("${HOME}/aur-dev" "${HOME}/aur" "${HOME}/git/pkgbuilds")
  local toClean

  for directory in "${dirsToClean[@]}"; do
    if [[ -d "${directory}" ]]; then
      mapfile -t toClean <<< "$(find "${directory}" -type f \( -name "*.gz" -o -name "*.xz" -o -name "*.zst" -o -name "*.log" -o -name "*.sig" \))"

      for file in "${toClean[@]}"; do
        rm -f "${file}"
      done
    else
      printf "\nSkipping %s, does not exist\n" "${directory}"
    fi
  done
}

list_packages_from_repo()
{
  if [[ $# -gt 0 ]]; then
    comm -12 <(pacman -Qq | sort) <(pacman -Slq "$1" | sort)
  else
    error "Please specify a repo to list the packages from."
  fi
}

list_explicitly_installed_packages()
{
  comm -23 <(pacman -Qqe | sort) <({ pacman -Qqg base-devel; pacman -Qmq; } | sort -u)
}

#######
# Git #
#######

allgits()
{
  for dir in ~/git/*/ ; do
    printf "===> Printing git status for %s%s%s <===\n" "${GREEN}" "$(basename "${dir}")" "${NC}"
    cd "${dir}" && git status
    cd ..
    printf "\n"
  done
}

gitcam() # git commit -am
{
  if [[ $# -gt 0 ]]; then
    git commit -am "$1"
  else
    error "Please specify a commit message."
  fi
}

gitd() # git diff {,$*}
{
  if [[ -n "$*" ]]; then
    git diff "$*" | bat
  else
    git diff | bat
  fi
}

pulldiff()
{
  git diff @{1}.. | bat
}

gitpoc() # git push origin [current branch]
{
  local branch
  branch="$(git status | head -n1)"
  git push origin "${branch/On branch }"
}
