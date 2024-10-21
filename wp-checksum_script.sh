#!/bin/bash
#####################################
# Script to identify WP installations in a cPanel user,
# remove unwanted files, and download correct WP core files.
#####################################

read -p "Enter the username: " cpuser

# Validate username
if ! id -u "$cpuser" >/dev/null 2>&1; then
  echo "Invalid username"
  exit 1
fi

# Function to remove unwanted files and verify WP core checksums
wp_checksum_with_removal() {
  su - "$cpuser" -s /bin/bash <<'EOF'
  for docroot in $(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname); do
    cd "$docroot" || continue
    echo -e "\e[31mRemoving unwanted WP files from $docroot\e[0m"
    wp core verify-checksums 2>&1 | awk '/File should not exist/ {print $6}' | xargs rm -fv
    echo -e "\e[31mRunning WP checksum\e[0m"
    wp core verify-checksums
    find . -type f -iname '*.php' -exec chmod 644 {} \;
  done
EOF
}

# Function to download correct WP core files based on version
wp_checksum() {
  su - "$cpuser" -s /bin/bash <<'EOF'
  for docroot in $(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname); do
    cd "$docroot" || continue
    version=$(grep -s '^\$wp_version' "wp-includes/version.php" | cut -d\' -f2)
    echo -e "\e[31mDownloading WP core files of version $version in $docroot\e[0m"
    wp core download --force --version="$version"
    find . -type f -iname '*.php' -exec chmod 644 {} \;
  done
EOF
}

# Finds WP installations, their versions, and unwanted files
find_wp_installations() {
  su - "$cpuser" -s /bin/bash <<'EOF'
  wp_checklist="/home/$cpuser/wp-checklist.txt"
  > "$wp_checklist" # Initialize wp-checklist.txt
  for docroot in $(find "/home/$cpuser/" -type d -iname 'wp-content' | xargs dirname); do
    cd "$docroot" || continue
    version=$(grep -s '^\$wp_version' "wp-includes/version.php" | cut -d\' -f2)
    output=$(wp core verify-checksums 2>&1 | awk '/File should not exist/ {print $6}')
    echo -e "\e[1;33m$docroot has WordPress version $version\e[0m"
    if [[ -n "$output" ]]; then
      echo -e "\e[1;32mFiles that are not part of the WP installation are:\e[0m\n$output"
      echo "$output" >> "$wp_checklist"
    else
      echo -e "\e[1;32mNo unwanted files found in $docroot\e[0m"
    fi
  done
EOF
}

# Check if wp-checklist.txt is not empty and proceed
check_and_execute() {
  if [ -s "/home/$cpuser/wp-checklist.txt" ]; then
    read -p $'\e[1;31mDo you want this script to delete all the files listed above and download WP core files in each WP installation?\e[0m (yes/no): ' answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    if [[ $answer == "yes" ]]; then
      wp_checksum_with_removal
      wp_checksum
    elif [[ $answer == "no" ]]; then
      wp_checksum
    else
      echo "Invalid input. Please enter 'yes' or 'no'."
      exit 1
    fi
    rm -f "/home/$cpuser/wp-checklist.txt"
  else
    wp_checksum
  fi
}

# Main script flow
find_wp_installations
check_and_execute

exit 0
