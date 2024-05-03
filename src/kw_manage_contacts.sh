# This file handles the interactions with the email groups and contacts. Currently it

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/send_patch.sh"

# Hash containing user options
declare -gA options_values

# Mail group database tables
declare -g DATABASE_TABLE_GROUP='email_group'
declare -g DATABASE_TABLE_CONTACT='email_contact'
declare -g DATABASE_TABLE_CONTACT_GROUP='email_contact_group'

declare -Ag condition_array
declare -Ag updates_array

#shellcheck disable=SC2119
function manage_contacts_main()
{
  local flag
  local ret

  flag=${flag:-'SILENT'}

  if [[ "$1" =~ -h|--help ]]; then
    manage_contacts_help "$1"
    exit 0
  fi

  parse_manage_contacts_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    manage_contacts_help
    return 22 # EINVAL
  fi

  if [[ "${options_values['GROUP_CREATE']}" ]]; then
    create_email_group "${option_values['GROUP']}"

    if [[ "$?" -eq 0 ]]; then
      success "New group ${group_name} created successfully!"
    fi
  fi

  if [[ "${options_values['GROUP_REMOVE']}" ]]; then
    remove_email_group "${option_values['GROUP']}"
    
    if [[ "$?" -eq 0 ]]; then
      success "Group ${group_name} removed successfully!"
    fi
  fi

   if [[ -n "${options_values['GROUPS_RENAME']}" ]]; then
    rename_email_group "${options_values['GROUP']}" "${options_values['GROUPS_RENAME']}"

    if [[ "$?" -eq 0 ]]; then
      success "Group ${options_values['GROUP']} successfully renamed to ${options_values['GROUPS_RENAME']}"
    fi
  fi

  return 0
}

# This function receives the name of a new group and then check for
# incidences in the database and validate the group name before creating
# the group.
#
# @group_name: The name of the group that will be created.
#
# Returns:
# returns 0 if successful, non-zero otherwise
function create_email_group()
{
  local group_name="$1"
  local values

  validate_group_name "$group_name"
  
  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi
  
  check_existent_group "$group_name"
  
  if [[ "$?" -ne 0 ]]; then
    warning 'This group already exists'
    return 22 # EINVAL
  fi

  create_group "$group_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  return 0
}

# This function creates a new kw mail group
#
# @group_name: The name of the group that will be created.
#
# Returns:
# returns 0 if successful, non-zero otherwise
function create_group()
{
  local group_name="$1"
  local sql_operation_result

  values="$(format_values_db 1 "$group_name")"

  sql_operation_result=$(insert_into "$DATABASE_TABLE_GROUP" '(name)' "$values" '' 'VERBOSE')
  ret="$?"

  if [[ "$ret" -eq 2 || "$ret" -eq 61 ]]; then
    complain "$sql_operation_result"
    return 22 # EINVAL
  elif [[ "$ret" -ne 0 ]]; then
    complain "($LINENO):" $'Error while inserting group into the database with command:\n' "${sql_operation_result}"
    return 22 # EINVAL
  fi

  return 0
}

# This function validate a given group name
#
# @group_name: the group name that will be checked
#
# Return:
# returns 0 if successful, 61 if group name is empty,
# 75 if size of the group name is over 50 characters 
# and 22 if group name has invalid characters as: 
# [!, @, #, $, %, ^, &, (, ), (' ), (" ) and +].
function validate_group_name()
{
  local group_name="$1"
  local name_length
  local has_special_character
  local ret

  if [[ -z "$group_name" ]]; then
    complain 'The group name is empty'
    return 61 # ENODATA
  fi

  name_length="$(str_length "$group_name")"

  if [[ "$name_length" -ge 50 ]]; then
    complain 'The group name must be less than 50 characters'
    return 75 # OVERFLOW
  fi

  str_has_special_characters "$group_name"

  if [[ "$?" -eq 0 ]]; then
    complain 'The group name must not contain special characters'
    return 22 #EINVAL
  fi

  return 0
}

# This function checks the existence of a given group
#
# @group_name: the group name that will be checked
#
# Return:
# returns group id if group exists, 0 if it doesn't
function check_existent_group()
{
  local group_name="$1"
  local group_id

  condition_array=(['name']="${group_name}")
  group_id="$(select_from "$DATABASE_TABLE_GROUP" 'id' '' 'condition_array')"

  if [[ -n "$group_id" ]]; then
    return "$group_id"
  fi

  return 0
}

