#!/bin/env bash

source source.sh
# set -e
# set -x

BASE_AUR_URL='https://aur.archlinux.org'
AUR_API_URL=${BASE_AUR_URL}/rpc/v5
SEARCH_TERM='paru'
SEARCH_BY='name-desc'
FURL=${AUR_API_URL}/search/${SEARCH_TERM}?by=${SEARCH_BY}

INSTALL_ACTION=0
UNINSTALL_ACTION=0
SEARCH_ACTION=0

# set search term
while getopts "s:i:u:" opt; do
	case $opt in
		s)
			SEARCH_TERM="$OPTARG"
			SEARCH_ACTION=1
			;;
		i)
			INSTALL_ACTION=1
			SEARCH_TERM="$OPTARG"
			echo "install yes yes"
			;;
		u)
			UNINSTALL_ACTION=1
			SEARCH_TERM="$OPTARG"
			echo "we need to uninstall "$OPTARG""
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
	esac
done


FURL=${AUR_API_URL}/search/${SEARCH_TERM}?by=${SEARCH_BY}

echo ${FURL}
curl -fsS ${FURL} | jq > response.json

# searching
if [ "$SEARCH_ACTION" -eq 1 ]; then
	jq -r '.results[] | "aur/\(.Name) \(.Version) [\(.NumVotes)]\n    \(.Description)\n"' response.json
fi

# uninstalling
if [ "$UNINSTALL_ACTION" -eq 1 ]; then
	sudo pacman -R "$SEARCH_TERM"
fi

# installing
if [ "$INSTALL_ACTION" -eq 1 ]; then
	# install stuff i guess
	echo "should install"
	PACKAGE_DETAILS=$(jq --arg SEARCH_TERM "$SEARCH_TERM" '.results[] | select(.PackageBase == $SEARCH_TERM)' response.json)

	if [ -n "$PACKAGE_DETAILS" ]; then
		echo "$SEARCH_TERM found"
		PACKAGE_BASE_NAME=$(echo "$PACKAGE_DETAILS" | jq -r '.PackageBase')
		GIT_CLONE_URL=${BASE_AUR_URL}/${PACKAGE_BASE_NAME}.git
		if dir_exists "$PACKAGE_BASE_NAME"; then
			echo "dir already exists"
			rm -rf "$PACKAGE_BASE_NAME"
		fi

		# clone the package
		git clone "$GIT_CLONE_URL" --depth 1

		# move into the cloned package
		cd "$PACKAGE_BASE_NAME"

		# run install script
		makepkg -si

		# move into previous working directory
		cd ..

		# cleanup
		rm -rf "$PACKAGE_BASE_NAME"
	else
		echo "$SEARCH_TERM not found"
	fi

	echo "installing"
fi


