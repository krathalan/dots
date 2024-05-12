#!/usr/bin/env bash

#                      ===> WARNING! <===
# This file assumes you have the following programs installed:
# - eza (replaces ls)
# - ripgrep (replaces grep)
# - micro (default editor)

# Use bash-completion, if available
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck source=/dev/null
  source /usr/share/bash-completion/bash_completion
fi

# Use grc colorizer, if available
# shellcheck disable=2034
GRC_ALIASES=true
if [[ -f /etc/profile.d/grc.sh ]]; then
  # shellcheck source=/dev/null
  source /etc/profile.d/grc.sh
fi

# -----------------------------------------
# ----------- Program variables -----------
# -----------------------------------------

GREEN=$(tput bold && tput setaf 2)
RED=$(tput bold && tput setaf 1)
YELLOW=$(tput sgr0 && tput setaf 3)
BLUE=$(tput sgr0 && tput setaf 4)
PURPLE=$(tput sgr0 && tput setaf 5)
CYAN=$(tput sgr0 && tput setaf 6)
NC=$(tput sgr0) # No color/turn off all tput attributes
GREY=$(tput sgr0 && tput setaf 8)
WHITE=$(tput sgr0 && tput bold)

readonly GREEN RED YELLOW BLUE PURPLE CYAN NC GREY WHITE

determine_git_status()
{
  local -r gitBranch="$(git branch --show-current 2>&1)"

  case "${gitBranch}" in
    fatal*) exit ;;
    *) 
      local -r gitStatus="$(git status 2>&1)"
      if [[ "${gitStatus}" == "HEAD"* ]]; then
        printf "%s " "${gitStatus%%\n*}"
      else
        printf "[%s] " "${gitBranch}"
      fi
      ;;
  esac
}

PS1="\n \$([[ \$? != 0 ]] && printf \"%sX \" \"\${RED}\")\$(if [[ ${EUID} == 0 ]]; then printf \"%s\" \"\${RED}\"; else printf \"%s\" \"\${PURPLE}\"; fi)\u\[${BLUE}\]@\h \[${NC}\]\w \[${YELLOW}\]\$(determine_git_status)${GREY}\$(date "+%H:%M:%S")\n \[${NC}\]> "
# Looks like:
#  user@hostname ~/git/repo [branch]
#  >

if [[ -e /var/log/pacman.log ]]; then
  # Print time since last pacman -Syu upon opening a new terminal
  # as long as the time since last pacman -Syu is greater than 24 hours
  last_pac=$(tac /var/log/pacman.log 2>/dev/null | grep -m1 -F "[PACMAN] starting full system upgrade" | cut -d "[" -f2 | cut -d "]" -f1)
  time_since=$((($(date +%s)-$(date --date="${last_pac}" +%s))/3600))

  if [[ "${time_since}" -gt 23 ]]; then
    pacman_notification="${time_since} hours"
    if [[ "${time_since}" -gt 47 ]]; then
      time_since=$(( time_since / 24 ))
      pacman_notification="${time_since} days"
    fi
    printf "\nIt has been %s%s%s since your last system upgrade\n" "${YELLOW}" "${pacman_notification}" "${NC}"
  fi
fi

# -----------------------------------------
# ------------- User variables ------------
# -----------------------------------------

export EDITOR="micro"

# Set XDG dirs
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"

# Move things out of base $HOME
export CCACHE_DIR="${HOME}/.cache/ccache"
[[ ! -d "${CCACHE_DIR}" ]] && mkdir -p "${CCACHE_DIR}"
export MPV_HOME="${XDG_CONFIG_HOME}/mpv"
export HISTFILE="${XDG_DATA_HOME}/bash_history"
alias irssi='irssi --home="${XDG_CONFIG_HOME}/irssi" --config="${XDG_CONFIG_HOME}/irssi/config"'

# -----------------------------------------
# ---------------- Aliases ----------------
# -----------------------------------------

# Keep aliases when using sudo
alias sudo="sudo "

# git
alias gits="git status"
alias gitlog="git log --pretty=oneline --abbrev-commit --show-signature"
alias diff="diff --color"

# Make commands have default flags/args
alias ip="ip --color=auto"
alias rsync="rsync -a -z --compress-choice=lz4 --progress"
alias stow="stow --target=\${HOME}"

# To start building packages in clean chroots, take the following steps.
# 1. Install the `devtools` package:
#     $ sudo pacman -Syu devtools
# 2. Create the chroot directory:
#     $ sudo mkdir -p /var/lib/makechrootpkg
# 3. Install Arch into the chroot:
#     $ sudo mkarchroot /var/lib/makechrootpkg/root base base-devel
# 4. Re-source your ~/.bashrc, or restart your terminal
# 5. Start building packages with `makechrootpkg` instead of `makepkg`
if [[ -d "/var/lib/makechrootpkg" ]]; then
  alias upgrade_chroot="arch-nspawn /var/lib/makechrootpkg/root pacman -Syu --noconfirm"
  alias update_chroot="arch-nspawn /var/lib/makechrootpkg/root pacman -Syu --noconfirm"
  # $HOME, $HOME never changes
  # shellcheck disable=SC2139
  alias makechrootpkg="makechrootpkg -c -d ${CCACHE_DIR}/:/ccache -r /var/lib/makechrootpkg -- CCACHE_DIR=/ccache"
