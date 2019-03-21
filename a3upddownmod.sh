#!/bin/bash

: << LICENSE

MIT License

Copyright (c) 2018 Vitalii Bieliavtsev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

LICENSE

: << EXITCODES

1 - Some external program error
2 - No authentication data for Steam account
3 - Wrong selection
4 - Wrong MODs name
5 - Can not creeate the symbolic link
6 - Wrong MODs ID in "meta.cpp" file ("0" as usually)
7 - Interrupted by user

EXITCODES

# Mandatory variables
STMAPPID="107410"                 # AppID of an ArmA 3 which used to download the MODs. Should not be changed usually.
CURRYEAR=$(date +%Y)                  # Current year
CURL_CMD="/usr/bin/curl"               # CURL command
STEAM_CHLOG_URL="https://steamcommunity.com/sharedfiles/filedetails/changelog"    # URL to get the date of the last MOD's update in a WorkShop
# Change it according to your paths
STMCMD_PATH="/home/steam/arma3server/steamcmd"            # Path to 'steamcmd.sh' file
# INST_MODS_PATH="/home/steam/arma3server/serverfiles/mods"       # Path to ArmA 3 installed MODs in an installed  ArmA 3 server's directory
WKSHP_PATH="/home/steam/Steam/steamapps/workshop"         # Path to there is Workshop downloaded the MODs

if [[ ! -f ../auth.sh ]]; then
# Optional variables
    STEAM_LOGIN=""                    # Steam login (with a purchased ArmA 3)
    STEAM_PASS=""                   # Steam password
  else
    source ./auth.sh
    STEAM_PASS="$(echo ${STEAM_PASS} | base64 -d)"
fi

# Check for needed paths and for CURL
if [[ ! -d "${STMCMD_PATH}" || ! -d "${WKSHP_PATH}" ]]; then
  echo "Some path(s) is/(are) missing. Check - does an all paths are correctly setted up! Exit."
  exit 11
elif [[ ! -f "${CURL_CMD}" ]]; then
  echo "CURL is missing. Check - does it installed and pass the correct path to it into variable 'CURL_CMD'. Exit."
fi

## Functions
# Check authorization data for Steam
authcheck(){
  # Checking for does the Steam login and password are pre-configured?
  if [[ -z "${STEAM_LOGIN}" ]]; then
    clear
    read -e -p "Steam login is undefined. Please, enter it now: " STEAM_LOGIN
    if [[ -z "${STEAM_LOGIN}" ]]; then
      echo -ne "Steam login not specified! Exiting!\n"
      exit 2
    fi
  fi
  if [[ -z "${STEAM_PASS}" ]]; then
    clear
    read -sep "Steam password is undefined. Please, enter it now (password will not be displayed in console output!): " STEAM_PASS
    if [[ -z "${STEAM_PASS}" ]]; then
      echo -ne "Steam password not specified! Exiting!\n"
      exit 2
    fi
  fi
  clear
}

backupwkshpdir(){
  if [[ "${MOD_ID}" = "" ]]; then
    exit 100
  fi
  FULL_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
  if [[ -d "${FULL_PATH}" ]]; then
    echo "Workshop target directory for MOD ${MOD_NAME} is already present. Moving it to ${FULL_PATH}_old_$(date +%y%m%d-%H%M)"
    mv -f "${FULL_PATH}" "${FULL_PATH}_old_$(date +%y%m%d-%H%M)" &>/dev/null
  fi
}

# Get original MOD's name from meta.cpp file
get_mod_name(){
  if [[ "${MOD_ID}" = "" ]]; then
    exit 100
  fi
  FULL_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
  if [[ -f "${FULL_PATH}"/meta.cpp ]]; then
    grep -h "name" "${FULL_PATH}"/meta.cpp | \
    awk -F'"' '{print $2}' | \
    tr -d "[:punct:]" | \
    tr "[:upper:]" "[:lower:]" | \
    sed -E 's/\s{1,}/_/g' | \
    sed 's/^/\@/g'
  fi
}

# Mod's application ID from meta.cpp file
get_mod_id(){
  if [[ "${MOD_ID}" = "" ]]; then
    exit 100
  fi
  FULL_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
  if [[ -f "${FULL_PATH}"/meta.cpp ]]; then
    grep -h "publishedid" "${FULL_PATH}"/meta.cpp | \
    awk '{print $3}' | \
    tr -d [:punct:]
  fi
}

