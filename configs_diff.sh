#!/bin/bash

# This script will output .ini and traefik.toml variable changes from a 'git diff > configs.diff'.
# Use this before stashing changes and upgrading CKAN so you can run `make secret` again and input the variable values.
# Note: this script only looks for changes in .ini and traefik.toml (specifically email, main, and rule).

file_path="configs.diff"
output_file="config_changes.txt"

if [ ! -f "$file_path" ]; then
    echo "File $file_path not found. Please run 'git diff > configs.diff' first."
    exit 1
fi

rm -f "$output_file"

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    var="${var%\"}"
    var="${var#\"}"
    echo -n "$var"
}

echo "The following variables have changed in the .ini and traefik.toml files and need to be updated in the secrets:"
echo ""

in_target_file=0
current_file=""

# Parse the diff file
while IFS= read -r line; do
    if [[ "$line" =~ ^diff\ --git\ a/.*\.ini\.template ]]; then
        in_target_file=1
        current_file="ini"
    elif [[ "$line" =~ ^diff\ --git\ a/.*traefik.toml ]]; then
        in_target_file=1
        current_file="toml"
    elif [[ "$line" =~ ^diff\ --git ]]; then
        in_target_file=0
    fi

    # Output the variable changes
    if [[ "$in_target_file" -eq 1 ]]; then
        if [[ "$line" == +* ]] && [[ ! "$line" == "+++"* ]]; then
            line_content="${line:1}"

            if [[ "$current_file" == "toml" && "$line_content" == *email* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Let's Encrypt Email: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "toml" && "$line_content" == *main* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Let's Encrypt Domain: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *ckanext.gtm.gtm_id* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Google Tag Manager ID: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *googleanalytics.id* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Google Analytics ID: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *googleanalytics.account* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Google Analytics Account: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *googleanalytics.username* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Google Analytics Username: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *googleanalytics.password* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Google Analytics Password: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *ckan.sentry.dsn* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "Sentry DSN: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *smtp.server* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "SMTP Server Address (include port, e.g., 'my.smtp.server:587'): $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *smtp.user* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "SMTP Username: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *smtp.password* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "SMTP Password: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *smtp.mail_from* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "SMTP Mail From: $(trim $value)" | tee -a "$output_file"
            elif [[ "$current_file" == "ini" && "$line_content" == *=* ]]; then
                key="${line_content%%=*}"
                value="${line_content#*=}"
                echo "$(trim "$key"): $(trim $value)" | tee -a "$output_file"
            fi
        fi
    fi
done <"$file_path"

if [ ! -s "$output_file" ]; then
    echo ""
    echo "No changes found in .ini or traefik.toml files."
else
    echo ""
    echo "Note: A list of these changes can also be found in '$output_file'. Make sure to run 'git pull' before running 'make secret'."
fi

echo ""
echo "You are now ready to run 'git pull' and continue with the upgrade."
echo ""