# This function removes a given mail group and
# all of it's references in the data base. Also
# removes the contacts without group association
#
# @group_name: The name of the removed group
#
# Returns:
# returns 0 if successful, non-zero otherwise
function remove_email_group()
{
  local group_name="$1"

  check_existent_group "$group_name"

  if [[ "$?" -eq 0 ]]; then
    warning 'Error, this group does not exist'
    return 22 #EINVAL
  fi

  remove_group "$group_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 #EINVAL
  fi

  return 0
}

# This function removes a given group from the database
#
# @group_name: Name of the group which the contacts will be removed
#
# Return:
# returns 0 if successful, non-zero otherwise
function remove_group()
{
  local group_name="$1"
  local sql_operation_result

  condition_array=(['name']="${group_name}")
  
  sql_operation_result=$(remove_from "$DATABASE_TABLE_GROUP" 'condition_array' '' '' 'VERBOSE')
  ret="$?"

  if [[ "$ret" -eq 2 || "$ret" -eq 61 ]]; then
    complain "$sql_operation_result"
    return 22 # EINVAL
  elif [[ "$ret" -ne 0 ]]; then
    complain $'Error while removing group from the database with command:\n'"${sql_operation_result}"
    return 22 # EINVAL
  fi

  return 0
}

# This function renames a given mail group after checking
# the parameters passed.
#
# @old_name: The actual name of the renamed group
# @new_name: The new name wich the group will be renamed
#
# Returns:
# returns 0 if successful, non-zero otherwise
function rename_email_group()
{
  local old_name="$1"
  local new_name="$2"
  local group_id

  if [[ -z "$old_name" ]]; then
    complain 'Error, group name is empty'
    return 61 # ENODATA
  fi

  check_existent_group "$old_name"

  if [[ "$?" -eq 0 ]]; then
    warning 'This group does not exist so it can not be renamed'
    return 22 # EINVAL
  fi

  validate_group_name "$new_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  rename_group "$old_name" "$new_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  return 0
}

# This function renames a given group from the database
#
# @old_name: Name of the group that will be renamed
# @new_name: New namw of the group
#
# Return:
# returns 0 if successful, non-zero otherwise
function rename_group()
{
  local old_name="$1"
  local new_name="$2"
  local sql_operation_result
  local ret

  condition_array=(['name']="${old_name}")
  updates_array=(['name']="${new_name}")
  
  sql_operation_result=$(update_into "$DATABASE_TABLE_GROUP" 'updates_array' '' 'condition_array' 'VERBOSE')
  ret="$?"

  if [[ "$ret" -eq 2 || "$ret" -eq 61 ]]; then
    complain "$sql_operation_result"
    return 22 # EINVAL
  elif [[ "$ret" -ne 0 ]]; then
    complain "($LINENO):" $'Error while removing group from the database with command:\n'"${sql_operation_result}"
    return 22 # EINVAL
  fi
  
  return 0
}

function parse_manage_contacts_options()
{
  local index
  local option
  local setup_token=0
  local patch_version=''
  local commit_count=''
  local short_options='c:,r:,'
  local long_options='group-create:,group-remove:,group-rename:,'
  local pass_option_to_send_email

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw manage-contacts' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  eval "set -- $options"

  options_values['GROUPS']=''
  options_values['GROUP']=''
  options_values['GROUP_CREATE']=''
  options_values['GROUP_REMOVE']=''
  options_values['GROUP_RENAME']=''

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --group-create | -c)
        options_values['GROUP_CREATE']=1
        options_values['GROUP']="$2"
        shift 2
        ;;
      --group-remove | -r)
        options_values['GROUP_REMOVE']="$2"
        shift 2
        ;;
      --group-rename)
        options_values['GROUP_RENAME']="$2"
        shift 2
        ;;
      --)
        shift
        ;;
    esac
  done

  return 0
}

function manage_contacts_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'manage-contacts'
    exit
  fi
  printf '%s\n' 'kw manage-contacts:' \
    '  manage-contacts (-c | --group-create) [<name>] - create new group' \
    '  manage-contacts (-r | --group-remove) [<name>] - remove existing group' \
    '  manage-contacts --group-rename [<old_name>:<new_name>] - rename existent group'
}