# Get the MOD's last updated date from Steam Workshop
get_wkshp_date(){
  if [[ "$(${CURL_CMD} -s ${URL} | grep -m1 "Update:" | wc -w)" = "7" ]]; then
    PRINT="$(${CURL_CMD} -s ${URL} | grep -m1 "Update:" | tr -d "," | awk '{ print $2" "$3" "$4" "$6 }')"
  else
    PRINT="$(${CURL_CMD} -s ${URL} | grep -m1 "Update:" | awk '{ print $2" "$3" "'${CURRYEAR}'" "$5 }')"
  fi
  WKSHP_UP_ST="${PRINT}"
}

countdown(){
  local TIMEOUT="10"
  for (( TIMER="${TIMEOUT}"; TIMER>0; TIMER--)); do
    printf "\rDisplay the list in: ${TIMER}\nor Press any key to continue without waiting... :)"
    read -s -t 1 -n1
    if [[ "$?" = "0" ]]; then
      break
    fi
    clear
  done
}


fixuppercase() {
    find ${FULL_PATH} -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
    if [[ "$?" = "0" ]]; then
      echo "Fixed upper case for MOD ${MOD_NAME}"
    fi

}

# Fix Steam application ID
fixappid(){
  if [[ -z "$MOD_ID" ]]; then
    exit 100
  fi
  FULL_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
  if [[ "$?" = "0" ]]; then
    DMOD_ID=$(get_mod_id)         # Downloaded MODs ID
    DMOD_ID="${DMOD_ID%$'\r'}"
    if [[ "${DMOD_ID}" = "0" ]]; then
      echo "Steam ApplicationID is 0. Will try to fix."
      sed -i 's/^publishedid.*$/publishedid \= '${MOD_ID}'\;/' "${FULL_PATH}"/meta.cpp
      if [[ "$?" = "0" ]]; then
        echo "Steam ApplicationID is fixed."
      fi
    fi
  fi
}

# Check all installed mods for updates in Steam Workshop.
checkupdates(){
  echo "Checking for updates..."
  # check all installed MODs for updates.
  TO_UP=( )
  MOD_UP_CMD=( )
  MOD_ID_LIST=( )
  for MODs_NAME in $(ls -1 ${WKSHP_PATH}/content/${STMAPPID} | grep -v -E "*old*"); do
    MOD_ID=$(grep "publishedid" ${WKSHP_PATH}/content/${STMAPPID}/${MODs_NAME}/meta.cpp | awk -F"=" '{ print $2 }' | tr -d [:blank:] | tr -d [:space:] | tr -d ";$")
    MOD_ID="${MOD_ID%$'\r'}"
    URL="${STEAM_CHLOG_URL}/${MOD_ID}"
    URL="${URL%$'\r'}"
    MOD_NAME=$(grep "name" ${WKSHP_PATH}/content/${STMAPPID}/${MODs_NAME}/meta.cpp | awk -F"=" '{ print $2 }' | sed 's/\s/_/g' | tr -d ";$")
    if [[ "${MOD_ID}" = "" ]]; then
      exit 100
    fi
    FULL_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"

    get_wkshp_date

    UTIME=$(date --date="${WKSHP_UP_ST}" +%s)
    echo ${FULL_PATH}
    CTIME=$(date --date="$(stat ${FULL_PATH} | grep Modify | cut -d" " -f2-)" +%s ) 				#Fix for MC syntax hilighting #"

    if [[ "${MOD_ID}" = "0" ]]; then
      echo -ne "\033[37;1;41mWrong ID for MOD ${MOD_NAME} in file 'meta.cpp'\033[0m You can update it manually and the next time it will be checked well. \n"
      continue
    elif [[ ! -f "${WKSHP_PATH}/content/${STMAPPID}/${MODs_NAME}/meta.cpp" ]]; then
      echo -ne "\033[37;1;41mNo 'meta.cpp' file found for MOD ${MOD_NAME}.\033[0m\n"
      continue
    else
      # Compare update time
      if [[ ${UTIME} -gt ${CTIME} ]]; then
        # Construct the list of MODs to update
        MOD_UP_CMD+="+workshop_download_item ${STMAPPID} ${MOD_ID} "
        TO_UP+="${MOD_NAME} "
        MOD_ID_LIST+="${MOD_ID} "
        echo -en "\033[37;1;42mMod ${MOD_NAME} can be updated.\033[0m\n"
        continue
      else
        echo "MOD ${MOD_NAME} is already up to date!"
        continue
      fi
    fi
  done
  export TO_UP
  export MOD_UP_CMD
}

