#!/usr/bin/env bash
set +e

#LC_ALL=C

# Licence block
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

# List of a script exit codes
: << EXITCODES

1 - Some external program error
51 - Some path(s) is/(are) missing.
52 - No authentication data for Steam account
53 - Wrong selection
54 - Wrong MOD ID
55 - Reserved code. Not used
56 - Wrong MODs ID in "meta.cpp" file ("0" as usually)
57 - No MOD_ID in meta.cpp file
58 - Earley interrupted 
60 - Already running

EXITCODES

# Trap exit codes and remove PID file on exit
trap cleanup EXIT QUIT ABRT SIGTERM
trap 'exit $?' ERR
trap 'exit 2' INT
PID_FILE=/tmp/a3upddownmod.pid

cleanup() {
  local EXIT_CODE=$?
  [[ "${EXIT_CODE}" = "60" ]]  && exit "${EXIT_CODE}"
  rm "${PID_FILE}"
  exit "${EXIT_CODE}"
}

if [[ -f "${PID_FILE}" ]]; then
  echo "Already running: PID=$(cat ${PID_FILE})"
  exit 60
else
  echo $$ > "${PID_FILE}"
fi
###

# Mandatory variables
STEAM_APP_ID="107410"
CURL_CMD="/usr/bin/curl"               # CURL command
STEAM_CHANGELOG_URL="https://steamcommunity.com/sharedfiles/filedetails/changelog"    # URL to get the date of the last MOD's update in a WorkShop
# Change it according to your paths
# Path to 'steamcmd' executable file
STEAM_CMD_PATH="/home/steam/server/steamcmd/steamcmd.sh"
# Path to there is Workshop downloaded the MODs
WORKSHOP_PATH="/home/steam/Steam/steamapps/workshop"
# Notification script
NOTIFICATION_SCRIPT=$(dirname "${BASH_SOURCE[0]}")/notify_update_status.sh

# Authentication
if [[ ! -f $(dirname ${BASH_SOURCE[0]})/../auth.sh ]]; then
# Optional variables
    STEAM_LOGIN=""                    # Steam login (with a purchased Arma 3)
    STEAM_PASS=""                   # Steam password
  else
    if [[ $- =~ x ]]; then debug=1; set +x; fi
    source "$(dirname "${BASH_SOURCE[0]}")"/../auth.sh
    STEAM_PASS="$(echo ${STEAM_PASS} | base64 -d)"
    [[ $debug == 1 ]] && set -x

fi

# Check for needed paths and for CURL
if [[ ! -f "${STEAM_CMD_PATH}" || ! -d "${WORKSHOP_PATH}" ]]; then
  echo "Some path(s) is/(are) missing. Check - does an all paths are correctly setted up! Exit."
  return 51
elif [[ ! -f "${CURL_CMD}" ]]; then
  echo "CURL is missing. Check - does it installed and pass the correct path to it into variable 'CURL_CMD'. Exit."
  return 51
fi

## Functions
# Usage
usage() {
  cat << EOF
Usage
  $0 [ -h ] [ -n ] { -c | -u }
  Where:
   -h  -  Show this help
   -n  -  Execute notification script.

   -c  -  Check for MOD's updates, do not update
       OR
   -u  -  Update MODs
EOF
}

# Check authorization data for Steam
  # Checking for does the Steam login and password are pre-configured?
  if [[ -z "${STEAM_LOGIN}" ]]; then
    clear
    read -e -p "Steam login is undefined. Please, enter it now: " STEAM_LOGIN
    if [[ -z "${STEAM_LOGIN}" ]]; then
      echo -ne "Steam login not specified! Exiting!\n"
      exit 52
    fi
  fi
  if [[ -z "${STEAM_PASS}" ]]; then
    clear
    read -sep "Steam password is undefined. Please, enter it now (password will not be displayed in console output!): " STEAM_PASS
    if [[ -z "${STEAM_PASS}" ]]; then
      echo -ne "Steam password not specified! Exiting!\n"
      exit 52
    fi
  fi
  clear

