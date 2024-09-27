### Purpose:

This Bash script is designed to streamline the management of multiple WordPress installations on cPanel or InterWorx servers. Its primary functions include:

1) Identifying WordPress Installations: Automatically locates all WordPress installations within a specified cPanel account.
2) Calculating Checksums: Generates checksums (e.g., MD5 or SHA-256) for core WordPress files to verify their integrity.
3) Detecting Non-Core Files: Identifies any files or directories that are not part of the standard WordPress installation, potentially indicating modifications or malware.
4) Optional Deletion: Provides the option to delete non-core files, which can help maintain the security and stability of WordPress installations.
5) Core File Verification: Re-downloads official WordPress core files and recalculates checksums to ensure that the installation is in a pristine state.

### Benefits:

1) Efficiency: Simplifies the management of numerous WordPress installations, saving time and effort.
2) Security: Helps identify and address potential security vulnerabilities caused by non-core files.
3) Integrity: Ensures that WordPress installations are in a clean and consistent state.

### Usage:
Open your SSH terminal and run the below command as the root user.

`bash <(curl -s https://raw.githubusercontent.com/anoopmedackal/WordPress-Checksum/main/wp-checksum_script.sh)`
