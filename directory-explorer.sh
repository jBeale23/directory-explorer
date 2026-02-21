#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------- #
# Directory Explorer: Adds directory stacking, ls after cd, and fuzzy finding behavior to cd.    #
#                                                                                                #
# MIT License                                                                                    #
# Copyright © 2026 Josh Beale                                                                    #
# Permission is hereby granted, free of charge, to any person obtaining a copy                   #
# of this software and associated documentation files (the "Software"), to deal                  #
# in the Software without restriction, including without limitation the rights                   #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell                      #
# copies of the Software, and to permit persons to whom the Software is                          #
# furnished to do so, subject to the following conditions:                                       #
#                                                                                                #
# The above copyright notice and this permission notice shall be included in all                 #
# copies or substantial portions of the Software.                                                #
#                                                                                                #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR                     #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,                       #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE                    #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER                         #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,                  #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE                  #
# SOFTWARE.                                                                                      #
# ---------------------------------------------------------------------------------------------- #

# ---------------------------- #
# User Configuration Variables #
# ---------------------------- #

# All of these values fall back to their defaults if left unset here.
declare _de_USER_DIRSTACK="$HOME/.dirstack"      # This can be located anywhere the user has write permissions.
declare -i _de_STACK_DISPLAY_LIMIT="5"           # This can be any integer greater than or equal to 1.
declare _de_USER_BOOKMARKS="$HOME/.de_bookmarks" # This can be located anywhere the user has write permissions.
declare _de_CLOBBER_BOOKMARKS=false              # This can be any boolean truthy or falsy value.
declare _de_LS_AFTER_CD=true                     # This can be any boolean truthy or falsy value.
declare _de_FUZZY_SEARCH_WHEN_BLANK=true         # This can be any boolean truthy or falsy value.
# Fuzzy searching requires fzf and tree as additional dependencies.

# --------------------- #
# End of user variables #
# --------------------- #

function _de_usage() {
  cat << EOF
Adds directory stacking, ls after cd, and fuzzy finding behavior to cd.

Usage: ${FUNCNAME[1]} [-L/-P [-e]] [-h] [-v] [-l] [-b] [-s[=][DIRECTORY]/-p[=][0-9]+] [-m[=]<BOOKMARK>[DIRECTORY]/-u[=]<BOOKMARK>] [DIRECTORY]

Options:
	-h, --help					Show this help message and exit.
	    --version					Show version information and exit.
	-l, --list-directories				List the current directory stack.
	-s, --stack-directory [DIRECTORY]		Add the current or specified directory to the top of the directory stack.
	-p, --pop-directory [0-9]+			Pop the top or specified directory from the directory stack and change to it.
	    --purge-directory-stack			Empty the current directory stack.
	-m, --mark-directory <BOOKMARK> [DIRECTORY]	Bookmark the current or specified directory.
	-u, --unmark-directory <BOOKMARK> 		Bookmark the current or specified directory.
	-b, --list-bookmarks				List the current bookmarks.
	    --purge-bookmarks				Remove all bookmarks.
	-L						Resolve symlinks during traversal after processing .. in path (Default Behavior).
	-P						Prevents following symlinks after processing .. in path.
	-e						Return a non-zero status if working directory resolution fails with -P enabled.
EOF
}

function _de_version() {
  cat << EOF
Directory Explorer 0.1.0
Copyright © 2026 Josh Beale <jbeale2023@gmail.com>.
Licence MIT: <https://directory.fsf.org/wiki/License:Expat>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
}

# If there are directories on the stack, list them, one per line, with added line numbers.
# If there are more than $_de_STACK_DISPLAY_LIMIT directories in the stack, truncate the output.
function _de_list-directories() {
  if [ -f "${_de_USER_DIRSTACK:-$HOME/.dirstack}" ]; then
    declare -i STACK_SIZE
    STACK_SIZE=$(wc -l "${_de_USER_DIRSTACK:-$HOME/.dirstack}" | cut -f 1 -d " ")
    [ "$STACK_SIZE" -ge 1 ] || { echo "The directory stack is empty." && return 0; }
    case "$STACK_SIZE" in
      1)
        echo "There is currently $STACK_SIZE directory on the stack."
        ;;
      *)
        echo "There are currently $STACK_SIZE directories on the stack."
        ;;
    esac
    tac "${_de_USER_DIRSTACK:-$HOME/.dirstack}" | head -n "${_de_STACK_DISPLAY_LIMIT:-5}" | cat -n
  else
    echo "The directory stack is empty." && return 0
  fi
}

# Add a directory to the stack.
# Defaults to $PWD if no directory is provided.
function _de_stack-directory() {
  realpath "${1:-"$PWD"}" >> "${_de_USER_DIRSTACK:-$HOME/.dirstack}"
  echo "Added ${1:-"$PWD"} to the stack."
  declare -i STACK_SIZE
  STACK_SIZE=$(wc -l "${_de_USER_DIRSTACK:-$HOME/.dirstack}" | cut -f 1 -d " ")
  (("STACK_SIZE" == 1)) && { echo "There is currently 1 directory on the stack." && return 0; }
  echo "There are currently $STACK_SIZE directories on the stack." && return 0
}

