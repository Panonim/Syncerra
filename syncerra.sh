#!/bin/bash
# --- Syncerra - Artur Flis ----

# --- Configuration and Constants ---

# Define APP_FOLDER as the absolute path to the directory where this script resides
APP_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Path to the JSON metadata file storing file mappings
JSON_FILE="$APP_FOLDER/files.json"
VERSION="0.1.0"

# ANSI color codes for styled terminal output
CYAN='\033[0;36m'
MAGENTA='\x1b[35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# --- Utility Functions ---

# shorten_path: strips APP_FOLDER prefix from full paths for nicer terminal display
shorten_path() {
    local fullpath="$1"
    local folder="${APP_FOLDER%/}"
    if [[ "$fullpath" == "$folder"* ]]; then
        echo "${fullpath#$folder/}"
    else
        basename "$fullpath"
    fi
}

# --- Check for dependencies ---

# Ensure `jq` (for JSON parsing) is installed
if ! command -v jq &> /dev/null; then
    echo "'jq' is required but not installed. Install it and try again."
    exit 1
fi

# --- Help Function ---

print_help() {
    echo -e "${CYAN}Usage:${RESET} $(basename "$0") [--add <path>] [--inspect|--inspect-precise] [-h|--help]"
    echo
    echo -e "${MAGENTA}Options:${RESET}"
    echo -e "  ${GREEN}--add <path>         ${RESET}Add a new app with destination path <path>."
    echo -e "  ${GREEN}--inspect            ${RESET}Inspect local vs destination differences (fuzzy UI)."
    echo -e "  ${GREEN}--list               ${RESET}List json entries."
    echo -e "  ${GREEN}--remove             ${RESET}Remove json entry."
    echo -e "  ${GREEN}--inspect-precise    ${RESET}Full diff output using 'diff -ur'."
    echo -e "  ${GREEN}--ip                 ${RESET}Alias for --inspect-precise."
    echo -e "  ${GREEN}-h, --help           ${RESET}Show this help message."
    echo -e "  ${GREEN}-v, --version        ${RESET}Print version information."
    echo
    echo -e "${MAGENTA}Default:${RESET}"
    echo -e "  If no options are passed, will check for mismatches and offer to sync from system to local."
    echo -e "${CYAN}Syncerra:${RESET} ©Artur Flis 2025"
}

# --- Command: Add new file/folder mapping to JSON ---

