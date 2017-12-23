#!/bin/bash

set -e

save_game_basedir="$USERPROFILE/Documents/Paradox Interactive/Stellaris/save games"
save_game_subdir="$save_game_basedir"/borgcollective_210724061
save_files=("$save_game_subdir"/*.sav)

latest_save_file="${save_files[0]}"
for save_file in "${save_files[@]}"; do
    if [[ "$save_file" -nt "$latest_save_file" ]]; then

        latest_save_file="$save_file"
    fi
done

#ls -talh "$save_game_subdir"
#declare -p latest_save_file
#exit

echo "Reading from $latest_save_file..."

unzip -p "$latest_save_file" gamestate |
    sed -nr '
        /^\t{0}country=\{/,/^\t{0}\}/ {
            /^\t{1}0=\{/,/^\t{1}\}/ {
                /^\t{2}tech_status=\{/,/^\t{2}\}/ {
                    s/^\t{3}technology="(.*)"/\1/p
                }
            }
        }
    ' > known_techs.txt
