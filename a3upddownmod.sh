#!/bin/bash

: << LICENSE

MIT License

Copyright (c) 2018 

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

EXITCODES

# Mandatori varables
STMAPPID="107410"									# AppID of an ArmA 3 which used to download the MODs
STMCMD_PATH="/home/steam/arma3server/steamcmd"						# Path to 'steamcmd' sh file
INST_MODS_PATH="/home/steam/arma3server/serverfiles/mods"				# Path to ArmA 3 installed MODs in an installed  ArmA 3 server's directory
WKSHP_PATH="/home/steam/Steam/steamapps/workshop"					# Path to there is Workshop downloaded the MODs
STEAM_CHLOG_URL="https://steamcommunity.com/sharedfiles/filedetails/changelog"		# URL to get the date of the last MOD's update in a WorkShop
CURRYEAR=$(date +%Y)									# Current year
CURL_CMD="/usr/bin/curl -s"								# CURL command

# Optional variables
STEAM_LOGIN=""										# Steam login (with a purchased ArmA 3)
STEAM_PASS=""										# Steam password

# Check are Steam login and passwrod is setted
if [[ -z "${STEAM_LOGIN}" ]]; then
    clear
    echo -ne "Steam login is undefined. Please, enter it now:\n"
    read -er STEAM_LOGIN
    if [[ -z "${STEAM_LOGIN}" ]]; then
	echo -ne "Steam login not specified! Exiting!\n"
	exit 2
    fi
fi
if [[ -z "${STEAM_PASS}" ]]; then
    clear
    echo -ne "Steam password is undefined. Please, enter it now (password will not be displayed in console output!):\n"
    read -sr STEAM_PASS
    if [[ -z "${STEAM_PASS}" ]]; then
	echo -ne "Steam password not specified! Exiting!\n"
	exit 2
    fi
fi


## Functions
get_mod_name(){
    grep -h "name" "${MODS_PATH}"/meta.cpp | \
    awk -F'"' '{print $2}' | \
    tr -d "[:punct:]" | \
    tr "[:upper:]" "[:lower:]" | \
    sed -E 's/\s{1,}/_/g' | \
    sed 's/^/\@/g'
}

get_mod_id(){
    grep -h "publishedid" "${MODS_PATH}"/meta.cpp | \
    awk '{print $3}' | \
    tr -d [:punct:]
}

: << INPROGRESS
update_all(){
    "${STMCMD_PATH}"/steamcmd.sh +login "${STEAM_LOGIN}" "${STEAM_PASS}" "${MOD_UP_CMD}" validate +quit
}
INPROGRESS

update_mod(){
    rm -rf "${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
    "${STMCMD_PATH}"/steamcmd.sh +login "${STEAM_LOGIN}" "${STEAM_PASS}" "${MOD_UP_CMD}" validate +quit
    if [[ "$?" != "0" ]]; then
	echo -ne "Unknown error while downloading from Steam Workshop. Exiting.\n"
	exit 1
    else
	echo -e "\n"
    fi
}

download_mod(){
    "${STMCMD_PATH}"/steamcmd.sh +login "${STEAM_LOGIN}" "${STEAM_PASS}" "${MOD_UP_CMD}" validate +quit
    if [[ "$?" != "0" ]]; then
	echo -ne "Unknown error while downloading from Steam Workshop. Exiting.\n"
	exit 1
    else
	echo -e "\n"
    fi
}
## End of a functions block

# List installed mods
INST_MODS_LIST=($(ls -1 "${INST_MODS_PATH}"))

clear

# Ask user for action
echo -ne "What do you want to do? Update(u/U) or Download(d/D) MOD? Any other selection will cause script to stop.\n"
echo -ne "After selecting to 'Update' - you will see the list of installde MODs.\n"

read -r -n1 ACTION

case "${ACTION}" in
    # Update section
    u | U )
	clear
	echo -ne "$(ls ${INST_MODS_PATH})\n" | less
	echo -ne "Please, specify MOD's name (with '@' symbol in the begining too). Or press 'Enter' to update all installed mods.\n"
	echo -ne "You have installed a MODs listed above. Please, select one or press 'Enter'.\n"
	# Ask user to enter a MOD's name to update
	read -e MOD_NAME
	
	# Check syntax
	if [[ "${MOD_NAME}" != @* && "${MOD_NAME}" != "" ]]; then
	    echo -ne "Wrong MOD's name! Exiting!\n"
	    exit 4
	else
	    # IF the MOD's name is not provided - check all installed MODs for update
	    if [[ -z "${MOD_NAME}" ]]; then
		# Reserved for further usage
		# MOD_UP_CMD=( )
		TO_UP=( )
		for MOD_NAME in "${INST_MODS_LIST[@]}"; do
		    MODS_PATH="${INST_MODS_PATH}/${MOD_NAME}"
		    MOD_ID=$(get_mod_id)
		    URL="${STEAM_CHLOG_URL}/${MOD_ID}"
		    URL="${URL%$'\r'}"
		    WKSHP_UP_ST=$(${CURL_CMD} ${URL} | grep -m1 "Update:" | sed 's/\@/'${CURRYEAR}'/' | awk '{print $2" "$3" "$4" "$5}')	# Get the last update time of a MOD from WorkShop

		    UTIME=$(date --date="${WKSHP_UP_ST}" +%s)
		    CTIME=$(date --date="$(stat ${MODS_PATH} | grep Modify | cut -d" " -f2-)" +%s )	#Fix for MC #"
		    # Compare update time
		    if [[ ${UTIME} -gt ${CTIME} ]]; then
			# Construct the list of MODs to update
			TO_UP+="${MOD_NAME}"
			continue
		    else
			echo -ne "MOD ${MOD_NAME} is already up to date!\n"
			continue
		    fi
		done
		# Print MODs which could be updated
		if [[ ! -z "${TO_UP[@]}" ]]; then
		    echo "Mods "${TO_UP[@]}" can be updated. Please, proceed manually."