fi

# My personal way to make Arch isos.
makearchiso()
{
  # Allow the user a clean exit upon immediate Ctrl+C so as to not
  # continually spawn sudo prompts
  sudo true || return

  local -r iso_build_dir="/tmp/mkarchiso"
  [[ -d "${iso_build_dir}" ]] &&
    sudo rm -rf "${iso_build_dir}"
  sudo mkdir -p "${iso_build_dir}"

  local -r output_dir="${HOME}/isos"
  [[ ! -d "${output_dir}" ]] &&
    mkdir -p "${output_dir}"


  # $ mkarchiso --help
  # -v: Enable verbose output
  # -o: Set the output directory ($HOME/isos)
  # -w: Set the working directory (/tmp/mkarchiso)
  # $PWD: expected directory of archiso config files (e.g. packages.x86_64)
  sudo mkarchiso \
    -v \
    -o "${output_dir}" \
    -w "${iso_build_dir}" \
    "${PWD}"

  # Clean up tmp dirs
  sudo rm -rf "${iso_build_dir}"
}

# Redirect some commands to others
alias bt="bluetoothctl"

alias ls="eza --group-directories-first"
alias lsa="eza -la --group-directories-first"
alias tree="eza --long --tree --group-directories-first"

alias rg="rg --hidden -g '!**/.git/**'"
alias grep="rg"

alias sl="ls"
alias s="ls"
alias l="ls"

# -----------------------------------------
# --------------- Functions ---------------
# -----------------------------------------

# Used by this file for nice error message printing
error()
{
  printf "%sError:%s %s\n" "${RED}" "${NC}" "$1"
}

# ---------------------------
# ----------- Arch ----------
# ---------------------------

# Removes old packages built with make(chroot)pkg
clean_pkgbuild_dirs()
{
  local -r dirsToClean=("${HOME}/aur" "${HOME}/git")
  local toClean

  for directory in "${dirsToClean[@]}"; do
    if [[ -d "${directory}" ]]; then
      mapfile -t toClean <<< "$(find "${directory}" -type f \( -name "*.pkg.tar*" -o -name "*.log" \))"

      for file in "${toClean[@]}"; do
        (
          # cd into file's base directory
          cd "${file%/*}" || exit

          # Ensure file is not tracked by git
          if ! git ls-files --error-unmatch "${file}" &> /dev/null; then
            rm -f "${file}"
          fi
        )
      done
    else
      printf "\nSkipping %s, does not exist\n" "${directory}"
    fi
  done
}

