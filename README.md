# a3upddownmod
# BASH Script for ArmA 3 MODs updating/downloading for Linux Servers 

This script is a full interactive. The complete automatic start is planing but not implemented yet.

## Script's abilities:
- Check all installed MODs for updates in a Steam Workshop
- Update one selected MOD by name
- Download MOD by Steam AppID
- Fix missed Steam AppID in 'meta.cpp' file during updating/downloading process. 
  - REM: To make fixing possible during an Updating process it need to be manually edited once at first time before update of the selected MOD will started. All further updates will fix automatically it again and again.
- Create symlinks for Updated/Downloaded MODs
- Transform the files and directories names from UPPER to LOWER case

## Dependecies
- curl

## Intstallation: 
1. Clone or download this script to the /home directory of a user which is running an ArmA 3 server.
2. Set up the permissions to execute it for user.
3. Update paths to installed ArmA 3 Linux Server 'mods', to the Workshop directry, where steam downlading the modes and to the Steam WorkShop where the 'steamcmd.sh is located.
4. OPTIONAL: Add your Steam login and password to variables 'STEAM_LOGIN' and 'STEAM_PASS'

## Usage: 
Run the script and follow an instructions.
## Known issues:
- Script can't correctly parse the last update date of a MOD from the Steam WorkShop if it was updated in the past Year or early. (For exapmle, the current year is 2018, but the mod was updated the last time at 2016. So, this situation will generate a message like "date: invalid date ‘24 Aug, 2016 2018’")
- _**NOT A BUG**_: Some MODs has no an application ID in it's **meta.cpp** file (it's = 0). These MODs can't be updated by this script before editing the **meta.cpp** file. To make it work - just copy the MOD's Steam AppID from the MOD's WorkShop link and replace the "0" here
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
2. Implement a batch updating of an all installed MODs
3. Fix an issue with a date parsing from a Steam WorkShop of a too old MODs
