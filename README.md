# Minecraft Manager

This is an Ansible role that manages remote Minecraft servers.  
**Note: This role does not create Minecraft servers. You are responsible for managing the files!**

## Features

- Joins template and override files
- Supports naming services
- Launches services in a screen session
- Provides interaction with services (start, stop, run a command)
- Services can be safely edited and deleted
- Setup script is provided
- **Automatic updates for most popular plugin sites**. See autoupdate section below.
- Includes a bash script wrapper for quick and easy use.

## Installation

Copy the `role/minecraft` directory to any valid Ansible role paths. The default paths are:
- `roles/` (relative to the current playbook - not recommended; does not work with the bash wrapper)
- `/usr/share/ansible/roles`
- `~/.ansible/roles`
- `/etc/ansible/roles`

Then run the `setup/setup-playbook` using `ansible-playbook setup-playbook.yml`. This playbook will prompt you for configuration entries. Make sure it runs in interactive mode and choose the hosts you want to manage with this role.

The iptables update script is optional and is provided for your convenience.

## Configuration

### Defaults

The role uses configurable values located in `roles/defaults/config.yml`. To replace these defaults, simply set the corresponding variable name before invoking the role. To modify defaults for the script, you need to edit it.

### Templates and Overrides

The use of this role relies on two main principles.

When a service is created, it is given two values by the user: the template and the name (passed as `service_name` due to "name" being reserved). The files for the current service are created using the following steps:
1. Find and copy all files from the template.
2. Check if an override for the current name exists. If not, the process stops here.
3. Copy all override files, replacing any template files with the same name.

To illustrate this, here are some examples:

Let's say we have the following service:

survival (paper)
swift
Copy code

So the name is `survival`, and the template is `paper`.

The directory structure on the control node:

```
~/
templates/
paper/
plugins/
AwakenLife.jar
server.jar
start.sh
server.properties
overrides/
survival/
plugins/
Worldguard.jar
server.properties
```

Since the override directory (`overrides/survival`) exists, files from the override will be copied to the service. As a result, the service (on the remote node) will have the following directory structure:

```
plugins/
AwakenLife.jar
Worldguard.jar
server.jar
start.sh
server.properties (Content of the file will be taken from overrides)
```

### Bash Scripts

As you may have noticed, there is a `scripts/` directory containing multiple bash scripts. These scripts need to be placed in the template or override directory to be able to use some functions of this role.

Why this approach?  
Each different service type (paper, purpur, bungeecord, velocity) has a different approach and options passed to it. This allows us to maintain compatibility with different service types and provide an easy way to modify startup options without having to modify the role.

Please open (and potentially edit) the scripts before adding them to your template/override directory. They have a SETTINGS category for easy modifications.

The `start` command requires the `start.sh` script to be present and it needs to have executable permissions. Similarly, the `backup` command requires the `backup.sh` script to be present and executable.

The `restart.sh` script is different and is not needed by the role. However, it is required for server restarts to work correctly. Set this script as your restart script, for example: `restart-script: ./restart.sh` in `spigot.yml` for Spigot-based servers.

## Usage

### Recommended Usage
Place the `services.sh` script in a directory. This script will interact with the Ansible role without requiring you to create your own playbooks. To use it, navigate to the directory where the script is located and run `./services.sh -h`.

### Advanced Usage

This is still a regular Ansible role that uses tags to separate different actions. Therefore, it can be invoked as a role using the methods specified in the [Ansible documentation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#using-roles). To view a list of possible tags, refer to `roles/minecraft/tasks/main.yml`.

## Autoupdate

This feature uses file names to update all plugins (and some servers too!) in one command. The currently supported autoupdate hosts are: `bukkit`, `github`, `hangar`, `jenkins`, `modrinth`, `papermc`, `projectkorra`, `spigotmc`. The numbers at the end are managed by the role and are used to store build numbers. If you have created an empty file and want it to be autoupdated, set the build number as 0 (as shown in examples). The next time you update, it will be replaced by the real build number.

File name format for different update sources:  
- Bukkit: `AUTOUPDATE_COMMENT_bukkit_pluginName__0.jar`
- GitHub: `AUTOUPDATE_COMMENT_github_Author:Repo_fileNameToDownloadPrefix_0.jar`
- Hangar: `AUTOUPDATE_COMMENT_hangar_Author:Name_releasePlatform_0.jar`
- Jenkins: `AUTOUPDATE_COMMENT_jenkinsUrl_fileNameToDownloadPrefix_0.jar`
- Modrinth: `AUTOUPDATE_COMMENT_modrinth_pluginName_releasePlatform_0.jar`
- PaperMC: `AUTOUPDATE_COMMENT_papermc_project_mcVersion_0.jar` (For Paper, the target mcVersion must also be set in `target.mcversion` file)
- ProjectKorra: `AUTOUPDATE_COMMENT_projectkorra_id__0.jar`
- SpigotMC: `AUTOUPDATE_COMMENT_spigotmc_id__0.jar`
