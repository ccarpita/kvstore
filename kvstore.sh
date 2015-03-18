#!/bin/bash

_kvstore_found=0

kvstore_usage () {
  if [[ -n "$1" ]]; then
    echo "$1"
    echo
  fi
  echo "kvstore <command> [<namespace>] [arguments...]"
  echo "kvstore [-h|--help]"
  echo
  echo "Interface for a file-based transactional kv store"
  echo
  echo "Commands:"
  echo "  ls"
  echo "    List kv stores (namespaces)"
  echo "  ls <namespace>"
  echo "    List keys in a namespace"
  echo "  get <namespace> <key>"
  echo "    Get value of key"
  echo "  set <namespace> <key> <value>"
  echo "    Set value of key"
  echo "  rm <namespace> <key>"
  echo "    Remove key from store"
  echo "  mv <namespace> <from_key> <to_key>"
  echo "    Move (rename) key.  Fails if the destination key already exists"
  echo
  echo "Environmental Variables:"
  echo "  KVSTORE_DIR"
  echo "    Directory where file stores will be kept, defaults to \$HOME/.kvstore"
  echo
  echo "Shell Initialization"
  echo "  For command completion, add the following to your shell profile:"
  echo "  # File: Shell Profile"
  echo '  $(kvstore shellinit)'
}

kvstore_path () {
  local file="$1"
  local dir="${KVSTORE_DIR:-$HOME/.kvstore}"
  mkdir -p "$dir"
  if [[ -z "$file" ]]; then
    echo "$dir"
  else
    echo "$dir/$file"
  fi
}

kvstore_each () {
  local file="$1"
  local cmd="$2"
  shift
  shift
  local OLDIFS="$IFS"
  IFS=$'\n'
  for line in $(cat "$file"); do
    IFS="$OLDIFS"
    local k=$(echo "$line" | cut -f1)
    local v=$(echo "$line" | cut -f2)
    found=1
    $cmd "$k" "$v" "$@"
  done
}

kvstore_ls () {
  local ns="$1"
  local dir=$(kvstore_path)
  if [[ -z "$ns" ]]; then
    for file in $dir/*; do
      basename "$file"
    done
  else
    local path=$(kvstore_path $ns)
    if [[ ! -f "$path" ]]; then
      echo "Error: path not found: $path" >&2
      return 2
    fi
    cat "$path" | cut -f1
  fi
}

_echo_v_if_k() {
  local k="$1"
  local v="$2"
  local key="$3"
  if [[ "$k" == "$key" ]]; then
    found=1
    echo "$v"
  fi
}

kvstore_get () {
  local ns="$1"
  local key="$2"
  if [[ -z "$ns" ]] || [[ -z "$key" ]]; then
    kvstore_usage "Error: namespace or key missing" >&2
    return 1
  fi
  local file="$(kvstore_path $ns)"
  if [[ ! -f "$file" ]]; then
    echo "Error: namespace file not found: $ns" >&2
    return 2
  fi
  local found=0
  kvstore_each "$file" _echo_v_if_k "$key"
  #if [[ "$?" != '0' ]]; then
  #  echo "Key not found: $key" >&1
  #  return 1
  #fi
}

kvstore_shellinit() {
  local ns="$1"
  declare -i local cpos=1
  declare -i local npos=2
  local cmd="${ns:-kvs}"
  echo "_${ns}_kvstore_complete () {
  declare -i local pos=\$COMP_CWORD
  local cw=\${COMP_WORDS[\$pos]}
  local ns=\"$ns\"
  if [[ -z \"\$ns\" ]] && (( pos > $npos )); then
    ns=\${COMP_WORDS[$npos]}
  fi
  #echo \"ns=\$ns,pos=\$pos,comp=\${COMP_WORDS[@]}\"
  if (( pos == $cpos )); then
    COMPREPLY=( \$( compgen -W \"ls get set rm mv shellinit\" -- \$cw) )
  else
    local OLDIFS=\$IFS
    IFS=\$'\\n'
    COMPREPLY=( \$( compgen -W \"\$(kvstore ls \$ns)\" -- \$cw) )
    IFS=\$OLDIFS
  fi
}
export -f _${ns}_kvstore_complete
$cmd () {
  local ns=\"$ns\"
  if [[ -z \"\$ns\" ]]; then
    kvstore \"\$@\"
    return \$?
  else
    local cmd=\"\$1\"
    shift
    kvstore \"\$cmd\" \"\$ns\" \"\$@\"
    return \$?
  fi
}
complete -F _${ns}_kvstore_complete $cmd"
  if [[ -z "$ns" ]]; then
    echo "complete -F __kvstore_complete kvstore"
  fi
}

kvstore () {
  local cmd="$1"
  if [[ -z "$cmd" ]]; then
    kvstore_usage "Error: Command not specified" >&2
    return 1
  fi
  declare -i local force=0
  case "$cmd" in
    -h|--help)
      kvstore_usage
      return 0
      ;;
    ls)
      kvstore_ls "$2"
      return $?
      ;;
    get)
      kvstore_get "$2" "$3"
      return $?
      ;;
    set)
      kvstore_set "$2" "$3" "$4"
      return $?
      ;;
    rm)
      kvstore_rm "$2" "$3"
      return $?
      ;;
    mv)
      kvstore_mv "$2" "$3" "$4"
      return $?
      ;;
    shellinit)
      kvstore_shellinit "$2"
      return 0
      ;;
    *)
      kvstore_usage "Error: Unrecognized command: $cmd" >&2
      return 1
      ;;
  esac
}
kvstore "$@"
exit $?
