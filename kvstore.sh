#!/bin/bash

kvstore_usage () {
  if [[ -n "$1" ]]; then
    echo "$1"
    echo
  fi
  echo "kvstore <command> [<namespace>] [arguments...]"
  echo "kvstore [-h|--help]"
  echo "kvstore [-v|--version]"
  echo
  echo "Interface for a file-based transactional kv store"
  echo
  echo "Commands:"
  echo "  ls"
  echo "    List kv stores (namespaces)"
  echo "  keys <namespace>"
  echo "    List keys in a namespace"
  echo "  vals <namespace>"
  echo "    List values in a namespace"
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
  echo "  \$(kvstore shellinit)"
  echo
  echo "Version - 2.0"
}

_kvstore_path () {
  local file="$1"
  local dir="${KVSTORE_DIR:-$HOME/.kvstore}"
  mkdir -p "$dir"
  if [[ -z "$file" ]]; then
    echo "$dir"
  else
    echo "$dir/$file"
  fi
}

_kvstore_lock_then () {
  local lockfile="$1"
  local cmd="$2"
  shift
  shift
  if [[ -z "$ns" ]]; then
    echo "error: nothing to lock" &>2
    return 1
  fi
  if type flock &>/dev/null; then
    set -e
    (
      flock -w 5 -x 200
      "$cmd" "$@"
    ) 200>"$lockfile"
    set +e
    return
  elif type shlock &>/dev/null; then
    set -e
    shlock -f "$lockfile" -p $$
    $cmd "$@"
    rm -f "$lockfile"
    set +e
    return
  fi

  echo "error: could not find 'flock' or 'shlock' in PATH.  This is needed to ensure kvstore integrity." >&2
  return 1
}

_kvstore_echo_v_if_k_match() {
  local k="$1"
  local v="$2"
  local key="$3"
  if [[ "$k" == "$key" ]]; then
    found=1
    echo "$v"
  fi
}

_kvstore_echo_kv () {
  local k="$1"
  local v="$2"
  echo -n "$k"
  echo -ne "\t"
  echo "$v"
}

_kvstore_echo_kv_if_k_nomatch() {
  local k="$1"
  local v="$2"
  local key="$3"
  if [[ "$k" != "$key" ]]; then
    _kvstore_echo_kv "$k" "$v"
  fi
}

_kvstore_each_file_kv () {
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
    $cmd "$k" "$v" "$@"
  done
}

_kvstore_nonatomic_mv () {
  local path="$1"
  local key_from="$2"
  local key_to="$3"
  local val="$4"
  local tmp="${path}.tmp"
  _kvstore_each_file_kv "$path" _kvstore_echo_kv_if_k_nomatch "$key_from" > "$tmp"
  _kvstore_echo_kv "$key_to" "$val" >> "$tmp"
  mv -f "$tmp" "$path"
}

_kvstore_nonatomic_set () {
  local path="$1"
  local key="$2"
  local val="$3"
  local tmp="${path}.tmp"
  _kvstore_each_file_kv "$path" _kvstore_echo_kv_if_k_nomatch "$key" > "$tmp"
  _kvstore_echo_kv "$key" "$val" >> "$tmp"
  mv -f "$tmp" "$path"
}

_kvstore_nonatomic_rm () {
  local path="$1"
  local key="$2"
  local tmp="${path}.tmp"
  _kvstore_each_file_kv "$path" _kvstore_echo_kv_if_k_nomatch "$key" > "$tmp"
  mv -f "$tmp" "$path"
}

kvstore_ls () {
  local dir
  dir=$(_kvstore_path)
  for file in $dir/*; do
    ! [[ "$file" =~ \.lock$ ]] && basename "$file"
  done
}

_kvstore_get_either () {
  local cutarg=$1; shift
  local ns="$1"
  [[ -z "$ns" ]] && echo "Missing param: namespace" >&2 && return 1
  local path
  path=$(_kvstore_path "$ns")
  if [[ ! -f "$path" ]]; then
    echo "Error: path not found: $path" >&2
    return 2
  fi
  cut $cutarg < "$path"
}

kvstore_keys () {
  _kvstore_get_either -f1 "$@"
}

kvstore_vals () {
  _kvstore_get_either -f2 "$@"
}

kvstore_get () {
  local ns="$1"
  [[ -z "$ns" ]] && echo "Missing param: namespace" >&2 && return 1
  local key="$2"
  [[ -z "$key" ]] && echo "Missing param: key" >&2 && return 1
  local file
  file=$(_kvstore_path "$ns")
  if [[ ! -f "$file" ]]; then
    echo "Error: namespace file not found: $ns" >&2
    return 2
  fi
  found=0
  _kvstore_each_file_kv "$file" _kvstore_echo_v_if_k_match "$key"
  if (( found == 0 )); then
    echo "Error: key not found in namespace $ns: $key" >&2
    return 1
  fi
}

kvstore_set () {
  local ns="$1"
  [[ -z "$ns" ]] && echo "Missing param: namespace" >&2 && return 1
  local key="$2"
  [[ -z "$key" ]] && echo "Missing param: key" >&2 && return 1
  local val="$3"
  [[ -z "$val" ]] && echo "Missing param: value" >&2 && return 1
  local path
  path=$(_kvstore_path "$ns")
  touch "$path"
  _kvstore_lock_then "${path}.lock" _kvstore_nonatomic_set "$path" "$key" "$val"
  return $?
}

kvstore_mv () {
  local ns="$1"
  [[ -z "$ns" ]] && echo "Missing param: namespace" >&2  && return 1
  local key_from="$2"
  [[ -z "$key_from" ]] && echo "Missing param: key_from" >&2  && return 1
  local key_to="$3"
  [[ -z "$key_to" ]] && echo "Missing param: key_to" >&2 && return 1
  local val
  val=$(kvstore_get "$ns" "$key_from")
  if ! kvstore_get "$ns" "$key_from" >/dev/null; then
    return 2
  fi
  if kvstore_get "$ns" "$key_to" &>/dev/null; then
    echo "Error: destination key already exists: $key_to" >&2
    return 3
  fi
  local path
  path=$(_kvstore_path "$ns")
  _kvstore_lock_then "${path}.lock" _kvstore_nonatomic_mv "$path" "$key_from" "$key_to" "$val"
}


kvstore_rm () {
  local ns="$1"
  [[ -z "$ns" ]] && echo "Missing param: namespace" >&2  && return 1
  local key="$2"
  [[ -z "$key" ]] && echo "Missing param: key to remove" >&2  && return 1
  if ! kvstore_get "$ns" "$key" >/dev/null; then
    return 2
  fi
  local path
  path=$(_kvstore_path "$ns")
  _kvstore_lock_then "${path}.lock" _kvstore_nonatomic_rm "$path" "$key"
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
    echo "Error: Command not specified" >&2
    echo "kvstore -h to see usage" >&2
    return 1
  fi
  ## $2 is namespace, $3 is key, $4 is value
  case "$cmd" in
    -h|--help)
      kvstore_usage "$@"
      return 0
      ;;
    -v|--version)
      echo 2.0
      return 0
      ;;
    ls)
      kvstore_ls "$2"
      return $?
      ;;
    keys)
      kvstore_keys "$2"
      return $?
      ;;
    vals)
      kvstore_vals "$2"
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
      echo "Error: Unrecognized command: $cmd" >&2
      echo "kvstore -h to see usage" >&2
      return 1
      ;;
  esac
}
kvstore "$@"
exit $?

## for emacs...
## Local Variables:
## sh-basic-offset: 2
## sh-indentation: 2
## End:
