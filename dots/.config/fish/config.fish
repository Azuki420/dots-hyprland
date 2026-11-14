# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    #set fish_greeting

    # Kuromi
    function fish_greeting
        if test $COLUMNS -ge 57
            kuromi
        end
    end

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    
    # Colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons=auto'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end
    alias cd.. 'cd ..'
    alias .. 'cd ..'
    alias ... 'cd ../..'
    alias update 'sudo pacman -Syu'
    alias update-yay 'yay -Syu'
    alias upd 'update & update-yay'

    function mount-efi
        sudo mount --mkdir /dev/nvme0n1p1 /mnt/efi
    end

    function umount-efi
        if sudo umount /mnt/efi
            sudo rmdir /mnt/efi
        else
            echo "Unmount failed (drive might be busy). Directory was not removed."
        end
    end

    function tower-remount
    set shares $argv
    test (count $shares) -eq 0; and set shares data appdata ssd
    for s in $shares
        sudo systemctl stop mnt-tower-$s.automount mnt-tower-$s.mount
        sudo systemctl start mnt-tower-$s.automount
        ls /mnt/tower/$s >/dev/null;     and echo "$s mounted"
        end
    end

    alias kuromi 'cat $HOME/.config/fish/ascii/kuromi'

end
