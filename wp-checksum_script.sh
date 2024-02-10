#!/bin/bash
#####################################
# This is a bash script used to identify WP installations
# in a cPanel user and using wp-cli remove unwanted files 
# and download WP core files according to the installations 
# correct version(optional)
#####################################

read -p "Enter the username: " cpuser
# Validate username 
if ! id -u "$cpuser" >/dev/null 2>&1; then
  echo "Invalid username"
  exit 1
fi

function wp-checksum-with-file-removal() {
su - $cpuser -s /bin/bash << 'EOF'
cpuser=$(whoami)
for docroot in $(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname)
do
        cd $docroot
        version="$(grep -s '^\$wp_version' "wp-includes/version.php" |cut -d\' -f2)"
        echo -e "\e[31mRemoving unwanted WP files from $docroot\e[0m"
        wp core verify-checksums 2>&1 | grep 'File should not exist' | awk '{print $6}'|xargs rm -fv
        echo -e "\e[31mRunning WP checksum\e[0m"
        wp core verify-checksums
done
EOF
}

function wp-checksum() {
su - $cpuser -s /bin/bash << 'EOF'
cpuser=$(whoami)
for docroot in $(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname)
do
        cd $docroot
        version="$(grep -s '^\$wp_version' "wp-includes/version.php" |cut -d\' -f2)"
        echo -e "\e[31mDownloading WP core files of version $version in $docroot\e[0m"
        wp core download --force --version=$version
done
EOF
}


# cPanel user to check
su - $cpuser -s /bin/bash << 'EOF' 
cpuser=$(whoami)
# Finds WP installations and their versions along with unwanted files on WP
for docroot in $(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname)
do
	cd $docroot
	version="$(grep -s '^\$wp_version' "wp-includes/version.php" |cut -d\' -f2)"
	output="$(wp core verify-checksums 2>&1 | grep 'File should not exist' | awk '{print $6}')"
	cd - > /dev/null
	for item in "$output"; do
		if [[ -n "$item" ]]; then 
    			echo "$item" >> wp-checklist.txt
		fi
	done
	echo -e "\e[1;33m$docroot has WordPress version $version\e[0m \n\e[1;32mFiles that are not part of the WP installation are:\e[0m \n$output"
done
EOF


if [ -s "/home/$cpuser/wp-checklist.txt" ]; then
	read -p $'\e[1;31mDo you want this script to delete all the files listed above and download WP core files in each WP installations?\e[0m (yes/no): ' answer
	answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
	if [[ $answer == "yes" ]]; then
		wp-checksum-with-file-removal
		wp-checksum
		rm -f "/home/$cpuser/wp-checklist.txt"
	elif [[ $answer == "no" ]]; then
		wp-checksum		
		rm -f "/home/$cpuser/wp-checklist.txt"
		exit 0
	else
		rm -f "/home/$cpuser/wp-checklist.txt"
		echo "Invalid input. Please enter 'yes' or 'no'."
		wp-checksum
		exit 1
	fi
else
	wp-checksum
	exit 0
fi
