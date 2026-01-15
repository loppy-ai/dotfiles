local wezterm = require("wezterm")
local act = wezterm.action

-- Show which key table is active in the status area
wezterm.on("update-right-status", function(window, pane)
    local name = window:active_key_table()
    if name then
        name = "TABLE: " .. name
    end
    window:set_right_status(name or "")
end)

return {
    keys = {
        {
            -- workspaceの切り替え
            key = "w",
            mods = "LEADER",
            action = act.ShowLauncherArgs({ flags = "WORKSPACES", title = "Select workspace" }),
        },
        {
            --workspaceの名前変更
            key = "e",
            mods = "LEADER",
            action = act.PromptInputLine({
                description = "(wezterm) Set workspace title:",
                action = wezterm.action_callback(function(win, pane, line)
                    if line then
                        wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
                    end
                end),
            }),
        },
        {
            key = "W",
            mods = "LEADER|SHIFT",
            action = act.PromptInputLine({
                description = "(wezterm) Create new workspace:",
                action = wezterm.action_callback(function(window, pane, line)
                    if line then
                        window:perform_action(
                            act.SwitchToWorkspace({
                                name = line,
                            }),
                            pane
                        )
                    end
                end),
            }),
        },
        -- コマンドパレット
        { key = "p", mods = "SHIFT|CTRL", action = act.ActivateCommandPalette },
        -- Tab移動
        { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
        { key = "Tab", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(-1) },
        -- Tab入れ替え
        { key = "r", mods = "SHIFT|CTRL", action = act({ MoveTabRelative = 1 }) },
        { key = "e", mods = "SHIFT|CTRL", action = act({ MoveTabRelative = -1 }) },
        -- Tab新規作成
        { key = "t", mods = "SHIFT|CTRL", action = act({ SpawnTab = "CurrentPaneDomain" }) },
        -- Tabを閉じる
        { key = "w", mods = "SHIFT|CTRL", action = act({ CloseCurrentTab = { confirm = true } }) },

        -- 画面フルスクリーン切り替え
        { key = "Enter", mods = "ALT", action = act.ToggleFullScreen },

        -- Pane作成
        { key = "r", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
        { key = "d", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
        -- Paneを閉じる
        { key = "x", mods = "LEADER", action = act({ CloseCurrentPane = { confirm = true } }) },
        -- Pane移動
        { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
        { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
        { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
        { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
        -- Pane選択
        { key = "f", mods = "LEADER", action = act.PaneSelect },
        -- 選択中のPaneのみ表示
        { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
        -- コピーモード
        { key = "c", mods = "LEADER", action = act.ActivateCopyMode },
        { key = "v", mods = "LEADER", action = act.PasteFrom("Clipboard") },
        -- フォントサイズ切替
        { key = ";", mods = "CTRL", action = act.IncreaseFontSize },
        { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
        -- フォントサイズのリセット
        { key = "0", mods = "CTRL", action = act.ResetFontSize },
        -- 設定再読み込み
        { key = "r", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
        -- キーテーブル用
        { key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
    },
    -- キーテーブル
    key_tables = {
        -- Paneサイズ調整 leader + s
        resize_pane = {
            { key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
            { key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
            { key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
            { key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
            { key = "Enter", action = "PopKeyTable" },
        },
        -- copyモード leader + c
        copy_mode = {
            -- 移動
            { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
            { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
            { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
            { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
            -- 最初と最後に移動
            { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
            { key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
            { key = "\\", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") }, -- ここだけ変更
            -- 選択範囲の端に移動
            { key = "o", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEnd") },
            -- 単語ごと移動
            { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
            { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
            { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
            -- ジャンプ機能 t f
            { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
            { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
            { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
            { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
            -- 一番下へ
            { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
            -- 一番上へ
            { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
            -- viewport
            { key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
            { key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
            { key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
            -- スクロール
            { key = "b", mods = "CTRL", action = act.CopyMode("PageUp") },
            { key = "f", mods = "CTRL", action = act.CopyMode("PageDown") },
            -- 範囲選択モード
            { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
            { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
            { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
            -- コピー
            { key = "y", mods = "NONE", action = act.CopyTo("ClipboardAndPrimarySelection") },
            -- コピーモードを終了
            { key = "Enter", mods = "NONE", action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }) },
            { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
            { key = "c", mods = "CTRL", action = act.CopyMode("Close") },
            { key = "q", mods = "NONE", action = act.CopyMode("Close") },
        },
    },
}