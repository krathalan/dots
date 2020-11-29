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

# -----------------------------------------
# ----------- Program variables -----------
# -----------------------------------------

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

# Print time since last pacman -Syu upon opening a new terminal
# as long as the time since last pacman -Syu is greater than 24 hours
if check_command pacman; then
  last_pac=$(tac /var/log/pacman.log | grep -m1 -F "[PACMAN] starting full system upgrade" | cut -d "[" -f2 | cut -d "]" -f1)
  time_since=$((($(date +%s)-$(date --date="${last_pac}" +%s))/3600))
  [[ "${time_since}" -gt 23 ]] && printf "\nIt has been %s%s hour%s%s since your last system upgrade\n" "${YELLOW}" "${time_since}" "$([ ${time_since} -ne 1 ] && printf s)" "${NC}"
fi

# -----------------------------------------
# ------------- User variables ------------
# -----------------------------------------

export EDITOR="nano"

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
alias rsync="rsync -a --progress"
alias stow="stow --target=\${HOME}"

# To start building packages in clean chroots, take the following steps.
# 1. Install the `devtools` package:
#     $ sudo pacman -Syu devtools
# 2. Create the chroot directory:
#     $ sudo mkdir -p /var/lib/makechrootpkg
# 3. Install Arch into the chroot:
#     $ sudo mkarchroot /var/lib/makechrootpkg/root base-devel
# 4. Re-source your ~/.bashrc, or restart your terminal
# 5. Start building packages with `makechrootpkg` instead of `makepkg`
if [[ -d "/var/lib/makechrootpkg" ]]; then
  alias arch-nspawn="arch-nspawn /var/lib/makechrootpkg/root"
  # $HOME, $HOME never changes
  # shellcheck disable=SC2139
  alias makechrootpkg="makechrootpkg -c -u -d ${CCACHE_DIR}/:/ccache -r /var/lib/makechrootpkg -- CCACHE_DIR=/ccache"
fi

# Override the `mkarchiso` command with this function.
makearchiso()
{
  # Allow the user a clean exit upon Ctrl+C so as to not
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
  # -o: Set the output directory
  # -w: Set the working directory
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
if check_command bat; then
  alias cat="bat"
  alias less="bat"
  alias tree="exa --long --tree"
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
  comm -23 <(pacman -Qqe | sort) <({ pacman -Qqg base-devel; pacman -Qmq; } | sort -u)
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

# Compares two sums (or any strings, for that matter).
compare_sums()
{
  if [[ $# -gt 1 ]]; then
    if [[ "$1" == "$2" ]]; then
      printf "%s Sums are equal.%s\n" "${GREEN}" "${NC}"
    else
      printf "%s Sums are not equal.%s\n" "${RED}" "${NC}"
    fi
  else
    error "Please specify two sums to compare."
  fi
}

# Specify a directory to compress and an output directory, and you can choose
# from a few different compression programs, each using their multithreaded
# complimentary programs if available. Also optionally encrypt and sign with
# GPG. Outputs the compression ratio and total time to compress/encrypt.
compress_cp()
{
  if [[ $# -gt 1 ]]; then
    # Get full paths
    local directoryToCompress="$1"
    local targetDirectory="$2"

    directoryToCompress="$(readlink -f "${directoryToCompress}")"
    targetDirectory="$(readlink -f "${targetDirectory}")"

    printf "\nWhat kind of compression?"
    printf "\n [1] zstd (default)"
    printf "\n [2] lz4"
    printf "\n [3] xz"
    printf "\n [4] gzip\n\n"
    read -r -p "> " response
    case "${response}" in
      2)
        local -r compression_program="lz4"
        local -r compression_file_ext="lz4"
        ;;
      3)
        local -r compression_program="xz"
        local -r compression_file_ext="xz"
        ;;
      4)
        if check_command "pigz"; then
          local -r compression_program="pigz"
        else
          local -r compression_program="gzip"
        fi
        local -r compression_file_ext="gz"
        ;;
      *)
        # Default
        if check_command "pzstd"; then
          local -r compression_program="pzstd"
        else
          local -r compression_program="zstd"
        fi
        local -r compression_file_ext="zst"
        ;;
    esac

    # Target output file name
    targetOutput="${directoryToCompress##*/}.tar.${compression_file_ext}"

    printf "\nSign and encrypt with key %s? " "${GPG_KEY_ID}"
    read -r -p "[y/N] " response
    local -r start_time="$(date +%s)"
    case "${response}" in
      [yY][eE][sS]|[yY])
        targetOutput="${targetOutput}.gpg"
        tar -I "${compression_program}" -cf - "${directoryToCompress}" | gpg2 -z 0 --default-key "${GPG_KEY_ID}" --recipient "${GPG_KEY_ID}" --sign --encrypt > "${targetDirectory}/${targetOutput}"
        ;;
      *)
        tar -I "${compression_program}" -cf "${targetDirectory}/${targetOutput}" "${directoryToCompress}"
        ;;
    esac
    local -r end_time="$(date +%s)"

    printf "\nOutput compressed archive %s%s/%s%s%s" "${BLUE}" "${targetDirectory}" "${GREEN}" "${targetOutput}" "${NC}"
    # Get the size of the directoryToCompress and the targetOutput file and divide them to get a compression ratio,
    # rounded to the nearest hundredth, e.g. 0.91
    printf "\nCompression ratio: %.2f" "$(echo "$(du -sc "${targetDirectory}/${targetOutput}" | tail -n1 | awk '{printf $1}') / $(du -sc "${directoryToCompress}" | tail -n1 | awk '{printf $1}')" | bc -l)"
    printf "\nTime to compress: %s seconds\n" "$(( end_time - start_time ))"
  else
    error "Please specify (1) a directory to compress and (2) the target directory."
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

  lsblk -f

  printf "\nThis will write ISO file: %s%s%s\nto drive: %s%s%s\n\nContinue? " "${YELLOW}" "$1" "${NC}" "${YELLOW}" "$2" "${NC}"
  read -r -p "[y/N] " response
  case "${response}" in
    [yY][eE][sS]|[yY])
      sudo dd bs=8M status=progress oflag=sync if="$1" of="$2"
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

# Show status of all dirs that are also git repos in $PWD
# For example, a directory structure of:
# $PWD
# ├── apparmor-profiles
# ├── archiso
# ├── dots
# ├── ...
# would result in this function calling the `git status` command
# in each of the subdirectories, e.g. apparmor-profiles/, archiso/,
# dots/, etc.
allgits()
{
  for dir in ~/git/*/ ; do
    printf "===> Printing git status for %s%s%s <===\n" "${GREEN}" "$(basename "${dir}")" "${NC}"
    cd "${dir}" && git status
    cd ..
    printf "\n"
  done
}

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
    git diff "$*" | bat
  else
    git diff | bat
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
  local branch
  branch="$(git status | head -n1)"
  git push origin "${branch/On branch }"
}

# ---------------------------
# ----------- GPG -----------
# ---------------------------

# Encrypts and signs a specified file with the user's personal GPG_KEY_ID
encrypt_file()
{
  if [[ $# -gt 0 ]]; then
    gpg --sign --encrypt --default-key "${GPG_KEY_ID}" --recipient "${GPG_KEY_ID}" "$1"
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

# microv(iew)
# A simple function to open any file readonly with micro
# while adhering to its AppArmor profile
# https://git.sr.ht/~krathalan/apparmor-profiles
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