# If there is a directory on top of the stack, pop it and change to it.
# Optionally, instead select the directory specified by user numerical input.
function _de_pop-directory() {
  if [[ $1 =~ [0-9]+ ]]; then
    declare -i DIRNUM="$1"
  else
    declare -i DIRNUM="1"
  fi
  if [ -f "${_de_USER_DIRSTACK:-$HOME/.dirstack}" ]; then
    declare -i STACK_SIZE
    STACK_SIZE=$(wc -l "${_de_USER_DIRSTACK:-$HOME/.dirstack}" | cut -f 1 -d " ")
    [ "$STACK_SIZE" -ge 1 ] || { echo "The directory stack is empty." && return 1; }
    [ "$DIRNUM" -gt "$STACK_SIZE" ] && { echo "Invalid stack index $DIRNUM" && return 1; }
    DIRNUM=$((STACK_SIZE + 1 - DIRNUM))
    local STACK_TOP
    STACK_TOP=$(sed -i -e "$DIRNUM w /dev/stdout" -e "$DIRNUM d" "${_de_USER_DIRSTACK:-$HOME/.dirstack}")
    cdopts+=("$STACK_TOP") &&
      echo "Popped $STACK_TOP from the stack." && {
      if (("$STACK_SIZE" >= 3)); then
        echo "There are currently $((--STACK_SIZE)) directories on the stack."
      elif [[ "$STACK_SIZE" == 2 ]]; then
        echo "There is currently $((--STACK_SIZE)) directory on the stack."
      else
        echo "The directory stack is empty."
      fi
      _de_directory-explorer
    } || return 1
  else
    { echo "The directory stack is empty." && return 1; }
  fi
}

# If there are directories on the stack, empty it.
function _de_purge-directory-stack() {
  if [ -f "${_de_USER_DIRSTACK:-$HOME/.dirstack}" ]; then
    declare -i STACK_SIZE
    STACK_SIZE=$(wc -l "${_de_USER_DIRSTACK:-$HOME/.dirstack}" | cut -f 1 -d " ")
    [ "$STACK_SIZE" -ge 1 ] || { echo "The directory stack is empty." && return 0; }
    echo "Purging $STACK_SIZE directories from the stack."
    rm "${_de_USER_DIRSTACK:-$HOME/.dirstack}"
  fi
}

# Main function for changing to a given target path.
# If $_de_FUZZY_SEARCH_WHEN_BLANK is enabled, launches fzf with tree preview if no path is provided.
function _de_directory-explorer() {
  declare -r TARGET_PATH="${cdopts[-1]}"
  if [ "$TARGET_PATH" == "--" ]; then
    if [ "${_de_FUZZY_SEARCH_WHEN_BLANK:-true}" ]; then
      declare DIR
      DIR=$(find / -type d 2> /dev/null | fzf --preview 'tree {}')
      if [ -n "$DIR" ]; then
        cdopts+=("$DIR")
      fi
    else
      cdopts+=("$HOME")
    fi
  fi
  if [ "$TARGET_PATH" != "--" ]; then
    [ -f "$TARGET_PATH" ] && { echo "$TARGET_PATH is a file." && return 1; }
  fi
  builtin cd "${cdopts[@]}" || return 1
  [ "${_de_LS_AFTER_CD:-true}" ] && ls
}

function de() {
  declare -a cdopts
  if ! OPTS=$(getopt -o hvls::p::LPe --long help,version,list-directories,stack-directory::,pop-directory::,purge-directory-stack -- "$@"); then
    cat << EOF
${FUNCNAME[0]}: error during argument parsing.
Do you have GNU getopt?
EOF
    return 1
  fi

  eval set -- "$OPTS"

  while true; do
    case "$1" in
      -h | --help)
        _de_usage
        return "$?"
        ;;
      -v | --version)
        _de_version
        return "$?"
        ;;
      -l | --list-directories)
        _de_list-directories
        return "$?"
        ;;
      -s | --stack-directory)
        if [ -d "$2" ]; then
          _de_stack-directory "$2"
        else
          _de_stack-directory
        fi
        return "$?"
        ;;
      -p | --pop-directory)
        if [[ $2 =~ [0-9]+ ]]; then
          _de_pop-directory "$2"
        else
          _de_pop-directory
        fi
        return "$?"
        ;;
      --purge-directory-stack)
        _de_purge-directory-stack
        return "$?"
        ;;
      -[LPe])
        cdopts+=("$1")
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        cat << EOF
${FUNCNAME[0]}: invalid option -- '${1}'
Try '${FUNCNAME[0]}' --help' for more information.
EOF
        return 1
        ;;
    esac
  done

  if [ "$#" -gt 1 ]; then
    echo "${FUNCNAME[0]}: Too many target paths provided." && return 1
  fi
  cdopts+=("--")
  [ -n "$1" ] && cdopts+=("$1")
  _de_directory-explorer
  return "$?"
}

# vim: set filetype=bash:
