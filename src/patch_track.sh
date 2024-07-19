# This file handles all the interactions with git send-email. Currently it
# provides functions to configure the options used by git send-email.
# It's also able to verify if the configurations required to use git send-email
# are set.

include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"


function patch_track_main()
{
    local flag

    flag=${flag:-'SILENT'}

    if [[ -z "$*" ]]; then
        complain 'Please, provide an argument'
        patch_track "$@"
        exit 22 # EINVAL
    fi

    parse_patch_track "$@"
    if [[ "$?" -gt 0 ]]; then
        complain "${options_values['ERROR']}"
        patch_track "$@"
        exit 22 # EINVAL
    fi

    if [[ -n "${options_values['DASHBOARD']}" ]]; then
        show_patches_dashboard "${options_values['FROM']}" "${options_values['BEFORE']}" "${options_values['AFTER']}" "$flag"
        return 0
    fi

    if [[ -n "${options_values['SET_STATUS']}" ]]; then
        if [[ -z "${options_values['PATCH_ID']}" ]] ; then
            complain 'Patch id not specified with `--id <num>`'
            return 22 #EINVAL
        fi

        set_patch_status "${options_values['PATCH_ID']}" "${options_values['SET_STATUS']}" "$flag"
        return 0
    fi

}

function register_patch_track()
{

}

function register_patch_log()
{

}

function show_patches_dashboard()
{
    local from="$1"
    local before="$2"
    local after="$3"


    if [[ -n "$from" ]]; then
    else if [[ -n "$before" ]]; then
    else if [[ -n "$from" ]]; then
    fi
}

function set_patch_status()
{
    local patch_id="$1"
    local patch_new_status="$2"
    local patch_infos

    condition_array=(['id']="${patch_id}")
    patch_infos="$(select_from_where "$DATABASE_PATCH_TABLE" '' 'condition_array')"

    set_array=(['status']="${patch_id}")
    return "$(update_into "$DATABASE_PATCH_TITLE" 'condition_array' 'set_array')"
}

function parse_patch_track()
{
  local long_options='id:,show,set-status:,from:,before:,after:,'
  local short_options='-s,-f:,-b:,-a:,-p:'
  local options

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    # TODO kw_parse_get_errors
    options_values['ERROR']="$(kw_parse_get_errors 'kw patch_track' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  eval "set -- ${options}"

  # Default values
  options_values['SHOW']=''
  options_values['PATCH_ID']=''
  options_values['SET_STATUS']=
  options_values['FROM']=''
  options_values['BEFORE']=''
  options_values['AFTER']=''

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dashboard | -d)
        options_values['SHOW']=1
        shift 2
        ;;
      --id)
        options_values['PATCH_ID']="$2"
        shift 2
        ;;
      --set-status | -s)
        options_values['SET_STATUS']="$2"
        shift 2
        ;;
      --from | -f)
        options_values['FROM']="$2"
        shift 2
        ;;
      --before | -b)
        options_values['BEFORE']="$2"
        shift 2
        ;;
      --after | -a)
        options_values['AFTER']="$2"
        shift 2
        ;;
      --help | -h)
      # TODO: patch_track_help
        patch_track_help "$1"
        exit
        ;;
      *)
        shift
        ;;
    esac
  done
}

function patch_track_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'patch-track'
    return
  fi
  printf '%s\n' 'kw patch-track:' \
    '  patch-track (-d|--dashboard) [[--before <from>] | [--after <date>] [--before <date>]] - Show patches dashboard in chronological order ' \
    '  patch-track (--id) [-s| --set-status] - Show infos from patch with given id ' \
    '  patch-track (-d|--dashboard) - Show patches dashboard in chronological order ' \
    '  patch-track (-d|--dashboard) - Show patches dashboard in chronological order ' \

}