# a3upddownmod
# BASH Script for ArmA 3 MODs updating/downloading for Linux Servers 

This script is a full interactive. The complete automatic start is planing but not implemented yet.

## Script's abilities:
- Check all installed MODs for updates in a Steam Workshop
- Update one selected MOD by name
- Update all MODs, which are updated in a Steam Workshop in a batch mode.
- Download MOD by Steam AppID
- Fix missed Steam AppID in 'meta.cpp' file during updating/downloading process. 
  - REM: To make fixing possible during an Updating process it need to be manually edited once at first time before update of the selected MOD will started. All further updates will fix automatically it again and again.
- Transform the files and directories names from UPPER to LOWER case

## Dependencies
- curl
- wget
- steamcmd

## Intstallation: 
1. Clone or download this script to the **/home** directory of a user which is running an ArmA 3 server.
2. Set up the permissions to execute it for user.
3. Update paths to installed ArmA 3 Linux Server 'mods', to the Workshop directry, where steam downlading the modes and to the Steam WorkShop where the 'steamcmd.sh is located.
4. OPTIONAL: You can create an external file auht.sh in the same folder and store your Steam credentials there. The password should be encrypted with a base64 encryption.

To create your own auth.sh file make the followed (Enter your own Steam credentials before executing!):

```
echo '#!/bin/bash' > auth.sh && echo "" >> auth.sh
echo "STEAM_LOGIN=\"YOUR_STEAM_LOGIN\"" >> auth.sh
echo "STEAM_PASS=\"$(echo "YOUR_STEAM_PASSWORD" | base64)\"" >> auth.sh
```

## Usage: 
Run the script and follow an instructions.
## Known issues:
- After the batch updating of a MODs - the Steam AplicationID is brokes again in a some MODs. These MOD's 'meta.cpp' file need to be updated manually again.
- _**NOT A BUG**_: Some MODs has no an application ID in its **meta.cpp** file (it's = 0). These MODs can't be updated by this script before editing the **meta.cpp** file. To make it work - just copy the MOD's Steam AppID from the MOD's WorkShop link and replace the "0" here
```
publishedid = 0;
```
with your AppID to make it looks like a
```
publishedid = 123456789;
```
For example
```
protocol = 1;
publishedid = 0;
name = "@ACE Compat_RHS_USAF";
timestamp = 5248321387302862629;
```
will take a look like
```
protocol = 1;
publishedid =773125288;
name = "@ACE Compat_RHS_USAF";
timestamp = 5248321387302862629;
```
UPD: This could be fixed by re-downloading the MOD with 'publishedid =0;' in **meta.cpp** by current script. It will replace the '0' by pasted Steam Workshop AppID.

## Plans
1. Run script with a CLI options to make all jobs automatically
