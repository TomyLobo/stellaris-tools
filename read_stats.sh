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
    grep -nE '^([a-z].*\{|\})' |
    tr '\n' '\r' |
    sed -r '
        s/(\{)\r/\1 /g
        s/\r/\n/g
    ' |
    sed -r '
        s/([0-9]+):([a-z0-9_:]+)=\{ ([0-9]+):\}/\2 \1 \3/
    ' |
    {
        i=0
        lines=
        last_section=
        last_section_size=0
        while read -r section start end; do
            section_size="$((end - start + 1))"
            if [ "$section" = "$last_section" ]; then
                (( --i )) # TODO dont err on 0th line
                section_size="$((section_size + last_section_size))"
            fi
            line="$(printf '%s: %s' "$section" "$section_size")"
            lines["$i"]="$line"

            (( ++i ))
            last_section="$section"
            last_section_size="$section_size"
        done

        for line in "${lines[@]}"; do
            echo "$line"
        done
    } |
    sort -n -k2,2 |
    less