check_mod_id() {
  if [[ -z "${MOD_ID}" ]]; then
    return 57
  fi
}

# Backup
backupwkshpdir() {
  check_mod_id
  FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
  if [[ -d "${FULL_PATH}" ]]; then
    echo "Workshop target directory for MOD ${MOD_NAME} is already present. Moving it to ${FULL_PATH}_old_$(date +%y%m%d-%H%M)"
    mv -f "${FULL_PATH}" "${FULL_PATH}_old_$(date +%y%m%d-%H%M)" &>/dev/null
  fi
}

# Get original MOD's name from meta.cpp file
get_mod_name() {
  check_mod_id
  FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
  if [[ -f "${FULL_PATH}"/meta.cpp ]]; then
    grep -h "name" "${FULL_PATH}"/meta.cpp | \
    awk -F'"' '{print $2}' | \
    tr -d "[:punct:]" | \
    # tr "[:upper:]" "[:lower:]" | \
    sed -E 's/\s{1,}/_/g' | \
    sed 's/^/\@/g'
  fi
}

# Mod's application ID from meta.cpp file
get_mod_id() {
  check_mod_id
  FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
  if [[ -f "${FULL_PATH}"/meta.cpp ]]; then
    grep -h "publishedid" "${FULL_PATH}"/meta.cpp | \
    awk '{print $3}' | \
    tr -d [:punct:]
  fi
}

# Get the MOD's last updated date from Steam Workshop
get_wkshp_date() {
  if [[ "$(${CURL_CMD} -sN ${URL} | grep -m1 "Update:" | wc -w)" = "7" ]]; then
    PRINT="$(${CURL_CMD} -sN ${URL} | grep -m1 -E -o '<p id=".*">' | awk -F'"' '{ print $2}')"
  else
    PRINT="$(${CURL_CMD} -sN ${URL} | grep -m1 -E -o '<p id=".*">' | awk -F'"' '{ print $2}')"
  fi
  WKSHP_UP_ST="${PRINT}"
}

