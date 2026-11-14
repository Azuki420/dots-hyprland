hl.on("hyprland.start", function()
--hl.exec_cmd("firefox & spotify-launcher & discord-x11")
hl.exec_cmd("~/.local/bin/backup-home.sh &")
hl.exec_cmd("~/.config/hypr/custom/scripts/hypr-shutdown-daemon &")

-- Session restore commands
--hl.exec_cmd("sleep 2 && ~/.config/hypr/scripts/hypr-session-restore restore")
hl.exec_cmd("~/.config/hypr/custom/scripts/hypr-session-restore restore")
hl.exec_cmd("~/.config/hypr/custom/scripts/hypr-session-restore daemon")
end)
