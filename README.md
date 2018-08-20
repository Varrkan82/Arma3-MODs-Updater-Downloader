# a3upddownmod
# ArmA 3 MODs updater/downloader for Linux Servers 

This script is a full interactive. The complete automatic start is planing but not incremented yet.
This script is able to update the separate (for now) MOD, download separate MOD and to check for updates of an all installed MODs.
After downloading or updating the MOD this script will ask to make a symlink and to change MODs directory name and all files/directories names in it from upper to lower case.

## Intstallation: 
Just clone or download this script to the /home directory of a user which is running an ArmA 3 server. And set up the permissions to execute it for user.
## Usage: 
Run the script and follow instructions.
## Known issues:
- Script can't correctly parse the last update date of a MOD from the Steam WorkShop if it was updated in a Year before the current or earley. (For exapmle, the current year is 2018, but the mod was updated the last time at 2016. So, this situation will generate a message like "date: invalid date ‘24 Aug, 2016 2018’")
- NOT A BUG: Some MODs has no an application ID in it's **meta.cpp** file (it's = 0). These MODs can't be updated by this script before editing the **meta.cpp** file. To make it work (just for a one time, it will be broken after update and need to be edited again before the next update) just copy the MOD's Steam AppID from the MOD's WorkShop link and replace the "0" here
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
ame = "@ACE Compat_RHS_USAF";
timestamp = 5248321387302862629;
```

## Plans
1. Run script with a CLI options to make all jobs automatically
2. Implement a batch updating of an all installed MODs
3. Fix an issue with a date parsing from a Steam WorkShop of a too old MODs
