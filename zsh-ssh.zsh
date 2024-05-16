#!/usr/bin/env zsh

setopt no_beep # don't beep

SSH_CONFIG_FILE="${SSH_CONFIG_FILE:-$HOME/.ssh/config}"

# Parse the file and handle the include directive.
__parse_config_file() {
  # Enable PCRE matching
  setopt localoptions rematchpcre globdots extendedglob
  unsetopt nomatch

  local config_file_path=$(realpath "$1")
  while IFS= read -r line || [[ -n "$line" ]]; do
    # @hack: black POSIX magic is here:
    # ${line##[[:space:]]#} : trim leading whitespaces
    # ${line%%[[:space:]]#\#[^_]*} : trim trailing whitespaces and comments except '#_'
    line="${${line##[[:space:]]#}%%[[:space:]]#\#[^_]*}"
    # Ignore empty lines
    if [[ -z $line ]]; then
      continue
    fi
    # Load includes recursively
    if [[ $line =~ ^[Ii]nclude[[:space:]]+(.*) ]] && (( $#match > 0 )); then
      local include_paths="${match[1]}"
      # Collect multiple inline includes
      for include_path in $include_paths; do
        if [[ $include_path == ~* ]]; then
          # Replace the first occurrence of "~" in the string with the value of the environment variable HOME.
          local expanded_include_path=${include_path/#\~/$HOME}
        else
          local expanded_include_path="$HOME/.ssh/$include_path"
        fi
        # `~` used to force the expansion of wildcards in variables
        for include_file_path in $~expanded_include_path; do
          if [[ -f "$include_file_path" ]]; then
            __parse_config_file "$include_file_path"
          fi
        done
      done
      continue
    fi
    # Separate 'Host' and 'Match' sections with empty line
    if [[ $line =~ ^[Hh]ost[[:space:]] ]] || [[ $line =~ ^[Mm]atch[[:space:]] ]]; then
      echo
    fi
    echo "$line"
  done < "$config_file_path"
}

__ssh_host_list() {
  local basedir ssh_config host_list

  ssh_config=$(__parse_config_file $SSH_CONFIG_FILE)
  # "${${(%):-%x}:P:h}" is a cwd, but we need exact plugin locations anywhere
  # Also, plugin must be sourced via full path, for correct whence work
  basedir=$(command dirname $(whence -v $0 | command sed 's#.* /#/#'))
  host_list=$(echo "${ssh_config}" | command python3 "${basedir}/host_list_process.py" 2>/dev/null)

  for arg in "$@"; do
    case $arg in
    -*) shift;;
    *) break;;
    esac
  done

  host_list=$(command grep -i "$1" <<< "$host_list")

  echo $host_list
}


__fzf_list_generator() {
  local header host_list

  if [ -n "$1" ]; then
    host_list="$1"
  else
    host_list=$(__ssh_host_list)
  fi

  header="
Alias|->|Hostname|Desc
"

  host_list="${header}\n${host_list}"

  echo -e $host_list | command column -t -s '|'
}

__set_lbuffer() {
  local result selected_host connect_cmd is_fzf_result
  result="$1"
  is_fzf_result="$2"

  if [ "$is_fzf_result" = false ] ; then
    result=$(cut -f 1 -d "|" <<< ${result})
  fi

  selected_host=$(cut -f 1 -d " " <<< ${result})
  connect_cmd="ssh ${selected_host}"

  LBUFFER="$connect_cmd"
}

fzf-complete-ssh() {
  local tokens cmd result selected_host
  setopt localoptions noshwordsplit noksh_arrays noposixbuiltins

  tokens=(${(z)LBUFFER})
  cmd=${tokens[1]}

  if [[ "$LBUFFER" =~ "^ *ssh$" ]]; then
    zle ${fzf_ssh_default_completion:-expand-or-complete}
  elif [[ "$cmd" == "ssh" ]]; then
    result=$(__ssh_host_list ${tokens[2, -1]})
    fuzzy_input="${LBUFFER#"$tokens[1] "}"

    if [ -z "$result" ]; then
      zle ${fzf_ssh_default_completion:-expand-or-complete}
      return
    fi

    if [ $(echo $result | wc -l) -eq 1 ]; then
      __set_lbuffer $result false
      zle reset-prompt
      # zle redisplay
      return
    fi

    result=$(__fzf_list_generator $result | fzf \
      --height=40% \
      --ansi \
      --border \
      --cycle \
      --info=inline \
      --header-lines=1 \
      --list-border=none \
	  --no-sort \
      --prompt='SSH Remote > ' \
      --query=$fuzzy_input \
      --no-separator \
      --bind 'shift-tab:up,tab:down,bspace:backward-delete-char/eof' \
      --preview 'ssh -GT $(cut -f 1 -d " " <<< {}) | grep -E -i -e "^host |^user |^hostname |^port |^controlpath |^forwardagent |^localforward |^identityfile |^remoteforward |^proxycommand |^proxyjump |^forkafterauthentication " | column -t' \
      --preview-window=right:40%
    )

    if [ -n "$result" ]; then
      __set_lbuffer $result true
      zle accept-line
    fi

    zle reset-prompt
    # zle redisplay

  # Fall back to default completion
  else
    zle ${fzf_ssh_default_completion:-expand-or-complete}
  fi
}


[ -z "$fzf_ssh_default_completion" ] && {
  binding=$(bindkey '^I')
  [[ $binding =~ 'undefined-key' ]] || fzf_ssh_default_completion=$binding[(s: :w)2]
  unset binding
}


zle -N fzf-complete-ssh
bindkey '^I' fzf-complete-ssh

# vim: set ft=zsh sw=2 ts=2 et