#		update_all
		else
		    exit 0
		fi
	    else
		# Update the single selected MOD
		MODS_PATH="${INST_MODS_PATH}/${MOD_NAME}"
		MOD_ID=$(get_mod_id)
		if [[ "${MOD_ID}" = "0" ]]; then
		    echo -ne "MOD application ID is not configured for mod ${MOD_NAME} in file ${MODS_PATH}/meta.cpp \n"
		    echo -ne "Find it by the MODs name in a Steam Workshop. Exiting."
		fi
		URL="${STEAM_CHLOG_URL}/${MOD_ID}"
		URL="${URL%$'\r'}"
		WKSHP_UP_ST=$(${CURL_CMD} ${URL}| grep -m1 "Update:" | sed 's/\@/'${CURRYEAR}'/' | awk '{print $2" "$3" "$4" "$5}')

		UTIME=$(date --date="${WKSHP_UP_ST}" +%s)
		CTIME=$(date --date="$(stat ${MODS_PATH} | grep Modify | cut -d" " -f2-)" +%s )		#Fix for MC #"
		if [[ ${UTIME} -gt ${CTIME} ]]; then
		    MOD_UP_CMD='+"workshop_download_item ${STMAPPID} ${MOD_ID}"'
		    echo "${MOD_UP_CMD}"
		    if [[ -d "${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}" ]]; then
			echo -ne "Wokshop target directory for MOD ${MOD_NAME} is already present. Moving it to ${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}_old \n"
			mv -f "${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}" "${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}_old"
		    fi
		    update_mod
		    if [[ "$?" = "0" ]]; then
			echo -ne "MODs updateis successfully downloaded to ${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}\n"
			mv -f "${MODS_PATH}" "${MODS_PATH}"_old
			echo -ne "Old MODs directory is moved to ${MODS_PATH}_old\n Creating symlink for an updated MOD.\n"
			ln -s "${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}" "${MODS_PATH}"
			if [[ "$?" = "0" ]]; then
			    echo -ne "MOD is updated.\n"
			else
			    echo -ne "Warning! Can't create sumbolic link to a target MODs directory. Exit.\n"
			    exit 5
			fi
			# Ask user to transform the names from upper to lower case
			read -r -n1 TRANSFORM
			    case "${TRANSFORM}" in
				y | Y )
				    find "${MODS_PATH}" -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
				    exit 0
				    ;;
				* )
				    echo -ne "Warning! You're selected to DO NOT transform the Upper case letters in a MOD's directory and file name. It could cause the probles in MOD includding to ArmA 3."
				    exit 0
				    ;;
			    esac
		    fi
		else
		    echo -ne "MOD ${MOD_NAME} is already up to date.\n"
		    exit 0
		fi
	    fi
	fi
	;;

    d | D )
	# Download section
	clear
	echo -ne "Please, enter an Application ID in a Steam WokrShop to dowdnload.\n"
	echo ""
	# Ask user to enter a MOD Steam AppID
	read -e MOD_ID
	echo -ne "Application ID IS: ${MOD_ID}\n"
	MODS_PATH="${WKSHP_PATH}/content/${STMAPPID}/${MOD_ID}"
	echo -ne "${MODS_PATH}\n"
	MOD_UP_CMD=+"workshop_download_item ${STMAPPID} ${MOD_ID}"
	echo "${MOD_UP_CMD}"

	download_mod

	echo -ne "Do you want to symlink the downloaded MOD to your MODs folder in ARMA3Server folder?\n"
	# Ask user to create the symbolic link for downloaded MOD to an ArmA 3 Server's mods folder
	read -n1 SLINK
	case "${SLINK}" in
	    y | Y )
		MOD_NAME=$(get_mod_name)
		echo "${MOD_NAME}"
		if [[ -d "${INST_MODS_PATH}/${MOD_NAME}" ]]; then
		    mv "${INST_MODS_PATH}/${MOD_NAME}" "${INST_MODS_PATH}/${MOD_NAME}_old"
		elif [[ -L "${INST_MODS_PATH}/${MOD_NAME}" ]]; then
		    rm "${INST_MODS_PATH}/${MOD_NAME}" ]]
		fi
		ln -s "${MODS_PATH}" "${INST_MODS_PATH}/${MOD_NAME}"
		if [[ "$?" = "0" ]]; then
		    echo -ne "Done! Symbolic link was created!\n"
		else
		    echo -ne "Can't create symbolic link to mode!\n"
		    exit 5
		fi
		;;

	    * )
		echo -ne "Done! Symbolic link not created!\n"
		;;
	esac

	echo -ne "Do you want to transform all file's and directories names from UPPER to LOWER case?\n"
	# Ask user to transform the names from upper to lower case
	read -r -n1 TRANSFORM
	    case "${TRANSFORM}" in
		y | Y )
		    find "${MODS_PATH}" -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
		    exit 0
		    ;;
		* )
		    echo -ne "Warning! You're selected to DO NOT transform the Upper case letters in a MOD's directory and file name. It could cause the probles in MOD includding to ArmA 3."
		    exit 0
		    ;;
	    esac
	;;

    * )
	echo -ne "Wrong selection! Exiting!\n"
	exit 3
	;;
esac
echo ""

exit 0