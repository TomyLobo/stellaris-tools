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
        /^\t{0}planet=\{/,/^\t{0}\}/ {
            /^\t{1}[0-9]+=\{/,/^\t{1}\}/ {
                s/^\t{2}name="(.*)"/Planet \1:/p
                /^\t{2}tiles=\{/,/^\t{2}\}/ {
                    /^\t{3}[0-9]+=\{/,/^\t{3}\}/ {
                        s/^\t{4}deposit="(.*)"/  deposit: \1/p
                        #s/^\t{4}deposit="d_sr_yridium_11_deposit"/  deposit: Yridium/p
                        #s/^\t{4}deposit="d_sr_sodium_12_deposit"/  deposit: Sodium/p
                    }
                }
            }
        }
    ' |
    tr '\n' '\r' |
    sed '
        s/\r  deposit: / /g
        s/\r/\n/g
    ' |
    grep -F ': ' |
    less