countdown() {
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

# Fix case
fixuppercase() {
    FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
    find "${FULL_PATH}" -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
    if [[ "$?" = "0" ]]; then
      echo -en "Fixed upper case for MOD ${MOD_NAME}\n"
    fi
}

# Fix Steam application ID
fixappid() {
  FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
  check_mod_id
  DMOD_ID=$(get_mod_id)         # Downloaded MODs ID
  DMOD_ID="${DMOD_ID%$'\r'}"
  if [[ "${DMOD_ID}" = "0" ]]; then
    echo "Steam ApplicationID is 0. Will try to fix."
    sed -i 's/^publishedid.*$/publishedid \= '${MOD_ID}'\;/' "${FULL_PATH}"/meta.cpp
    if [[ "$?" = "0" ]]; then
      echo -en "Steam ApplicationID is fixed.\n"
    fi
  fi
}

# Check all installed mods for updates in Steam Workshop.
checkupdates() {
  echo "Checking for updates..."
  # check all installed MODs for updates.
  LIST_TO_UPDATE=( )
  MOD_UP_CMD=( )
  MOD_ID_LIST=( )
  for MOD_DIR in $(ls -1 "${WORKSHOP_PATH}"/content/"${STEAM_APP_ID}" | grep -v -E "*old*"); do
    MOD_ID=$(grep "publishedid" "${WORKSHOP_PATH}"/content/"${STEAM_APP_ID}"/"${MOD_DIR}"/meta.cpp | awk -F"=" '{ print $2 }' | tr -d [:blank:] | tr -d [:space:] | tr -d ";$")
    MOD_ID="${MOD_ID%$'\r'}"
    URL="${STEAM_CHANGELOG_URL}/${MOD_ID}"
    URL="${URL%$'\r'}"
    MOD_NAME=$(grep "name" "${WORKSHOP_PATH}"/content/"${STEAM_APP_ID}"/"${MOD_DIR}"/meta.cpp | awk -F"=" '{ print $2 }' | tr [:space:] "_" | tr -d ";$" | awk -F\" '{ print $2 }')
    check_mod_id
    FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"

    get_wkshp_date

    UPDATE_TIME="${WKSHP_UP_ST}"
    CREATION_TIME=$(date --date="$(stat ${FULL_PATH} | sed '6q;d' | cut -d" " -f2-3)" +%s ) 				#Fix for MC syntax hilighting #"

    if [[ "${MOD_ID}" = "0" ]]; then
      echo -ne "\033[37;1;41mWrong ID for MOD ${MOD_NAME} in file 'meta.cpp'\033[0m You can update it manually and the next time it will be checked well. \n"
      continue
    elif [[ ! -f "${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_DIR}/meta.cpp" ]]; then
      echo -ne "\033[37;1;41mNo 'meta.cpp' file found for MOD ${MOD_NAME}.\033[0m\n"
      continue
    else
      # Compare update time
      if [[ "${UPDATE_TIME}" -gt "${CREATION_TIME}" ]]; then
        # Construct the list of MODs to update
        MOD_UP_CMD+=("+workshop_download_item ${STEAM_APP_ID} ${MOD_ID}")
        LIST_TO_UPDATE+=("${MOD_NAME}")
        MOD_ID_LIST+=("${MOD_ID}")
        echo -en "\033[37;1;42mMod \e[34m${MOD_NAME}\e[37;1;42m ID ${MOD_ID} can be updated.\033[0m\n\n"
        continue
      else
        echo -en "MOD \e[1;32m${MOD_NAME}\e[0m ID ${MOD_ID} is already up to date!\n\n"
        continue
      fi
    fi
  done
  export LIST_TO_UPDATE
  export MOD_UP_CMD
}

# Download MOD by its ID
download_mod() {
  if [[ $- =~ x ]]; then debug=1; set +x; fi
  until "${STEAM_CMD_PATH}" +login "${STEAM_LOGIN}" "${STEAM_PASS}" "${MOD_UP_CMD}" validate +quit; do
    echo -n "\nRetrying after error while downloading.\n"
    sleep 3
  done
  [[ $debug == 1 ]] && set -x
  if [[ ! -d "${WORKSHOP_PATH}"/content/"${STEAM_APP_ID}"/"${MOD_ID}" ]]; then
    echo "NOT Downloaded! Exiting!"
    exit 54
  fi 
  echo -e "\n"
}

# Update single MOD
update_mod() {
  check_mod_id
  FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
  rm -rf "${FULL_PATH}"

  download_mod
  fixuppercase
}

# Ask for confirmation
simplequery() {
  SELECT=false
  while ! "${SELECT}"; do
    read -e -p "Enter [y|Y]-Yes, [n|N]-No or [quit]-to abort: " ANSWER
    case "${ANSWER}" in
      y | Y )
        SELECT=true
        ;;
      n | N )
        SELECT=true
	      exit 1
        ;;
      quit )
        echo -ne "\033[37;1;41mWarning!\033[0m Some important changes wasn't made. This could or could not to cause the different problems.\n"
        exit 58
	      ;;
      * )
        echo -ne "Wrong selection! Try again or type 'quit' to interrupt process.\n"
        ;;
    esac
  done
}

# Update all MODs in a batch mode
update_all() {
  TMP_IDS=("${MOD_ID_LIST[*]}")
  for MOD_ID in ${TMP_IDS[*]}; do
    check_mod_id
    FULL_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
    MOD_NAME="$(get_mod_name)"

    backupwkshpdir "${MOD_ID}"
    MOD_UP_CMD="+workshop_download_item ${STEAM_APP_ID} ${MOD_ID} "

    download_mod
    fixuppercase
    fixappid

    unset MOD_ID
    unset MOD_NAME
  done
}

