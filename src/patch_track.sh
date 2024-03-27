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
        show_patches_dashboard "$flag"
        return 0
    fi

    if [[ -n "${options_values['SET_STATUS']}" ]]; then
        if [[ -z "${options_values['PATCH_ID']}" ]] ; then
            complain 'Patch id not specified with `--patch-id num`'
            return 22 #EINVAL
        fi

        set_patch_status "${options_values['PATCH_ID']}" "${options_values['SET_STATUS']}" "$flag"
        return 0
    fi

    if [[ -n "${options_values['FROM']}" ]]; then
        show_patches_dashboard "${options_values['FROM']}"
    fi

    if [[ -n "${options_values['BEFORE']}" ]]; then
        show_patches_dashboard "${options_values['BEFORE']}"
    fi

    if [[ -n "${options_values['AFTER']}" ]]; then
        show_patches_dashboard "${options_values['AFTER']}"
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
  local long_options='patch-id:,show,set-status:,from:,before:,after:,'
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
      --patch_id)
        options_values['PATCH_ID']="$2"
        shift 2
        ;;
      --set-status)
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
    kworkflow_man 'pomodoro'
    return
  fi
  printf '%s\n' 'kw pomodoro:' \
    '  pomodoro (-t|--set-timer) <time>(h|m|s) - Set pomodoro timer' \
    '  pomodoro (-c|--check-timer) - Show elapsed time' \
    '  pomodoro (-s|--show-tags) - Show registered tags' \
    '  pomodoro (-t|--set-timer) <time>(h|m|s) (-g|--tag) <tag> - Set timer with tag' \
    '  pomodoro (-t|--set-timer) <time>(h|m|s) (-g|--tag) <tag> (-d|--description) <desc> - Set timer with tag and description' \
    '  pomodoro (--verbose) - Show a detailed output'
}