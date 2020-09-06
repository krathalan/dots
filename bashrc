#!/usr/bin/env bash

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

#############
# Variables #
#############

export EDITOR="nano"

# Less
export PAGER="bat"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Set XDG dirs
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"

# Move things out of base $HOME
export MPV_HOME="${XDG_CONFIG_HOME}/mpv"
export HISTFILE="${XDG_DATA_HOME}/bash_history"

###########
# Aliases #
###########

alias ls="ls --group-directories-first --color=auto"

# git
alias gits="git status"
alias diff="diff --color"

# Make commands have default flags
alias gitlog="git log --pretty=oneline --abbrev-commit --show-signature"
alias ip="ip --color=auto"
alias makechrootpkg="makechrootpkg -c -u -r /var/lib/makechrootpkg"

# Redirect some commands to others
alias cat="bat"
alias less="bat"
alias ls="exa --group-directories-first"
alias lsa="exa -la --group-directories-first"
alias sl="ls"
alias s="ls"
alias l="ls"
alias tree="exa --long --tree"

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
