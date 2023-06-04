#!/bin/bash

############################# SETTINGS #############################

# List of directories to backup. Should be same as "level-name" in server.properties
# HOWEVER if you are using a bukkit (based) server, you will need to add the "_nether" and the "_the_end" suffix
# The defualt as same as mc default: world
readonly world_dir=(
    "world"
    "world_nether"
    "world_the_end"
)

# Directory to save backup files
# Will be created if it does not exist
# Can be an absolute or relative path
readonly backup_dir="backup"

# Screen name under which the server is running
# Will be used to disable (and then enable) autosave to prevent corruption
readonly screen_name="$2" # Passed as second argument (ansible knows how to handle that, will use the same name as passed to the ansible role)

# Maximum number of backups to keep
# Starts deleting the oldest backup when limit is reached
# Set to 0 to disable (WARNING! This may take large amount of disk space, especially if backups are made often)
readonly max_backups=28 # Wonder why 28? I decided to have automatic backups every 6 hours and keep backups up to a week

# Backup file name
# %time% will be replace with the current backup time and date (format defined below)
readonly backup_name="backup_%time%"

# Date format
# Should be a valid argument to pass to the "date" command
# See man(1) date for more information or visit https://manpages.ubuntu.com/manpages/xenial/man1/date.1.html
readonly date_format="%F_%T"

############################# END OF SETTINGS #############################


if [ -z "$1" ]; then
    printf "Usage: %s <create|list|delete>\n" "$0" >&2
    exit 1
fi

# Check that world_dir exists
for var in "${world_dir[@]}"; do
    if [ ! -d "$var" ]; then
        printf "World directory (%s) does not exist or is not a directory\n" "$var" >&2
        exit 2
    fi
done
mkdir -p "$backup_dir"

create () {
    if [ -z "$screen_name" ]; then
        printf "Screen name is required\n" >&2
        exit 1
    fi
    
    date=$(date "+$date_format")
    backup_name_replaced=${backup_name//%time%/$date}
    backup_path="$backup_dir/$backup_name_replaced.zip"

    screen -p 0 -S "$screen_name" -X stuff "\\015save-off\\015" || exit 4 # Disable autosave
    printf "Waiting for mc to disable autosave\n"
    sleep 5
    printf "Autosave disabled\n"
    
    printf "Backing up\n"
    zip -rq9 "$backup_path" "${world_dir[@]}" || exit 3

    screen -p 0 -S "$screen_name" -X stuff "\\015save-on\\015" || exit 4 # Enable autosave
    printf "Autosave enabled\n"

    # Check if backups need to be deleted
    current_backups=$(ls -1 "$backup_dir")
    i=0
    for var in $current_backups; do
        file_info=${var: -23}
        if [[ ! "$file_info" =~ ^([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.zip)$ ]]; then
            printf "User modified backup name: %s. Not counting to max limit\n" "$var" >&2
            continue
        fi
        
        file_date="${file_info%".zip"}"
        backup_dates[i]="$(date --date="${file_date/_/" "}" "+%s")"
        i="$((i + 1))"
    done

    if [ "$max_backups" -gt 0 ] && [ "${#backup_dates[@]}" -gt "$max_backups" ]; then
        max="${backup_dates[0]}"
        id=0
        i=0
        for var in "${backup_dates[@]}"; do
            if [ "$var" -lt "$max" ]; then
                max="$var"
                id="$i"
            fi
            i="$((i + 1))"
        done

        printf "Deleting oldest backup\n"
        readarray -t backups_array <<<"$current_backups"
        oldest="${backups_array[$id]}"
        rm -rf -- "$backup_dir/${oldest:?}"
    fi
}


list () {
    ls -1 "$backup_dir"
}

delete () {
    if [ -z "$delete_backup" ]; then
        printf "Usage: %s delete <backup-name>\n" "$0" >&2
        exit 1
    fi
    if [ "$delete_backup" = "*" ]; then
        rm -rf -- "${backup_dir:?}/"*
        return 0
    fi
    
    rm -r -- "$backup_dir/${delete_backup:?}"
}

restore () {
    if [ -z "$restore_backup" ]; then
        printf "Usage: %s restore <backup-name>\n" "$0" >&2
        exit 1
    fi
    if [ ! -f "$backup_dir/$restore_backup" ]; then
        printf "Backup file (%s) does not exist\n" "$restore_backup" >&2
        exit 1
    fi
    
    unzip -qqo "$backup_dir/$restore_backup" || exit 2
}

case $1 in
    create)
        create
        ;;
    list)
        list
        ;;
    delete)
        readonly delete_backup="$2"
        delete
        ;;
    restore)
        readonly restore_backup="$2"
        restore
        ;;
    *)
        printf "Invalid argument: %s\n" "$1" >&2
        exit 1
        ;;
esac