case "$1" in
    --add)
        shift
        DEST_PATH="$*"

        if [[ -z "$DEST_PATH" ]]; then
            echo -e "${RED}Error: You need to specify a path or file to add.${RESET}"
            exit 1
        fi

        # Normalize to absolute path
        if [[ "$DEST_PATH" != /* ]]; then
            DEST_PATH="$(realpath -m "$PWD/$DEST_PATH")"
        fi

        # Prompt for unique app key (JSON key)
        read -rp "Enter app name (unique key for JSON): " appname

        # Abort if app key already exists
        if jq -e --arg key "$appname" '.[$key]' "$JSON_FILE" &> /dev/null; then
            echo -e "${RED}Error: Key '$appname' already exists in $JSON_FILE.${RESET}"
            exit 1
        fi
        # Ensure JSON file exists; if not, create it
        if [[ ! -f "$JSON_FILE" ]]; then
            mkdir -p "$(dirname "$JSON_FILE")"
            echo '{}' > "$JSON_FILE"
        fi
        # Prompt for local filename or folder to be synced
        read -rp "Enter local file/folder name to create inside app folder: " localfile
        local_path="$APP_FOLDER/$localfile"

        # Detect or create the file/folder and record its type
        if [[ -d "$local_path" ]]; then
            filetype="folder"
        elif [[ -f "$local_path" ]]; then
            filetype="file"
        else
            read -rp "Create as file or folder? [f/d]: " choice
            if [[ "$choice" == "f" ]]; then
                touch "$local_path"
                filetype="file"
            elif [[ "$choice" == "d" ]]; then
                mkdir -p "$local_path"
                filetype="folder"
            else
                echo -e "${RED}Invalid choice. Aborting.${RESET}"
                exit 1
            fi
        fi

        # Add new entry to the JSON file
        jq --arg key "$appname" --arg dest "$DEST_PATH" --arg fname "$local_path" --arg typ "$filetype" \
           '. + {($key): {destination: $dest, filename: $fname, type: $typ}}' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

        echo "Added entry '$appname' in $JSON_FILE:"
        jq --arg key "$appname" '.[$key]' "$JSON_FILE"
        exit 0
        ;;

    # --- Command: Inspect differences between local and destination ---

    --inspect|--inspect-precise|--ip)
        if ! command -v fzf &> /dev/null; then
            echo "'fzf' is required for interactive inspect but not installed."
            exit 1
        fi

        precise=0
        [[ "$1" == "--inspect-precise" || "$1" == "--ip" ]] && precise=1

        declare -A DIFF_APPS

        # Scan all JSON entries and check for mismatches
        while IFS="|" read -r key filename destination type; do
            diff_found=0

            if [[ "$type" == "folder" ]]; then
                # Compare directories
                if [ ! -d "$filename" ] || [ ! -d "$destination" ]; then
                    diff_found=1
                else
                    # Compare contents of each file in destination with local source
                    while IFS= read -r -d '' dest_file; do
                        rel_path="${dest_file#$destination/}"
                        src_file="$filename/$rel_path"
                        if [ ! -f "$src_file" ] || ! cmp -s "$src_file" "$dest_file"; then
                            diff_found=1
                            break
                        fi
                    done < <(find "$destination" -type f -print0)
                fi
            else
                # Compare individual files
                if [ ! -f "$filename" ] || [ ! -f "$destination" ] || ! cmp -s "$filename" "$destination"; then
                    diff_found=1
                fi
            fi

            # Track mismatches
            if [ "$diff_found" -eq 1 ]; then
                DIFF_APPS["$key"]="$filename|$destination|$type"
            fi
        done < <(jq -r 'to_entries[] | "\(.key)|\(.value.filename)|\(.value.destination)|\(.value.type)"' "$JSON_FILE")

        # No diffs found
        if [ ${#DIFF_APPS[@]} -eq 0 ]; then
            echo -e "${GREEN}✅ All files/folders are up to date. No differences to inspect.${RESET}"
            exit 0
        fi

        # Show diffs via fzf UI
        mapfile -t choices < <(for key in "${!DIFF_APPS[@]}"; do
            read -r filename destination type <<< "$(echo "${DIFF_APPS[$key]}" | tr '|' '\n')"
            shortname=$(shorten_path "$filename")
            echo -e "${CYAN}${key}${RESET} (${shortname})"
        done | sort)

        selected=$(printf '%s\n' "${choices[@]}" | fzf --ansi --prompt="Select app to inspect > ")
        if [ -z "$selected" ]; then
            echo "❌ No selection made. Exiting."
            exit 0
        fi

        key=$(echo "$selected" | sed -E 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1)
        IFS='|' read -r filename destination type <<< "${DIFF_APPS[$key]}"

        echo
        echo -e "${CYAN}Inspecting differences for: ${key}${RESET}"

        # Print diffs (file or folder)
        if [[ "$type" == "folder" ]]; then
            if [ ! -d "$filename" ]; then
                echo -e "  ${RED}Local folder missing: $filename${RESET}"
                exit 0
            fi
            if [ ! -d "$destination" ]; then
                echo -e "  ${RED}Destination folder missing: $destination${RESET}"
                exit 0
            fi

            if [[ "$precise" -eq 1 ]]; then
                # Use full `diff -ur` output
                echo -e "${MAGENTA} Showing differences:${RESET}"
                diff -ur "$filename" "$destination" | sed 's/^/  /'
            else
                # Show which files are missing or changed
                diff_files=()
                while IFS= read -r -d '' dest_file; do
                    rel_path="${dest_file#$destination/}"
                    src_file="$filename/$rel_path"
                    if [ ! -f "$src_file" ]; then
                        diff_files+=("Missing file: $rel_path")
                    elif ! cmp -s "$src_file" "$dest_file"; then
                        diff_files+=("Different file: $rel_path")
                    fi
                done < <(find "$destination" -type f -print0)

                if [ ${#diff_files[@]} -eq 0 ]; then
                    echo -e "  ${GREEN}No differing files found.${RESET}"
                else
                    for f in "${diff_files[@]}"; do
                        if [[ "$f" == Missing* ]]; then
                            echo -e "  ${RED}${f}${RESET}"
                        else
                            echo -e "  ${MAGENTA}${f}${RESET}"
                        fi
                    done
                fi
            fi
        else
            # File diff output
            if [ ! -f "$filename" ]; then
                echo -e "  ${RED}Local file missing: $filename${RESET}"
                exit 0
            fi
            if [ ! -f "$destination" ]; then
                echo -e "  ${RED}Destination file missing: $destination${RESET}"
                exit 0
            fi

            if ! cmp -s "$filename" "$destination"; then
                if [[ "$precise" -eq 1 ]]; then
                    echo -e "${MAGENTA} Showing file diff:${RESET}"
                    diff -u "$filename" "$destination" | sed 's/^/  /'
                else
                    echo -e "  ${MAGENTA}Different file:${RESET} $(basename "$filename")"
                fi
            else
                echo -e "  ${GREEN}Files are identical.${RESET}"
            fi
        fi
        exit 0
        ;;
    --list)
        if [ ! -f "$JSON_FILE" ] || [ "$(jq 'keys | length' "$JSON_FILE")" -eq 0 ]; then
            echo -e "${RED}No entries found in $JSON_FILE.${RESET}"
            exit 0
        fi
        echo -e "${CYAN}Current mappings in ${JSON_FILE}:${RESET}"
        echo
        jq -r 'to_entries[] | "\(.key): \(.value.filename) → \(.value.destination) [\(.value.type)]"' "$JSON_FILE" | while IFS= read -r line; do
            key="${line%%:*}"
            rest="${line#*: }"
            file="${rest%% →*}"
            right="${rest#*→ }"
            dest="${right%% [*}"
            type="${right##*[}"
            type="${type%]}"
            echo -e "${MAGENTA}${key}${RESET}: ${CYAN}${file}${RESET} → ${GREEN}${dest}${RESET} [${type}]"
        done
        exit 0
        ;;

    --remove)
        if ! command -v fzf &> /dev/null; then
            echo "'fzf' is required for interactive remove but not installed."
            exit 1
        fi

        if [ ! -f "$JSON_FILE" ] || [ "$(jq 'keys | length' "$JSON_FILE")" -eq 0 ]; then
            echo -e "${RED}No entries found in $JSON_FILE to remove.${RESET}"
            exit 0
        fi

        mapfile -t keys < <(jq -r 'keys[]' "$JSON_FILE")
        selected=$(printf '%s\n' "${keys[@]}" | fzf --prompt="Select key to remove > ")

        if [ -z "$selected" ]; then
            echo "❌ No selection made. Aborting."
            exit 0
        fi

        echo -e "You selected: ${MAGENTA}${selected}${RESET}"
        read -p "Are you sure you want to remove it? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            echo "❌ Removal cancelled."
            exit 0
        fi

        jq "del(.\"$selected\")" "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
        echo -e "✅ Removed key '${MAGENTA}${selected}${RESET}' from ${JSON_FILE}"
        exit 0
        ;;
    -h|--help)
        print_help
        exit 0
        ;;
    -v|--version)
        echo -e "${CYAN}Version:${RESET} $VERSION"
        exit 0
        ;;
    *)
        # If no known argument passed, continue to main sync logic
        ;;
esac

# --- Default: Main sync routine (compare and optionally copy files) ---

declare -A TO_SYNC
# --- Ensure JSON file exists and contains data ---

if [ ! -f "$JSON_FILE" ] || [ "$(jq 'keys | length' "$JSON_FILE")" -eq 0 ]; then
    echo -e "${RED}Error: No mappings found. Use --add to initialize file mappings before syncing.${RESET}"
    exit 1
fi
MISMATCH_FOUND=0

echo " Checking file statuses..."
echo

# Loop through JSON entries and check if files/folders match
while IFS="|" read -r key filename destination type; do
    shortname=$(shorten_path "$filename")

    if [[ "$type" == "folder" ]]; then
        if [ ! -d "$filename" ]; then
            echo -e "${CYAN}${key}${RESET}: ${RED}❌ Folder missing locally${RESET}"
            TO_SYNC["$key"]=1
            MISMATCH_FOUND=1
            continue
        fi

        if [ ! -d "$destination" ]; then
            echo -e "${CYAN}${key}${RESET}: ${RED}❌ Folder missing on destination${RESET}"
            TO_SYNC["$key"]=1
            MISMATCH_FOUND=1
            continue
        fi

        mismatch_in_folder=0
        while IFS= read -r -d '' dest_file; do
            rel_path="${dest_file#$destination/}"
            src_file="$filename/$rel_path"

            if [ ! -f "$src_file" ] || ! cmp -s "$src_file" "$dest_file"; then
                mismatch_in_folder=1
                break
            fi
        done < <(find "$destination" -type f -print0)

        if [ "$mismatch_in_folder" -eq 0 ]; then
            echo -e "${CYAN}${key}${RESET} ↔ ${MAGENTA}${destination}${RESET}: ${GREEN}✅${RESET}"
            TO_SYNC["$key"]=0
        else
            echo -e "${CYAN}${key}${RESET} ↔ ${MAGENTA}${destination}${RESET}: ${RED}❌ Different or missing files${RESET}"
            TO_SYNC["$key"]=1
            MISMATCH_FOUND=1
        fi
    else
        if [ ! -e "$filename" ]; then
            echo -e "${CYAN}${shortname}${RESET}: ${RED}❌ Not found locally${RESET}"
            TO_SYNC["$key"]=1
            MISMATCH_FOUND=1
        elif [ ! -f "$filename" ]; then
            echo -e "${CYAN}${shortname}${RESET}: ${RED}❌ Not a regular file${RESET}"
            TO_SYNC["$key"]=1
            MISMATCH_FOUND=1
        elif [ -e "$destination" ] && cmp -s "$filename" "$destination"; then
            echo -e "${CYAN}${shortname}${RESET} ↔ ${MAGENTA}${destination}${RESET}: ${GREEN}✅${RESET}"
            TO_SYNC["$key"]=0
        else
            echo -e "${CYAN}${shortname}${RESET} ↔ ${MAGENTA}${destination}${RESET}: ${RED}❌ Different${RESET}"
            TO_SYNC["$key"]=1
            MISMATCH_FOUND=1
        fi
    fi
done < <(jq -r 'to_entries[] | "\(.key)|\(.value.filename)|\(.value.destination)|\(.value.type)"' "$JSON_FILE")

if [ "$MISMATCH_FOUND" -eq 0 ]; then
    echo
    echo "✅ All files/folders are up to date. No sync needed."
    exit 0
fi

echo
read -p "Do you want to sync all mismatched files/folders from system to local? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "❌ Sync cancelled."
    exit 0
fi

echo
echo "⏳ Syncing..."

# Copy from destination to local for each mismatched entry
while IFS="|" read -r key filename destination type; do
    if [[ "${TO_SYNC[$key]}" == "1" ]]; then
        if [[ "$type" == "folder" ]]; then
            if [ ! -d "$destination" ]; then
                echo -e "⚠️  ${MAGENTA}${destination}${RESET} not found. Skipping."
                continue
            fi
            mkdir -p "$filename"
            cp -r "$destination"/. "$filename"/
            echo -e "✔️  Synced folder ${MAGENTA}${destination}${RESET} → ${CYAN}${filename}${RESET}"
        else
            if [ -e "$destination" ]; then
                cp "$destination" "$filename"
                shortname=$(shorten_path "$filename")
                echo -e "✔️  Synced ${MAGENTA}${destination}${RESET} → ${CYAN}${shortname}${RESET}"
            else
                echo -e "⚠️  ${MAGENTA}${destination}${RESET} not found. Skipping."
            fi
        fi
    fi
done < <(jq -r 'to_entries[] | "\(.key)|\(.value.filename)|\(.value.destination)|\(.value.type)"' "$JSON_FILE")

echo
echo "✅ Sync complete."