# Download MOD by its ID
download_mod(){
  until "${STMCMD_PATH}"/steamcmd.sh +login "${STEAM_LOGIN}" "${STEAM_PASS}" "${MOD_UP_CMD}" validate +quit; do
    echo "Retrying after error while downloading."
    sleep 3
  done

  fixappid

  echo -e "\n"
}

# Update single MOD
update_mod(){
  if [[ "${MOD_ID}" = "" ]]; then
    exit 100
  fi
  FULL_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
  rm -rf "${FULL_PATH}"

  download_mod
  fixuppercase
}

simplequery(){
  SELECT=false
  while ! $SELECT; do
    read -e -p "Enter [y|Y]-Yes, [n|N]-No or [quit]-to abort: " ANSWER
    case "${ANSWER}" in
      y | Y )
        SELECT=true
        ;;
      n | N )
        SELECT=true
	return 1
        ;;
      quit )
        echo -ne "\033[37;1;41mWarning!\033[0m Some important changes wasn't made. This could or could not to cause the different problems.\n"
        exit 7
	      ;;
      * )
        echo -ne "Wrong selection! Try again or type 'quit' to interrupt process.\n"
        ;;
    esac
  done
}

# Update all MODs in a batch mode
update_all(){
  TMP_NAMES=("${TO_UP[@]}")
  TMP_IDS=("${MOD_ID_LIST[@]}")
  for MOD_ID in ${TMP_IDS[@]} ; do
    if [[ -z "$MOD_ID" ]]; then
      exit 100
    fi
    FULL_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"

    backupwkshpdir ${MOD_ID}
    MOD_UP_CMD="+workshop_download_item ${STMAPPID} ${MOD_ID} "
    rm ${STMCMD_PATH}/appworkshop_${STMAPPID}.acf

    download_mod

    fixuppercase

    unset MOD_ID
    unset MOD_NAME
  done
}


## End of a functions block

# Ask user for action
echo -ne "After selecting to 'Update' -> 'Single' - you will see the list of installed MODs.\n\033[37;1;41mPlease, copy the needed \"publishedid\" before exiting from the list.\nIt will be unavailabe after exit.\nTo get the list again - you'll need to restart the script\033[0m\n"
echo -ne "What do you want to do? \n [u|U] - Update MOD \n [c|C] - Check all MODs for updates\n [d|D] - Download MOD?\n"
echo -ne "Any other selection will cause script to stop.\n"

read -e -p "Make selection please: " ACTION

