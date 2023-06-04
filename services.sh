#!/bin/bash

help () {
    cat <<-EOF
	Usage: $0 <host> <command> [command arguments...]
	
	Host: A hostname or an IP address as defined in your ansible inventory
	Command:
	  help                                           Print this message
	  update [-p]                                    Update latest AUTOUPDATE_*.jar files and apt-get (on remote). To push after update, use -p
	  create <template> <name>                       Create a new service with the given template and name
	  push                                           Push all updated files to the remote
	  start <name>                                   Start a service with the given name
	  stop                                           Stop the current service (if any is running)
	  execute <command...>                           Execute a command on the service (will be passed to console)
	  list                                           List all services on the remote
	  edit <name> [-t template_name] [-n new_name]   Edit the given service, passing no arguments does nothing. Change template with -t and name with -n
	  delete <name> [-y]                             Delete the given service, passing -y will NOT prompt for confirmation
	  backup <action> [backup_name]                  Manages the backups for the current running service. Actions are: create, list, delete, restore. Give backup_name for delete and restore
	  
	  All flags must be passed AFTER all other arguments
	EOF
    exit 0
}

case "$1" in
    help|-h|--help)
        help
        ;;
esac
if [ "$#" -lt 2 ]; then
    printf "Usage: %s <host> <command> [command arguments...]\n" "$0" >&2
    exit 1
fi

readonly role="minecraft"
readonly host="$1"
shift
if [ -z "$host" ]; then
    printf "Host can't be empty\n" >&2
    exit 1
fi

run () {
    ansible-playbook "$@" /dev/stdin <<-EOF || exit 2
	---
	- name: SERVICE MANAGER
	  hosts: $host
	  gather_facts: false
	  roles:
	    - $role
	EOF
}

checkNoArguments () {
    shift
    if [ "$#" -gt 0 ]; then
        printf "Received unexpected argument: %s\n" "$1" >&2
        exit 1
    fi
}

checkOneArgument () {
    shift
    if [ "$#" -lt 1 ]; then
        printf "Not enough arguments\n" >&2
        exit 1
    fi
    if [ "$#" -gt 1 ]; then
        printf "Received unexpected argument: %s\n" "$2" >&2
        exit 1
    fi
}

confirm () {
    read -rp "$1? [y/N] " input
    input="$(printf "%s" "$input" | tr '[:upper:]' '[:lower:]')"
    if ! { [ "$input" = "y" ] || [ "$input" = "yes" ] || [ "$input" = "ye" ] || [ "$input" = "yeah" ] || [ "$input" = "yup" ] || [ "$input" = "yea" ] || [ "$input" = "yep" ]; }; then
        printf "Abort\n"
        exit 255
    fi
}


update () {
    shift
    if [ "$#" -gt 1 ]; then
        printf "Unknown argument: %s\n" "$2" >&2
        exit 1
    fi
    push=false
    if [ "$#" -eq 1 ]; then
        if [ "$1" != "-p" ]; then
            printf "Unknown argument: %s\n" "$1" >&2
            exit 1
        fi
        push=true
    fi

    run -t "update"
    if [ "$push" = true ]; then
        run -t "push"
    fi
}

create () {
    shift
    if [ "$#" -lt 2 ]; then
        printf "Not enough arguments\n" >&2
        exit 1
    fi
    if [ "$#" -gt 2 ]; then
        printf "Received unexpected argument: %s\n" "$3" >&2
        exit 1
    fi
    run -t "create" -e "template='$1' service_name='$2'"
}

edit () {
    # edit <service_name> [-t template_name] [-n new_name]
    shift
    if [ "$#" -lt 1 ] || [ "${1::1}" =  "-" ]; then
        printf "Not enough arguments\n" >&2
        exit 1
    fi
    vars="service_name=$1"
    shift
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -t)
                shift
                template="$1"
                shift
                ;;
            -n)
                shift
                name="$1"
                shift
                ;;
            *)
                printf "Unknown argument: %s\n" "$1" >&2
                exit 1
                ;;
        esac
    done
    
    if [ -n "$template" ]; then
        vars="$vars new_template='$template'"
    fi
    if [ -n "$name" ]; then
        vars="$vars new_name='$name'"
    fi
    
    run -t "edit" -e "$vars"
    run -t "push"
}

delete () {
    shift
    if [ "$#" -gt 2 ]; then
        printf "Unknown argument: %s\n" "$3" >&2
        exit 1
    fi
    if [ "$#" -lt 1 ]; then
        printf "Not enough arguments\n" >&2
        exit 1
    fi
    
    if [ "$#" -eq 2 ]; then
        if [ "$2" != "-y" ]; then
            printf "Unknown argument: %s\n" "$2" >&2
            exit 1
        fi
    else
        confirm "Are you sure you want to delete $1"
    fi
    
    run -t "delete" -e "service_name='$1'"
}

backup () {
    shift
    if [ "$#" -lt 1 ]; then
        printf "Not enough arguments\n" >&2
        exit 1
    fi
    if ! { [ "$1" = "create" ] || [ "$1" = "list" ] || [ "$1" = "delete" ] || [ "$1" = "restore" ]; }; then
        printf "Unknown argument: %s\n" "$1" >&2
        exit 1
    fi
    if { [ "$1" = "delete" ] || [ "$1" = "restore" ]; } && [ "$#" -lt 2 ]; then
        printf "Not enough arguments\n" >&2
        exit 1
    fi
    if ! { [ "$1" = "delete" ] || [ "$1" == "restore" ]; } && [ "$#" -gt 1 ]; then
        printf "Unknown argument: %s\n" "$2" >&2
        exit 1
    fi
    if [ "$#" -gt 2 ]; then
        printf "Unknown argument: %s\n" "$3" >&2
        exit 1
    fi
    
    if [ "$1" = "create" ]; then
        run -t "backup-create"
    elif [ "$1" = "list" ]; then
        run -t "backup-list"
    elif [ "$1" = "delete" ]; then
        run -t "backup-delete" -e "backup_name='$2'"
    elif [ "$1" = "restore" ]; then
        confirm  "Warning: This will overwrite the current world files. Are you sure you want to continue"
        run -t "backup-restore" -e "backup_name='$2'"
    fi
}


case "$1" in
    help|-h|--help)
        help
        ;;
    update)
        update "$@"
        ;;
    create)
        create "$@"
        ;;
    push)
        checkNoArguments "$@"
        run -t "push"
        ;;
    start)
        checkOneArgument "$@"
        shift
        run -t "start" -e "service_name='$1'"
        ;;
    stop)
        checkNoArguments "$@"
        run -t "stop"
        ;;
    execute)
        shift
        if [ "$#" -lt 1 ]; then
            printf "Not enough arguments\n" >&2
            exit 1
        fi
        run -t "execute" -e "cmd='$*'"
        ;;
    list)
        checkNoArguments "$@"
        run -t "list"
    ;;
    edit)
        edit "$@"
        ;;
    delete)
        delete "$@"
        ;;
    backup)
        backup "$@"
        ;;
    *)
        printf "Unknown command: %s\n" "$1" >&2
        exit 1
        ;;
esac
