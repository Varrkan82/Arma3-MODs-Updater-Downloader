# a3upddownmod
# BASH Script for Arma 3 MODs updating/downloading for Linux Servers 

This script is a full interactive. The complete automatic start is planing but not implemented yet.

## Script's abilities:
- Check an all installed MODs for updates in a Steam Workshop
- Update one selected MOD by its name
- Update all MODs, which are updated in a Steam Workshop in a batch mode.
- Download MOD by Steam AppID
- Fix missed Steam AppID in 'meta.cpp' file during updating/downloading process. 
  - REM: To make fixing possible during an Updating process it need to be a manually edited once at a first time before update of the selected MOD will started. All further updates will fix automatically it again and again.
- Transform the files and directories names from UPPER to LOWER case

## Dependencies
- curl
- wget
- steamcmd
- rename

## Intstallation: 
1. Clone or download this script to the **/home** directory of a user which is running an Arma 3 server.
2. Set up the permissions to execute it for user.
3. Update paths to installed Arma 3 Linux Server **mods**, to the Workshop directry, where Steam downlading the modes and where the `steamcmd.sh` is located.
4. OPTIONAL: You can create an external file `auht.sh` in a folder a step above of a `a3upddownmod.sh` is located and to store your Steam credentials there. The password should be encrypted with a base64 encryption.

To create your own auth.sh file make the followed (Enter your own Steam credentials before executing!):

```
echo '#!/bin/bash' > auth.sh && echo "" >> auth.sh
echo "STEAM_LOGIN=\"YOUR_STEAM_LOGIN\"" >> auth.sh
echo "STEAM_PASS=\"$(echo "YOUR_STEAM_PASSWORD" | base64)\"" >> auth.sh
```

## Usage: 

###CLI
Run `./a3upddownmods.sh -h` for CLI usage overview (Check/Update available only for now).

If you want to use this script to check or to update the mods automatically and want you to be notified about it - do the next:

```
cp notify_update_status.sh.example notify_update_status.sh && nano notify_update_status.sh
```

Update `url=` variable to your Discord WEB-hook URL.

Add the script with needed parameters to you CRON (or to systemd timer job). For example `0 3 * * * /home/steam/a3upddownmods/a3upddownmods.sh -cn` to check for updates automatically.

I recommend to automatically check for updates ONLY and to do not use an automatic update as in this case you'll need to update mod's keys in server `keys` folder and to restart server manually anyway.

###Interactive
Run the script and follow an instructions for interactive usage.

## Plans
1. Run script with a CLI options to make all jobs automatically (partially done)