# Lists packages from a specified repo, e.g. "community"
list_packages_from_repo()
{
  if [[ $# -gt 0 ]]; then
    comm -12 <(pacman -Qq | sort) <(pacman -Slq "$1" | sort)
  else
    error "Please specify a repo to list the packages from."
  fi
}

# Lists explicitly installed packages, filtering out packages from the
# base-devel group and manually installed packages (e.g. from the AUR)
list_explicitly_installed_packages()
{
  comm -23 <(pacman -Qqe | sort) <(pacman -Qmq | sort -u)
}

# ---------------------------
# ----------- Dict ----------
# ---------------------------

define()
{
  if [[ $# -gt 0 ]]; then
    dict -d gcide "$1" | less
  else
    error "Please specify a word to define."
  fi
}

thesaurize()
{
  if [[ $# -gt 0 ]]; then
    dict -d moby-thesaurus "$1" | less
  else
    error "Please specify a word to thesaurize."
  fi
}

# ---------------------------
# ----- File Operations -----
# ---------------------------

# Compares two strings.
compare_strings()
{
  if [[ $# -gt 1 ]]; then
    if [[ "$1" == "$2" ]]; then
      printf "%s Strings are equal.%s\n" "${GREEN}" "${NC}"
    else
      printf "%s Strings are not equal.%s\n" "${RED}" "${NC}"
    fi
  else
    error "Please specify two strings to compare."
  fi
}

# Outputs a .gif file that plays the original, but backwards.
reverse_gif()
{
  if [[ $# -gt 0 ]]; then
    # Remove .gif extension
    local filename
    filename=$(basename -- "$1")
    filename="${filename%.*}"
    convert "${filename}.gif" -coalesce -reverse -layers OptimizePlus "${filename}-reversed.gif"
  else
    error "Please specify a gif file to reverse."
  fi
}

# Never remember the arguments for dd again!
# $1: iso file (e.g. arch-09-2019.iso)
# $2: drive to write to (e.g. /dev/sdd)
write_iso()
{
  [[ $# -lt 1 ]] &&
    error "Please specify (1) an ISO file and (2) a drive to write to, e.g. /dev/sdd."

  printf "%sDisk information for %s:%s\n" "${YELLOW}" "$2" "${NC}"
  lsblk -f "$2"

  local -r size="$(printf "scale=1; %s/1024/1024\n" "$(stat --printf="%s" "$1")" | bc -l)"
  printf "\nThis will write ISO file: %s%s%s (%s MB)\n                to drive: %s%s%s\n" "${YELLOW}" "$1" "${NC}" "${size}" "${YELLOW}" "$2" "${NC}"

  if [[ "$2" =~ [0-9] ]]; then
    printf "\n%sWARNING:%s Are you sure you want to write to a partition (e.g. /dev/sda1) and not the drive (e.g. /dev/sda)?" "${RED}" "${NC}"
  fi

  printf "\nContinue? "
  read -r -p "[y/N] " response
  case "${response}" in
    [yY][eE][sS]|[yY])
      local command_to_run="sudo dd bs=8M status=progress oflag=sync if=$1 of=$2"
      printf "\nRunning command: %s%s%s\n" "${YELLOW}" "${command_to_run}" "${NC}"
      ${command_to_run}
      ;;
    *)
      printf "Writing ISO cancelled.\n"
      return
      ;;
  esac
}

# ---------------------------
# ----------- Git -----------
# ---------------------------

gitcam() # git commit -am "$1"
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
    git diff "$*" | bat --style=numbers,grid
  else
    git diff | bat --style=numbers,grid
  fi
}

# Show the (git-)difference between the current commit of the git repository
# (in $PWD) and the commit of the repo before the last git pull/fetch.
pulldiff()
{
  # Disable shellcheck here as the @{1} argument is
  # git-specific and is not parsed by bash
  # shellcheck disable=SC1083
  git diff @{1}.. | bat
}

gitpoc() # git push origin [current branch]
{
  git push origin "$(git rev-parse --abbrev-ref HEAD)"
}

gitpac() # git push ALL [current branch]
{
  local -r branch="$(git rev-parse --abbrev-ref HEAD)"

  local remotes
  mapfile -t remotes <<< "$(git remote)"

  for remote in "${remotes[@]}"; do
    git push "${remote}" "${branch}"
  done
}

# ---------------------------
# ----------- GPG -----------
# ---------------------------

# Encrypts and signs a specified file with the user's personal GPG_KEY_ID
encrypt_file()
{
  if [[ $# -gt 0 ]]; then
    gpg --sign --encrypt --default-key "${GPG_KEY_ID}" --recipient "${GPG_KEY_ID}" "$1"
    printf "%sDon't forget to delete the original unencrypted file.%s\n" "${YELLOW}" "${NC}"
  else
    error "Please specify a file to encrypt."
  fi
}

# Easily allows you to export your GPG public key without remembering the flags
export_gpg_pubkey()
{
  if [[ $# -gt 0 ]]; then
    gpg --armor --export "$1"
  else
    error "Please specify a key to export."
  fi
}

# ---------------------------
# ----------- Misc ----------
# ---------------------------

generate_postfix_summary()
{
  sudo journalctl --unit=postfix.service | pflogsumm | less
}

# microv(iew)
# A simple function to open any file readonly with micro
# while adhering to its AppArmor profile
# https://github.com/krathalan/apparmor-profiles
microv()
{
  if [[ $# -gt 0 ]]; then
    local -r fileToCopy="$1"
    local -r TMP_DIR="$(mktemp -d -t "microv.XXXXXXXX")"

    # Replace any slashes with hyphens, e.g. "/etc/pacman.conf" becomes
    # "-etc-pacman.conf"
    local -r targetFile="${TMP_DIR}/file-${fileToCopy//\//-}"

    cp "${fileToCopy}" "${targetFile}"
    micro -readonly true "${targetFile}"

    printf "Cleaning up..."
    rm -rf "${TMP_DIR}"
    printf "done.\n"
  else
    error "Please specify a file to view."
  fi
}

# Rotate a PDF 90 degrees
rotate_pdf()
{
  [[ $# -lt 1 ]] &&
    error "Please specify pdf(s) to rotate."

  local baseFileName=""

  for pdf in "$@"; do
    if [[ "${pdf}" != *".pdf" ]]; then
      printf "%s is not a pdf, skipping" "${pdf}"
      continue
    fi

    # Get file name without ".pdf" extension
    baseFileName="${pdf%%.*}"
    qpdf "${baseFileName}.pdf" "${baseFileName}-rotated.pdf" --rotate=90
    mv "${baseFileName}-rotated.pdf" "${baseFileName}.pdf"
    printf "%s rotated\n" "${baseFileName}.pdf"
  done
}
