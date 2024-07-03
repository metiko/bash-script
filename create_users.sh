#!/bin/bash

# Ensure the script is run with a file argument
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <user-groups-file>"
  exit 1
fi

# Input file
INPUT_FILE=$1

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File $INPUT_FILE does not exist."
  exit 1
fi

# Log file
LOG_FILE="/var/log/user_management.log"

# Secure file for passwords
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure log and password files exist
mkdir -p /var/log
touch $LOG_FILE

mkdir -p /var/secure
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# Function to generate random password
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo ''
}

# Read each line from the file
while IFS=';' read -r user groups; do
  user=$(echo $user | xargs)  # Trim whitespace
  groups=$(echo $groups | xargs)  # Trim whitespace

  if id "$user" &>/dev/null; then
    log_message "User $user already exists."
    continue
  fi

  # Create user
  if ! useradd -m -s /bin/bash "$user"; then
    log_message "Failed to create user $user."
    continue
  fi
  log_message "User $user created successfully."

  # Create user's personal group
  if ! groupadd "$user"; then
    log_message "Failed to create group $user."
  fi
  usermod -aG "$user" "$user"
  log_message "User $user added to personal group $user."

  # Add user to additional groups
  IFS=',' read -r -a group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo $group | xargs)  # Trim whitespace
    if ! getent group "$group" &>/dev/null; then
      if ! groupadd "$group"; then
        log_message "Failed to create group $group for user $user."
        continue
      fi
      log_message "Group $group created."
    fi
    usermod -aG "$group" "$user"
    log_message "User $user added to group $group."
  done

  # Generate password and store securely
  password=$(generate_password)
  echo "$user,$password" >> $PASSWORD_FILE
  log_message "Password for user $user stored securely."

  # Set permissions for home directory
  chown "$user:$user" /home/"$user"
  chmod 700 /home/"$user"
  log_message "Permissions set for home directory of user $user."

done < "$INPUT_FILE"

log_message "User creation process completed."

exit 0
