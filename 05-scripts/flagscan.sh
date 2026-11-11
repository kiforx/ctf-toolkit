#!/usr/bin/env bash
#
# flagscan.sh - search a directory tree for obfuscated CTF flags.
#
# A flag looks like:   be_s_t_CTF-_{h1dd3n_r0b0ts_txt}:1
# The letters of "best" and "CTF" may be separated by any number of '-', '_'
# or '.' characters, the payload is wrapped in braces and ":N" is the flag
# number.
#
# Requires GNU grep.

set -o nounset
set -o pipefail

readonly PROGRAM=${0##*/}
readonly VERSION='1.0'

readonly EXIT_OK=0
readonly EXIT_NOT_FOUND=1
readonly EXIT_ERROR=2

# Access key. Replace the placeholder with the real key before use.
readonly EXPECTED_KEY='i will write key here'

# b-e_s.t_C-T.F_{payload}:N with arbitrary '-', '_' or '.' noise between letters.
readonly NOISE='[-_.]*'
readonly FLAG_REGEX="b${NOISE}e${NOISE}s${NOISE}t${NOISE}C${NOISE}T${NOISE}F${NOISE}\\{[[:alnum:]_]+\\}:[A-Za-z0-9]+"

# Parsed command line.
opt_key=''
opt_include=''
opt_exclude=''
opt_output=''
key_set=0
include_set=0
exclude_set=0
output_set=0
opt_help=0
opt_version=0
declare -a positionals=()
declare -a parse_errors=()

# Runtime state.
declare -A include_numbers=()
declare -A exclude_numbers=()
declare -a results=()
raw_matches=''
had_errors=0

warn() {
  printf '%s: %s\n' "${PROGRAM}" "$*" >&2
}

die() {
  warn "$@"
  exit "${EXIT_ERROR}"
}

usage_error() {
  local message
  for message in "$@"; do
    warn "${message}"
  done
  printf "Try '%s --help' for more information.\n" "${PROGRAM}" >&2
  exit "${EXIT_ERROR}"
}

usage() {
  cat <<EOF
Usage: ${PROGRAM} --key=KEY [OPTION]... DIRECTORY
Recursively search DIRECTORY for obfuscated flags such as
  be_s_t_CTF-_{h1dd3n_r0b0ts_txt}:1
and print every distinct flag found.

      --key=KEY        access key (required); if it is missing or wrong the
                       program prints "Error, not found" and exits with 1,
                       whatever other options were given
      --include=LIST   only output flags whose number is in LIST
      --exclude=LIST   do not output flags whose number is in LIST
      --output=FILE    write the flags to FILE (mode 0600) instead of stdout
  -h, --help           display this help and exit
  -V, --version        output version information and exit

LIST is a comma-separated list of numbers, for example 1,2,3.
If a number is in both lists, --exclude wins.

Exit status:
  0  at least one flag was output
  1  no flag found, or the key is wrong
  2  usage error or I/O error
EOF
}

print_info_if_requested() {
  if ((opt_help)); then
    usage
    exit "${EXIT_OK}"
  fi
  if ((opt_version)); then
    printf '%s %s\n' "${PROGRAM}" "${VERSION}"
    exit "${EXIT_OK}"
  fi
}

set_option() {
  case $1 in
    key)     opt_key=$2;     key_set=1 ;;
    include) opt_include=$2; include_set=1 ;;
    exclude) opt_exclude=$2; exclude_set=1 ;;
    output)  opt_output=$2;  output_set=1 ;;
  esac
}

# Parsing never exits on a bad option: mistakes are collected and reported
# only after the key has been checked, so a wrong key always wins.
parse_args() {
  local arg name

  while (($# > 0)); do
    arg=$1
    shift
    case ${arg} in
      --)
        positionals+=("$@")
        break
        ;;
      -h | --help)
        opt_help=1
        ;;
      -V | --version)
        opt_version=1
        ;;
      --key | --include | --exclude | --output)
        if (($# == 0)); then
          parse_errors+=("option '${arg}' requires an argument")
        else
          set_option "${arg#--}" "$1"
          shift
        fi
        ;;
      --key=* | --include=* | --exclude=* | --output=*)
        name=${arg%%=*}
        set_option "${name#--}" "${arg#*=}"
        ;;
      -*)
        parse_errors+=("unrecognized option '${arg}'")
        ;;
      *)
        positionals+=("${arg}")
        ;;
    esac
  done
}