case "${ACTION}" in
  # Actions section
  c | C )
    checkupdates

    # Print MODs which could be updated
    if [[ ! -z "${TO_UP[@]}" ]]; then
      echo -ne "Mods ${TO_UP[*]} can be updated. Please, proceed manually."
    else
      echo "All MODs are up to date. Exiting."
      exit 0
    fi
    ;;
  u | U )
    clear
    # Ask user to select update mode

    read -e -p "How do you want to update? [b|B]-Batch or [s|S]-Single MOD? " UPD_M
    case "${UPD_M}" in
      b | B )
	# Check updates for installed MODs
        checkupdates
        # Print MODs which could be updated
        if [[ ! -z "${TO_UP[@]}" ]]; then
          echo -e "Mods ${TO_UP[@]} can be updated. Do you want to proceed? [y|Y] or [n|N]: "
          simplequery

          if [[ "$?" = "0" ]]; then
            authcheck
          else
            exit 7
          fi

	  update_all

        else
          echo "All MODs are up to date. Exiting."
          exit 0
        fi
        ;;
      s | S )
        authcheck

        countdown

        echo -ne "$(grep -hr -A1 'publishedid' --include=meta.cpp -E --exclude-dir='*_old_*' ${WKSHP_PATH}/content/${STMAPPID})\n" | less
        echo -ne "Please, specify MOD's ID.\n"
        # Ask user to enter a MOD's name to update
        echo -ne "You have installed a MODs listed above. Please, enter the MODs ID to update:\n"
	unset MOD_ID
	unset FULL_PATH
        read -er MOD_ID

        # Check syntax
	DIGITS="^[0-9]+$"
        if ! [[ "${MOD_ID}" =~ ${DIGITS} ]] && [[ "${MOD_ID}" = "" ]]; then
          echo -ne "Wrong MOD's ID! Exiting!\n"
          exit 4
        else
          # Update the single selected MOD
          MOD_ID="${MOD_ID%$'\r'}"
	  MODS_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
	  MOD_NAME=$(get_mod_name)
	  echo "Starting to update MOD ${MOD_NAME}..."

          if [[ "${MOD_ID}" = "0" ]]; then
            echo -ne "MOD application ID is not configured for mod ${MOD_NAME} in file ${FULL_PATH}/meta.cpp \n"
            echo -ne "Find it by the MODs name in a Steam Workshop and update in MODs 'meta.cpp' file or use Download option to get MOD by it's ID. Exiting.\n"
            exit 6
          elif [[ -z "${MOD_ID}" ]]; then
            echo -ne "\033[37;1;41mNo 'meta.cpp' file found for MOD ${MOD_NAME}.\033[0m\n"
            continue
          fi

          URL="${STEAM_CHLOG_URL}/${MOD_ID}"
          URL="${URL%$'\r'}"

          get_wkshp_date

          UTIME=$(date --date="${WKSHP_UP_ST}" +%s)
          CTIME=$(date --date="$(stat ${MODS_PATH} | grep Modify | cut -d" " -f2-)" +%s )   #Fix for MC syntax hilighting #"
          if [[ ${UTIME} -gt ${CTIME} ]]; then
            MOD_UP_CMD=+"workshop_download_item ${STMAPPID} ${MOD_ID}"
            echo "${MOD_UP_CMD}"

            backupwkshpdir
            update_mod

            if [[ "$?" = "0" ]]; then
              echo "MODs updateis successfully downloaded to ${FULL_PATH}"

              fixappid "${FULL_PATH}"

              # Ask user to transform the names from upper to lower case
              echo "Do you want to transform all files and directories names from UPPER to LOWER case?"

              simplequery

              if [[ "$?" = "0" ]]; then
                find "${FULL_PATH}" -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
                exit 0
              elif [[ "$?" = "1" ]]; then
                echo -ne "\033[37;1;41mWarning!\033[0m You're selected to DO NOT transform the Upper case letters in a MOD's directory and file name.\n It could cause the probles connecting the MOD to ArmA 3.\n"
              fi

            fi
          else
            echo -ne "\033[37;1;42mMOD ${MOD_NAME} is already up to date.\033[0m \n"
            exit 0
          fi
        fi
        ;;
      * )
        echo -ne "Wrong selection! Exiting.\n"
        exit 7
        ;;
    esac
    ;;

  d | D )
    # Download section
    authcheck
    echo ""
    # Ask user to enter a MOD Steam AppID
    read -e -p "Please, enter an Application ID in a Steam WokrShop to dowdnload: " MOD_ID
    echo "Application ID IS: ${MOD_ID}\n"
    echo "Starting to download MOD ID ${MOD_ID}..."
    MODS_PATH=${FULL_PATH}
    MOD_UP_CMD=+"workshop_download_item ${STMAPPID} ${MOD_ID}"
    echo "${MOD_UP_CMD}"

    download_mod

    fixappid

    # Ask user to transform the names from upper to lower case
    echo -ne "Do you want to transform all file's and directories names from UPPER to LOWER case?\n"

    simplequery

    if [[ "$?" = "0" ]]; then
      find "${FULL_PATH}" -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
      exit 0
    elif [[ "$?" = "1" ]]; then
      echo -ne "\033[37;1;41mWarning!\033[0m You're selected to DO NOT transform the Upper case letters in a MOD's directory and file name.\n It could cause the probles with connecting the MOD to ArmA 3.\n"
      echo ""
      exit 0
    fi
    ;;

  * )
    echo -ne "Wrong selection! Exiting!\n"
    exit 3
    ;;
esac
echo ""

exit 0
