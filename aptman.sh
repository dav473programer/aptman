#!/bin/bash

# Where the theme will be saved
export DIALOGRC="/tmp/apt_manager_theme"

# I like yellow
cat <<EOF > "$DIALOGRC"
use_shadow = OFF
use_colors = ON
screen_color = (YELLOW,BLACK,OFF)
dialog_color = (YELLOW,BLACK,OFF)
title_color = (YELLOW,BLACK,OFF)
border_color = (YELLOW,BLACK,OFF)
border2_color = border_color
button_inactive_color = (BLACK,BLACK,OFF)
button_active_color = (BLACK,YELLOW,OFF)
button_label_active_color = (BLACK,YELLOW,OFF)
button_label_inactive_color = (YELLOW,BLACK,OFF)
button_key_inactive_color = (YELLOW,BLACK,OFF)
button_key_active_color = (BLACK,YELLOW,OFF)
tag_color = (YELLOW,BLACK,OFF)
tag_key_color = (YELLOW,BLACK,OFF)
item_color = (YELLOW,BLACK,OFF)
menubox_color = (YELLOW,BLACK,OFF)
menubox_border_color = (YELLOW,BLACK,OFF)
tag_selected_color = (BLACK,YELLOW,OFF)
tag_key_selected_color = (BLACK,YELLOW,OFF)
item_selected_color = (BLACK,YELLOW,OFF)
position_indicator_color = (BLACK,YELLOW,OFF)
inputbox_color = (YELLOW,BLACK,OFF)
inputbox_border_color = (YELLOW,BLACK,OFF)
uarrow_color = (YELLOW,BLACK,ON)
darrow_color = (YELLOW,BLACK,ON)
menubox_border2_color = menubox_border_color
EOF

# Cool function that deletes file.
trap 'rm -f "$DIALOGRC" /tmp/pkg_info /tmp/repo_error; clear' EXIT

# Check for dialog
if ! command -v dialog &> /dev/null; then
    echo "Error: 'dialog' is not installed. We will install it for you."
    sudo apt install dialog -y
    if [[ $? -eq 0 ]]; then
        echo "'dialog' has been installed succesfully, you are welcome."
    else
        echo "An error has occured, read the logs and see what happened \nMaybe you need to run 'sudo apt install dialog'? \nOr, first, update the repositories with 'sudo apt update' \nOr, check if you have network with 'ping 8.8.8.8'"
    fi
    exec "$0" "$@"
fi

# Handle direct file input (Double-click or 'Open with')
# Handle direct file input (Double-click or 'Open with')
if [[ -f "$1" && "$1" == *.deb ]]; then
    PKG_PATH="$1"
    
    # 1. Get basic info from the file
    dpkg-deb -I "$PKG_PATH" > /tmp/pkg_info
    INFO_TABLE=$(grep -E "^ (Package|Version|Section|Installed-Size|Maintainer):" /tmp/pkg_info | sed 's/^[[:space:]]*//' | column -t -s ':')
    DESC=$(sed -n '/ Description:/,$p' /tmp/pkg_info | head -n 6)

    # 2. Simulate the install to find dependencies
    # We grab the lines about "NEW packages will be installed" and the "Need to get" size.
    SIMULATION=$(audio sudo apt-get install -s "$PKG_PATH" 2>/dev/null)
    DEPS=$(echo "$SIMULATION" | grep -A 1 "The following NEW packages will be installed:" | tail -n 1 | sed 's/^[[:space:]]*//')
    DOWNLOAD_SIZE=$(echo "$SIMULATION" | grep "Need to get" | awk '{print $4 " " $5}')

    # Create the dependency warning string
    if [[ -n "$DEPS" ]]; then
        DEP_MSG="\n\nDEPENDENCIES TO BE INSTALLED:\n$DEPS\nDownload Size: $DOWNLOAD_SIZE"
    else
        DEP_MSG="\n\nDEPENDENCIES: None (All satisfied)"
    fi

    # 3. Show the enhanced dialog
    if dialog --title "Install Local Package: $(basename "$PKG_PATH")" \
              --yes-label "Install" --no-label "Cancel" \
              --yesno "LOCAL FILE DETECTED\n\n$INFO_TABLE\n\n$DESC$DEP_MSG" 22 78; then
        clear
        sudo apt install -y "$PKG_PATH"
        if [ $? -eq 0 ]; then
            # Get just the filename for a cleaner message
            FILENAME=$(basename "$PKG_PATH")
            dialog --title "Installation Successful" \
                   --msgbox "\n$FILENAME has been installed successfully!" 8 50
        else
            read -p "Installation failed. Press Enter to exit..."
        fi
    fi
    exit 0
fi

