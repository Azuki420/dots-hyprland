hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide left"})

-- workspaces
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 7,
    bezier = "menu_decel",
    style = "slidevert"
})

hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
hl.workspace_rule({ workspace = "3", monitor = "DP-1" })
hl.workspace_rule({ workspace = "4", monitor = "DP-1" })
hl.workspace_rule({ workspace = "5", monitor = "DP-1" })

hl.workspace_rule({ workspace = "6", monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "7", monitor = "DP-2" })
hl.workspace_rule({ workspace = "8", monitor = "DP-2" })
hl.workspace_rule({ workspace = "9", monitor = "DP-2" })
hl.workspace_rule({ workspace = "10", monitor = "DP-2" })

hl.window_rule({
    match = { class = "discord" },
    workspace = "6 silent",
})

hl.window_rule({
    name = "share-picker-focus",
    match = {
        class = "hyprland-share-picker"
    },
    float = true,
    no_focus = false,
    stay_focused = false,
    size = "700 400",
    center = true
})
