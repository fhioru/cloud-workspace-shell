#!/usr/bin/env bash
# Print tmux color palette.
# Idea from http://superuser.com/questions/285381/how-does-the-tmux-color-palette-work

# color_char='\u2588'
# color_area="${color_char}${color_char}${color_char}${color_char}${color_char}${color_char}${color_char}${color_char}"

# for code in $(seq 0 255)
# do
#     for attr in 0 1
#     do
#         printf "%s:%03s %b${color_area}%b\n" "${attr}" "${code}" "\e[${attr};38;05;${code}m" "\e[m"
#     done
# done | column -c 400


for fgbg in 38 48; do #Foreground/Background/transparent
    for weight in 0 1; do
        for color in {0..255} ; do #Colors
            # Display the color
            echo -en "\e[${weight};${fgbg};5;${color}m ${color}\t\e[0m"
            echo "\e[${weight};${fgbg};5;${color}m\e[0m"
        done
        echo #New line
    done
done | column -x