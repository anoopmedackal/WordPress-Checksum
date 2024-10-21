#!/bin/bash
# Script to identify and clean up WordPress installations in a cPanel user account

# Function to validate username
validate_user() {
    if ! id -u "$1" >/dev/null 2>&1; then
        echo "Invalid username"
        exit 1
    fi
}

# Function to perform WordPress checksum and file removal
wp_checksum_and_remove() {
    local cpuser=$1
    su - "$cpuser" -s /bin/bash << EOF
    for docroot in \$(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs -r dirname); do
        cd "\$docroot" || continue
        echo -e "\e[31mRemoving unwanted WP files from \$docroot\e[0m"
        wp core verify-checksums 2>&1 | grep 'File should not exist' | awk '{print \$6}' | xargs -r rm -fv
        echo -e "\e[31mRunning WP checksum\e[0m"
        wp core verify-checksums
        find . -type f -iname '*.php' -print0 | xargs -0 chmod 644
    done
EOF
}

# Function to download WordPress core files
wp_download_core() {
    local cpuser=$1
    su - "$cpuser" -s /bin/bash << EOF
    for docroot in \$(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs -r dirname); do
        cd "\$docroot" || continue
        version=\$(grep -s '^\$wp_version' "wp-includes/version.php" | cut -d\' -f2)
        echo -e "\e[31mDownloading WP core files of version \$version in \$docroot\e[0m"
        wp core download --force --version="\$version"
        find . -type f -iname '*.php' -print0 | xargs -0 chmod 644
    done
EOF
}

# Function to check WordPress installations
check_wp_installations() {
    local cpuser=$1
    su - "$cpuser" -s /bin/bash << EOF
    for docroot in \$(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs -r dirname); do
        cd "\$docroot" || continue
        version=\$(grep -s '^\$wp_version' "wp-includes/version.php" | cut -d\' -f2)
        output=\$(wp core verify-checksums 2>&1 | grep 'File should not exist' | awk '{print \$6}')
        if [ -n "\$output" ]; then
            echo "\$output" >> /home/$cpuser/wp-checklist.txt
        fi
        echo -e "\e[1;33m\$docroot has WordPress version \$version\e[0m"
        echo -e "\e[1;32mFiles that are not part of the WP installation are:\e[0m"
        echo "\$output"
    done
EOF
}

# Main script
read -p "Enter the username: " cpuser
validate_user "$cpuser"

check_wp_installations "$cpuser"

if [ -s "/home/$cpuser/wp-checklist.txt" ]; then
    read -p $'\e[1;31mDo you want this script to delete all the listed files and download WP core files in each WP installation?\e[0m (yes/no): ' answer
    case "${answer,,}" in
        yes)
            wp_checksum_and_remove "$cpuser"
            wp_download_core "$cpuser"
            ;;
        no)
            wp_download_core "$cpuser"
            ;;
        *)
            echo "Invalid input. Please enter 'yes' or 'no'."
            exit 1
            ;;
    esac
    rm -f "/home/$cpuser/wp-checklist.txt"
else
    wp_download_core "$cpuser"
fi