# The Menu
while true; do
    KERNEL=$(uname -r)
    OS_VER=$(cat /etc/debian_version)
    UPTIME=$(uptime -p | sed 's/up //')

    TITLE="APT Manager for Debian based systems. $OS_VER | Kernel: $KERNEL | Uptime: $UPTIME"
    ACTION=$(dialog --no-shadow --clear --backtitle "$TITLE"  --ok-label "Select" --cancel-label "Exit" \
        --title "Main Menu" \
        --menu "Select a task:" 18 60 7 \
        "SEARCH"       "Search and Install Packages" \
        "LIST"         "Manage Installed Packages and Uninstall." \
        "BATCH-REMOVE" "Search & Stage Multiple Uninstalls" \
        "ADD-REPO"     "Add New Software Repository" \
        "DELETE-REPOS" "View and Delete Repositories" \
        "UPDATE"       "Refresh Repositories Only" \
        "FULL-UPGRADE" "Update + Full System Upgrade" \
        --stdout)

    [[ $? != 0 || "$ACTION" == "EXIT" || -z "$ACTION" ]] && clear && exit

    case $ACTION in
        "SEARCH")
            QUERY=$(dialog --title "Search" --inputbox "Enter package name:" 8 45 --stdout)
            if [[ -n "$QUERY" ]]; then
                # Exact
                EXACT=$(apt-cache search "^${QUERY}$" | awk '{print $1 " [Exact_Match]"}')

                # Containing in the name
                STARTS=$(apt-cache search "^${QUERY}" | grep -v "^${QUERY}$" | head -n 10 | awk '{print $1 " [Starts_With]"}')

                # Containing inside the name + description
                OTHERS=$(apt-cache search "$QUERY" | grep -v "^${QUERY}" | head -n 20 | awk '{print $1 " [Keyword_Match]"}')

                # Combine them into the final list
                RESULTS=$(echo -e "$EXACT\n$STARTS\n$OTHERS" | grep -v '^$')

                
                if [[ -z "$RESULTS" ]]; then
                    dialog --msgbox "No packages found for '$QUERY'." 8 45
                else
                    PICK=$(dialog --title "Search Results" --menu "Select to Inspect:" 20 75 12 $RESULTS --stdout)
                    
                    if [[ -n "$PICK" ]]; then
                        # Tried to sort the apt show.
                        apt show "$PICK" 2>/dev/null | grep -E "^(Package|Version|Priority|Section|Installed-Size|Maintainer|Download-Size):" | \
                        sed 's/: / | /' | column -t -s '|' > /tmp/pkg_table
                        
                        # Put the description in a file, it could be to long for bash.
                        echo -e "\nDESCRIPTION:\n$(apt show "$PICK" 2>/dev/null | sed -n '/Description:/,$p' | head -n 10)" >> /tmp/pkg_table
                        
                        # MASSIVE Packages go here.
                        SIZE_RAW=$(grep "Installed-Size" /tmp/pkg_table | awk '{print $2}')
                        UNIT=$(grep "Installed-Size" /tmp/pkg_table | awk '{print $3}')
                        WARNING=""
                        [[ "$UNIT" == "GB" ]] && WARNING="\n\n WARNING: EXTREMELY LARGE PACKAGE!"
                        [[ "$UNIT" == "MB" && ${SIZE_RAW%.*} -gt 100 ]] && WARNING="\n\n WARNING: LARGE PACKAGE (>100MB)"

                        # Format the info
                        if dialog --title "Inspection: $PICK" \
                            --yes-label "Install" --no-label "Back" \
                            --yesno "$(cat /tmp/pkg_table)$WARNING" 22 78; then
                            clear
                            sudo apt install -y "$PICK"
                            read -p "Press Enter to return..."
                        fi
                    fi
                fi
            fi
            ;;

        "LIST")
            START=0
            PAGE_SIZE=50
            while true; do
                RAW_LIST=$(dpkg-query -W -f='${Package} ${Version}\n' | sed -n "$((START+1)),$((START+PAGE_SIZE))p")
                # That wanted to be a magnifying glass.
                MENU_OPTIONS=("SEARCH" "[ o- Search/Jump ]" "NEXT" "[ >> Next Page ]")
                [[ $START -gt 0 ]] && MENU_OPTIONS+=("PREV" "[ << Previous Page ]")
                
                while read -r pkg ver; do
                    [[ -n "$pkg" ]] && MENU_OPTIONS+=("$pkg" "$ver")
                done <<< "$RAW_LIST"

                PICK=$(dialog --title "Installed (Start: $((START+1)))" \
                    --menu "Click a package to Uninstall or use Navigation:" 22 75 14 \
                    "${MENU_OPTIONS[@]}" --stdout)

                case "$PICK" in
                    "NEXT") START=$((START + PAGE_SIZE)) ;;
                    "PREV") START=$((START - PAGE_SIZE)); [[ $START -lt 0 ]] && START=0 ;;
                    "SEARCH")
                        JUMP=$(dialog --inputbox "Jump to package name:" 8 45 --stdout)
                        if [[ -n "$JUMP" ]]; then
                            LINE=$(dpkg-query -W -f='${Package}\n' | grep -n -m 1 "$JUMP" | cut -d: -f1)
                            [[ -n "$LINE" ]] && START=$((LINE - 1)) || dialog --msgbox "Not found." 8 30
                        fi
                        ;;
                    "") break ;; 
                    *) 
                        if dialog --yesno "UNINSTALL $PICK?\n\nThis will purge the package." 10 50; then
                            clear
                            sudo apt purge -y "$PICK" && sudo apt autoremove -y
                            read -p "Press Enter..."
                        fi
                        ;;
                esac
            done
            ;;

        "BATCH-REMOVE")
            STAGING_LIST=()
            while true; do
                SEARCH_TERM=$(dialog --title "Batch Stage" \
                    --inputbox "Search for packages to add to the uninstall list:\n(Current staged: ${#STAGING_LIST[@]})" 10 60 --stdout)
                
                [[ $? != 0 || -z "$SEARCH_TERM" ]] && break

                # Search and Destroy
                MATCHES=$(dpkg-query -W -f='${Package} installed off\n' | grep -i "$SEARCH_TERM")

                if [[ -z "$MATCHES" ]]; then
                    dialog --msgbox "No installed packages found matching '$SEARCH_TERM'." 8 45
                else
                    PICKED=$(dialog --title "Select from matches: $SEARCH_TERM" \
                        --checklist "Space to select, Enter to stage:" 20 75 12 $MATCHES --stdout)

                    if [[ -n "$PICKED" ]]; then
                        for PKG in $PICKED; do
                            CLEAN_PKG=$(echo "$PKG" | tr -d '"')
                            [[ ! " ${STAGING_LIST[@]} " =~ " ${CLEAN_PKG} " ]] && STAGING_LIST+=("$CLEAN_PKG")
                        done
                    fi
                fi
                
                dialog --yesno "Add more packages from a different search term?" 8 55 || break
            done

            if [[ ${#STAGING_LIST[@]} -gt 0 ]]; then
                FINAL_LIST=$(printf "%s\n" "${STAGING_LIST[@]}")
                if dialog --title "CONFIRM BATCH REMOVAL" --yesno "Purge these packages?\n\n$FINAL_LIST" 20 60; then
                    clear
                    sudo apt purge -y "${STAGING_LIST[@]}" && sudo apt autoremove -y
                    read -p "Batch removal complete. Press Enter..."
                fi
            fi
            ;;

        "UPDATE")
            clear
            sudo apt update
            read -p "Repositories updated. Press Enter..."
            ;;

        "FULL-UPGRADE")
            if dialog --title "Confirm Full Upgrade" --yesno "Perform a FULL system upgrade?\n\nContinue?" 10 60; then
                clear
                sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y
                read -p "System is up to date. Press Enter to return..."
            fi
            ;;

        "ADD-REPO")
            # The name is pretty self explanatory, add those repos here.
            REPO=$(dialog --title "Add Repository" \
                --inputbox "Enter the PPA or Repo string:\n(e.g., ppa:glsn/steam or 'deb http://repo.url stable main')" 10 60 --stdout)

            if [[ -n "$REPO" ]]; then
                clear
                echo "Attempting to add: $REPO..."
                
                # Errors will always be a part of programing, so, lets store them carefully.
                sudo add-apt-repository -y "$REPO" 2> /tmp/repo_error
                
                # Did it succed?
                if [[ $? -eq 0 ]]; then
                    echo "Success! Updating lists..."
                    sudo apt update
                    dialog --msgbox "Repository added successfully!" 8 45
                else
                    # I knew we neded to store them carefully.
                    ERROR_MSG=$(cat /tmp/repo_error)
                    dialog --title "REPOSITORY FAULT" \
                        --msgbox "Failed to add repository.\n\nERROR:\n$ERROR_MSG" 15 65
                fi
            fi
            ;;
        "DELETE-REPOS")
            # I know there is another file available /etc/apt/sources.list, i am just lazy to add the implementation to also read that.
            REPO_FILES=($(ls /etc/apt/sources.list.d/))
            
            if [ ${#REPO_FILES[@]} -eq 0 ]; then
                dialog --msgbox "No third-party repositories found in /etc/apt/sources.list.d/" 8 50
                continue
            fi

            # Let's tidy up the files here
            MENU_LIST=()
            for file in "${REPO_FILES[@]}"; do
                MENU_LIST+=("$file" "Custom Repository")
            done

            # Show the menu, nothing to complex
            FILE_TO_DELETE=$(dialog --title "Delete Repository" \
                --menu "Select a file to PERMANENTLY remove:" 20 65 12 \
                "${MENU_LIST[@]}" --stdout)

            if [[ -n "$FILE_TO_DELETE" ]]; then
                # Lets warn the user, a "cat" (the command) might have stepped on his keyboard, you never know.
                CONTENT=$(cat "/etc/apt/sources.list.d/$FILE_TO_DELETE" | head -n 5)
                if dialog --title "ONFIRM DELETION" \
                    --yesno "Are you sure you want to delete $FILE_TO_DELETE?\n\nFile Content:\n$CONTENT..." 15 65; then
                    
                    clear
                    echo "Removing $FILE_TO_DELETE..."
                    sudo rm "/etc/apt/sources.list.d/$FILE_TO_DELETE"  
                    echo "Updating repository list..."
                    sudo apt update
                    dialog --msgbox "Repository removed successfully." 8 45
                fi
            fi
            ;;

    esac
done

