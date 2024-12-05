#!/bin/bash
# Script to identify and clean up WordPress installations in a cPanel user account
# This script helps to verify WordPress file integrity, remove unwanted files, 
# update WordPress core, plugins, and themes, and download fresh core files when necessary.

# Function to validate username
validate_user() {
    if ! id -u "$1" >/dev/null 2>&1; then
        echo -e "\e[1;31mError: Invalid username provided.\e[0m"
        exit 1
    fi
    echo -e "\e[1;32mValid username: $1\e[0m"
}

# Function to perform WordPress checksum verification and file removal
wp_checksum_and_remove() {
    local cpuser=$1
    echo -e "\n\e[1;34mStarting WordPress file cleanup and checksum verification for user: $cpuser\e[0m"
    su - "$cpuser" -s /bin/bash << EOF
    while read -r docroot; do
        cd "\$docroot" || continue
        echo -e "\e[1;33mChecking and removing unwanted WP files from \$docroot\e[0m"
        # Remove unwanted files as part of checksum validation
        wp core verify-checksums 2>&1 | grep 'File should not exist' | awk '{print \$6}' | while read -r file; do
            echo -e "\e[1;32mCapturing metadata before deletion\e[0m"
            stat "\$file"
            echo -e "\e[1;32mmd5 checksum\e[0m" 
            md5sum "\$file"
            # Remove the unwanted file
            rm -fv "\$file"
        done
        echo -e "\e[1;33mRunning WordPress checksum validation in \$docroot...\e[0m"
        wp core verify-checksums
        find . -type f -iname '*.php' -exec chmod 644 {} \;     
    done < <(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname)
EOF
    echo -e "\n\e[1;32mCleanup and checksum verification completed successfully!\e[0m"
}

# Function to download the correct WordPress core files for each installation and more cleanups
wp_download_core() {
    local cpuser=$1
    echo -e "\n\e[1;34mDownloading WordPress core files for user: $cpuser\e[0m"
    su - "$cpuser" -s /bin/bash << EOF
    while read -r docroot; do
        cd "\$docroot" || continue
        version=\$(grep -s '^\$wp_version' "wp-includes/version.php" | cut -d\' -f2)
        echo -e "\e[1;33mDownloading WordPress core files of version \$version for installation in \$docroot\e[0m"
        wp core download --force --version="\$version"
        find . -type f -iname '*.php' -exec chmod 644 {} \;
                # Remove PHP files in the uploads folder
        echo -e "\e[1;33mRemoving PHP files in wp-content/uploads directory...\e[0m"
        find wp-content/uploads/ -type f -iname '*.php' -exec rm -fv {} \;
        
        # Update the WordPress database
        echo -e "\e[1;33mUpdating WordPress database...\e[0m"
        wp core update-db
        
        # Update all plugins
        echo -e "\e[1;33mUpdating all installed plugins in \$docroot...\e[0m"
        wp plugin update --all

        # Update all themes
        echo -e "\e[1;33mUpdating all installed themes in \$docroot...\e[0m"
        wp theme update --all
        
        #Plugins that failed checksum 
        echo -e "\e[1;33mPlugins that failed checksum in \$docroot\e[0m"
        wp plugin verify-checksums --all --format=csv | grep 'File was added'|cut -d, -f1|uniq
        
        # Removing unwanted plugin files based on checksum results
        echo -e "\e[1;33mRemoving unwanted plugin files based on checksum results for \$docroot\e[0m"
        cd wp-content/plugins
        wp plugin verify-checksums --all --format=csv | grep 'File was added' | sed 's/,/\//; s/,".*"//' | xargs rm -fv
        cd -
        
        # List all administrators (to check for any suspicious users)
        echo -e "\e[1;33mListing all WordPress administrators in \$docroot\e[0m"
        wp user list --role=administrator

        # Shuffle salts in wp-config for added security
        echo -e "\e[1;33mShuffling WordPress salts for security...\e[0m"
        wp config shuffle-salts
    done < <(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname)
EOF
    echo -e "\n\e[1;32mWordPress core files downloaded successfully!\e[0m"
}

# Function to check existing WordPress installations for unwanted files
check_wp_installations() {
    local cpuser=$1
    echo -e "\n\e[1;34mChecking WordPress installations for unwanted files...\e[0m"
    su - "$cpuser" -s /bin/bash << EOF
    while read -r docroot; do
        cd "\$docroot" || continue
        version=\$(grep -s '^\$wp_version' "wp-includes/version.php" | cut -d\' -f2)
        output=\$(wp core verify-checksums 2>&1 | grep 'File should not exist' | awk '{print \$6}')
        if [ -n "\$output" ]; then
            echo "\$output" >> /home/$cpuser/wp-checklist.txt
            echo -e "\e[1;33m\$docroot has WordPress version \$version\e[0m"
            echo -e "\e[1;32mUnwanted files found in this installation:\e[0m"
            echo "\$output"
        else
            echo -e "\e[1;33m\$docroot has WordPress version \$version\e[0m"
            echo -e "\e[1;32mNo unwanted files found in \$docroot\e[0m"
        fi
    done < <(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname)
EOF
    echo -e "\n\e[1;32mWordPress installations checked successfully.\e[0m"
}

# Main script execution
echo -e "\e[1;34mWelcome to the WordPress Malware Remediation Script!\e[0m"
read -p "Enter the cPanel username (the user with WordPress installations): " cpuser
validate_user "$cpuser"

# Check for WordPress installations and list any unwanted files
check_wp_installations "$cpuser"

# If unwanted files are found, prompt for user confirmation to clean and update
if [ -s "/home/$cpuser/wp-checklist.txt" ]; then
  answer=""
  while [[ "${answer}" != "yes" && "${answer}" != "no" ]]; do
    echo -e "\n\e[1;33mThe following unwanted files have been identified:\e[0m"
    cat "/home/$cpuser/wp-checklist.txt"
    read -p $'\e[1;31mDo you want this script to delete all the files listed above? (yes/no): \e[0m' answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    if [[ $answer = "yes" ]]; then
      wp_checksum_and_remove "$cpuser"
      wp_download_core "$cpuser"
      rm -f "/home/$cpuser/wp-checklist.txt"
    elif [[ $answer = "no" ]]; then
      wp_download_core "$cpuser"
      rm -f "/home/$cpuser/wp-checklist.txt"
      exit 0
    else
      echo -e "\e[1;31mInvalid input. Please enter 'yes' or 'no'. Exiting...\e[0m"
      rm -f "/home/$cpuser/wp-checklist.txt"
      exit 1
    fi
  done
else
  echo -e "\n\e[1;32mNo unwanted files found. Proceeding with WordPress core download...\e[0m"
  wp_download_core "$cpuser"
fi

echo -e "\n\e[1;32mScript execution completed successfully.\e[0m"