validate_key() {
  if ((!key_set)) || [[ ${opt_key} != "${EXPECTED_KEY}" ]]; then
    printf 'Error, not found\n'
    exit "${EXIT_NOT_FOUND}"
  fi
}

validate_directory() {
  local dir=$1

  [[ -e ${dir} ]] || die "cannot access '${dir}': No such file or directory"
  [[ -d ${dir} ]] || die "'${dir}': Not a directory"
  [[ -r ${dir} && -x ${dir} ]] || die "cannot access '${dir}': Permission denied"
}

# Strip leading zeros so that "007" and "7" compare equal.
normalize_number() {
  local number=$1

  while [[ ${number} == 0?* ]]; do
    number=${number#0}
  done
  printf '%s' "${number}"
}

# parse_number_list ARRAY_NAME OPTION_NAME LIST
parse_number_list() {
  local -n target=$1
  local option=$2
  local list=${3//[[:space:]]/}
  local -a items=()
  local item

  if [[ ! ${list} =~ ^[0-9]+(,[0-9]+)*$ ]]; then
    die "invalid argument '$3' for '${option}' (expected e.g. 1,2,3)"
  fi

  IFS=',' read -r -a items <<<"${list}"
  for item in "${items[@]}"; do
    target["$(normalize_number "${item}")"]=1
  done
}

prepare_output() {
  local file=$1

  [[ -n ${file} ]] || die "option '--output' requires a non-empty path"
  [[ ! -d ${file} ]] || die "'${file}': Is a directory"
  [[ ! -L ${file} ]] || die "'${file}': refusing to write through a symlink"

  # Create (or truncate) with a restrictive umask, then enforce the mode in
  # case the file already existed with wider permissions.
  (umask 077 && : >"${file}") 2>/dev/null || die "cannot create '${file}'"
  chmod 0600 -- "${file}" || die "cannot set permissions on '${file}'"
}

scan_directory() {
  local dir=$1
  local status=0

  # LC_ALL=C: byte-wise matching, so binary files cannot upset the regex.
  raw_matches=$(
    LC_ALL=C grep --recursive --text --devices=skip --only-matching \
      --no-filename --extended-regexp --regexp="${FLAG_REGEX}" -- "${dir}"
  ) || status=$?

  # grep: 0 = matches, 1 = no matches, 2 or more = trouble (already on stderr).
  if ((status > 1)); then
    had_errors=1
    warn 'some files could not be read'
  fi
}

# Deduplicate the raw matches and apply --include / --exclude.
collect_flags() {
  local raw=$1
  local flag number
  local -A seen=()

  while IFS= read -r flag; do
    [[ -n ${flag} ]] || continue
    [[ -z ${seen[${flag}]+set} ]] || continue
    seen[${flag}]=1

    number=$(normalize_number "${flag##*:}")
    if ((${#include_numbers[@]} > 0)) && [[ -z ${include_numbers[${number}]+set} ]]; then
      continue
    fi
    if [[ -n ${exclude_numbers[${number}]+set} ]]; then
      continue
    fi
    results+=("${flag}")
  done <<<"${raw}"
}

emit_flags() {
  if ((${#results[@]} == 0)); then
    warn 'no matching flags found'
    return 1
  fi

  if ((output_set)); then
    printf '%s\n' "${results[@]}" >"${opt_output}" \
      || die "cannot write to '${opt_output}'"
  else
    printf '%s\n' "${results[@]}"
  fi
}

main() {
  local directory status=${EXIT_OK}

  parse_args "$@"

  # --help and --version leak nothing, so they work without a key;
  # once a key is supplied, a wrong one always wins.
  if ((!key_set)); then
    print_info_if_requested
  fi
  validate_key
  print_info_if_requested

  if ((${#parse_errors[@]} > 0)); then
    usage_error "${parse_errors[@]}"
  fi
  case ${#positionals[@]} in
    0) usage_error 'missing directory operand' ;;
    1) ;;
    *) usage_error "extra operand '${positionals[1]}'" ;;
  esac

  directory=${positionals[0]}
  validate_directory "${directory}"

  if ((include_set)); then
    parse_number_list include_numbers --include "${opt_include}"
  fi
  if ((exclude_set)); then
    parse_number_list exclude_numbers --exclude "${opt_exclude}"
  fi
  if ((output_set)); then
    prepare_output "${opt_output}"
  fi

  scan_directory "${directory}"
  collect_flags "${raw_matches}"
  emit_flags || status=${EXIT_NOT_FOUND}

  if ((had_errors)); then
    status=${EXIT_ERROR}
  fi
  exit "${status}"
}

main "$@"
