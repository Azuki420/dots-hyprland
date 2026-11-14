hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

hl.bind("ALT + SUPER_L", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Toggle right sidebar", ignore_mods = false, transparent = true })
hl.bind("SUPER + Z", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Toggle right sidebar", ignore_mods = false, transparent = true })

hl.unbind("SUPER + Space")
hl.bind("SUPER + Space", hl.dsp.global("quickshell:appDrawerToggle"), { description = "Shell: Toggle app drawer" })

hl.bind("ALT + Tab", hl.dsp.focus({ monitor = "+1" }), { description = "Window: Focus other monitor" })

hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.exec_cmd("obsidian"), { description = "App: Obsidian" })

hl.bind("CTRL+SUPER+ALT+Escape", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dispatch(hl.dsp.exit())'"), { description = "Session: Shut down Hyprland" })

hl.bind("Scroll_Lock", hl.dsp.global("discord:discord-toggle-mute"), { description = "Discord: Toggle mute" })
hl.bind("Pause", hl.dsp.global("discord:discord-toggle-deafen"), { description = "Discord: Toggle deafen" })
hl.bind("KP_Add", hl.dsp.global("discord:discord-toggle-go-live-streaming"), { description = "Discord: Toggle screen share" })

hl.unbind("SUPER + S")
hl.bind("SUPER + S", hl.dsp.workspace.swap_monitors({ monitor1 = "DP-1", monitor2 = "DP-2" }), { description = "Workspace: Swap monitors" })

-- print screen to file
local grimhyprctl = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""

hl.bind("SUPER + Print", hl.dsp.exec_cmd(
    "mkdir -p $(xdg-user-dir PICTURES)/Screenshots && " ..
    grimhyprctl .. " $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
), { locked = true, non_consuming = true, description = "Utilities: Screenshot >> file" })

-- move all tiles from current workspace to other workspace with number
local mainMod = "SUPER"

local function move_all_to(dest)
return function()
local cur = hl.get_active_workspace().id
local targets = {}
for _, w in pairs(hl.get_windows()) do
    if w.workspace.id == cur then
        table.insert(targets, w)
        end
        end
        for _, w in ipairs(targets) do
            hl.dispatch(hl.dsp.window.move({ workspace = dest, window = w }))
            end
            end
            end

            for i = 1, 10 do
                local key = i % 10  -- 10 wraps to key 0
                hl.bind(mainMod .. " + SHIFT + " .. key, move_all_to(i))
                end

hl.unbind("SUPER + mouse_up")
hl.unbind("SUPER + mouse_down")
hl.unbind("CTRL + SUPER + mouse_up")
hl.unbind("CTRL + SUPER + mouse_down")
hl.bind("SUPER + mouse_up",          hl.dsp.focus({ workspace = "r-1" }))
hl.bind("SUPER + mouse_down",        hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + SUPER + mouse_up",   hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL + SUPER + mouse_down", hl.dsp.focus({ workspace = "+1" }))