# Send notification
notify_send() {
  if [[ -n "${DO_NOTIFY}" ]]; then
    "${NOTIFICATION_SCRIPT}" "${MSG_SEND}"
  else
    echo -en "${MSG}" | tr -d '*'
  fi
}

# Check CLI options
DO_CHECK=
DO_UPDATE=
DO_NOTIFY=
while getopts "ucnh" opt; do
  case $opt in
    c)
      DO_CHECK=1
     ;;
    u)
      DO_UPDATE=1
      ;;
    n)
      DO_NOTIFY=1
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      echo "Wrong parameter!"
      exit 1
      ;;
  esac
done
if [[ -n "${DO_CHECK}" && -n "${DO_UPDATE}" ]]; then
  echo "Error: Only one of check or update may be supplied" >&2
  exit 1
elif [[ -z "${DO_CHECK}" && -z "${DO_UPDATE}" && -n "${DO_NOTIFY}" ]]; then
  echo "Error: -n option can not be used separate of others!"
  exit 1
elif [[ -n "${DO_CHECK}" ]]; then
  checkupdates
  if [[ -n "${LIST_TO_UPDATE[*]}" ]]; then
    MSG="Can be updated:\n**- $(echo ${LIST_TO_UPDATE[*]} | sed 's/ /\\n- /g')**\nPlease, proceed manually."
    MSG_SEND=":exclamation: ${MSG}"
    notify_send
    exit 0
  else
    exit 0
  fi
elif [[ -n "${DO_UPDATE}" ]]; then
  checkupdates
  # Print MODs which could be updated
  if [[ -n "${LIST_TO_UPDATE[*]}" ]]; then
    if update_all; then
      MSG="These Mod(s) has been updated:\n**- $(echo ${LIST_TO_UPDATE[*]} | sed 's/ /\\n- /g')**"
      MSG_SEND=":white_check_mark::exclamation: ${MSG}"
      notify_send
      exit 0
    else
      MSG="**WARNING!**\n Something went wrong during update! **Check it!**"
      notify_send
      exit 1
    fi
  else
    exit 0
  fi
fi


## End of a functions block

# Ask user for action
echo -ne "After selecting to 'Update' -> 'Single' - you will see the list of installed MODs.\n\033[37;1;41mPlease, copy the needed \"publishedid\" before exiting from the list.\nIt will be unavailabe after exit.\nTo get the list again - you'll need to restart the script\033[0m\n"
echo -ne "What do you want to do? \n [u|U] - Update MOD \n [c|C] - Check all MODs for updates\n [d|D] - Download MOD?\n [q|Q] - Quit\n]"
echo -ne "Any other selection will cause script to stop.\n"

read -e -p "Make selection please: " ACTION

case "${ACTION}" in
  ## Actions section
  # Check for updates, do not update
  c | C )
    checkupdates

    # Print MODs which could be updated
    if [[ -n "${LIST_TO_UPDATE[*]}" ]]; then
      echo -ne "Mods ${LIST_TO_UPDATE[*]} can be updated. Please, proceed manually."
    else
      echo "All MODs are up to date. Exiting."
      exit 0
    fi
    ;;
  # Proceed update  after check
  u | U )
    clear

    # Ask user to select update mode
    read -e -p "How do you want to update? [b|B]-Batch or [s|S]-Single MOD? " UPD_M
    case "${UPD_M}" in
  # Batch update
      b | B )
	# Check updates for installed MODs
        checkupdates
        # Print MODs which could be updated
        if [[ -n "${LIST_TO_UPDATE[*]}" ]]; then
	        update_all
          echo -ne "These Mods has been updated:\n ${LIST_TO_UPDATE[*]}"
        else
          echo "All MODs are up to date. Exiting."
          exit 0
        fi
        ;;
  # Update a single MOD
      s | S )
        countdown

        echo -ne "$(grep -hr -A1 'publishedid' --include=meta.cpp -E --exclude-dir='*_old_*' ${WORKSHOP_PATH}/content/${STEAM_APP_ID})\n" | less
        echo -ne "Please, specify MOD's ID.\n"
        # Ask user to enter a MOD's name to update
        echo -ne "You have installed a MODs listed above. Please, enter the MODs ID to update:\n"
        unset MOD_ID
        unset FULL_PATH
        read -er MOD_ID

        # Check syntax
	      DIGITS="^[0-9]+$"
        if ! [[ "${MOD_ID}" =~ ${DIGITS} ]] && [[ -z "${MOD_ID}" ]]; then
          echo -ne "Wrong MOD's ID! Exiting!\n"
          exit 54
        else
          # Update the single selected MOD
          MOD_ID="${MOD_ID%$'\r'}"
          MODS_PATH="${WORKSHOP_PATH}/content/${STEAM_APP_ID}/${MOD_ID}"
          MOD_NAME=$(get_mod_name)
          echo "Starting to update MOD ${MOD_NAME}..."

          if [[ "${MOD_ID}" = "0" ]]; then
            echo -ne "MOD application ID is not configured for mod ${MOD_NAME} in file ${FULL_PATH}/meta.cpp \n"
            echo -ne "Find it by the MODs name in a Steam Workshop and update in MODs 'meta.cpp' file or use Download option to get MOD by it's ID. Exiting.\n"
            exit 56
          elif [[ -z "${MOD_ID}" ]]; then
            echo -ne "\033[37;1;41mNo 'meta.cpp' file found for MOD ${MOD_NAME}.\033[0m\n"
            true
          fi

          URL="${STEAM_CHANGELOG_URL}/${MOD_ID}"
          URL="${URL%$'\r'}"

          get_wkshp_date

          UPDATE_TIME="${WKSHP_UP_ST}"
          CREATION_TIME=$(date --date="$(stat ${MODS_PATH} | sed '6q;d' | cut -d" " -f2-3)" +%s )   #Fix for MC syntax hilighting #"
          if [[ ${UPDATE_TIME} -gt ${CREATION_TIME} ]]; then
            MOD_UP_CMD=+"workshop_download_item ${STEAM_APP_ID} ${MOD_ID}"
            echo "${MOD_UP_CMD}"

            backupwkshpdir

            if update_mod; then
              echo "MOD's update is successfully downloaded to ${FULL_PATH}"
              fixappid "${FULL_PATH}"
            fi

          else
            echo -ne "\033[37;1;42mMOD ${MOD_NAME} is already up to date.\033[0m \n"
            exit 0
          fi
        fi
        ;;
      * )
        echo -ne "Wrong selection! Exiting.\n"
        exit 53
        ;;
    esac
    ;;
  # Download new MOD
  d | D )
    echo ""
    # Ask user to enter a MOD Steam AppID
    read -e -p "Please, enter an Application ID in a Steam WorkShop to download: " MOD_ID
    if [[ -d "${WORKSHOP_PATH}"/content/"${STEAM_APP_ID}"/"${MOD_ID}" ]]; then
      echo "Already present! Use UPDATE action. Exiting!"
      exit 1
    fi
    echo "Application ID IS: ${MOD_ID}\n"
    echo "Starting to download MOD ID ${MOD_ID}..."
    MODS_PATH=${FULL_PATH}
    MOD_UP_CMD=+"workshop_download_item ${STEAM_APP_ID} ${MOD_ID}"
    echo "${MOD_UP_CMD}"

    download_mod
    fixuppercase
    fixappid
    ;;
  q | Q )
    echo "Quit"
    exit 0
    ;;
  * )
    echo -ne "Wrong selection! Exiting!\n"
    exit 53
    ;;
esac
echo ""

exit 0
