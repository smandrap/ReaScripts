-- @description Search Tracks
-- @author smandrap
-- @version 1.9.8.1
-- @donation https://paypal.me/smandrap
-- @changelog
--  fixies
-- @provides
--   smandrap_Search Tracks/modules/*.lua
-- @about
--  Cubase style track search with routing capabilities

--------------------------------------
------- USER AREA --------------------
--------------------------------------

--[[
PRE-POST ACTIONS:

Insert actions command ID in the curly brackets,
surrounded by "" and comma separated.

BACKUP THESE ACTIONS YOURSELF!!!! Updates will (at the moment) wipe them out

Example:

PRE_ACTIONS = {
  "40183",
  "_RS144139a961beeafd979a8734b53d703449faccf3"
}

--]]


PRE_ACTIONS = {

}

POST_ACTIONS = {

}

------------------------------------------
-------  END USER AREA --------------------
-------------------------------------------

local r = reaper

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.9.3'


local script_name = "Search Tracks"

if not imgui.GetVersion then
    local ok = r.MB('Install now?', 'Reaimgui Missing', 1)
    if ok == 1 then r.ReaPack_BrowsePackages("Reaimgui API") end
    return
end

local js_api = false
if r.APIExists('JS_ReaScriptAPI_Version') then js_api = true end
local routing_cursor = js_api and r.JS_Mouse_LoadCursor(186) -- r.routing cursor
local normal_cursor = js_api and r.JS_Mouse_LoadCursor(0)

package.path = package.path ..
    ';' ..
    debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] ..
    "?.lua;" -- GET DIRECTORY FOR REQUIRE
local fzy = require("smandrap_Search Tracks.modules.fzy")
-- local lib = require("smandrap_Search Tracks.modules.lib")
local lib = loadfile("smandrap_Search Tracks/modules/lib.lua")

local extstate_section = 'smandrap_SearchTracks'

----------------------
-- DEFAULT SETTINGS
----------------------


local settings = {
    version = '1.9.8.1',
    uncollapse_selection = false,
    show_in_tcp = true,
    show_in_mcp = false,
    unhide_parents = true,
    close_on_action = true,
    show_track_number = false,
    show_color_box = true,
    hide_titlebar = false,
    use_routing_cursor = true,
    dim_hidden_tracks = true,
    do_pre_actions = true,
    do_post_actions = true,
    uncollapse_if_folder = true,
    nav_mode = false,
    font_size = 13
}

----------------------
-- APP VARS
----------------------

local is_macOS
local proj_change_cnt = 0

local tracks = {}
local filtered_tracks = {}

local selected_track
local dragged_track
local dest_track, info

local search_string = ''

----------------------
-- GUI VARS
----------------------

local FLT_MIN, FLT_MAX = imgui.NumericLimits_Float()

local ctx = imgui.CreateContext(script_name, imgui.ConfigFlags_NavEnableKeyboard)
local visible
local app_open
local first_frame = true

local open_settings = false

local new_font_size
local tooltip_font_size
local colorbox_size

local font
local tooltip_font



local default_wflags = imgui.WindowFlags_NoCollapse
local notitle_wflags = default_wflags | imgui.WindowFlags_NoTitleBar

local node_flags_base = imgui.TreeNodeFlags_OpenOnArrow
    | imgui.TreeNodeFlags_DefaultOpen
    | imgui.TreeNodeFlags_SpanAvailWidth

local node_flags_leaf = node_flags_base
    | imgui.TreeNodeFlags_Leaf
    | imgui.TreeNodeFlags_NoTreePushOnOpen

local colorbox_flags = imgui.ColorEditFlags_NoAlpha
    | imgui.ColorEditFlags_NoTooltip

local was_dragging = false

local help_text = script_name .. ' v' .. settings.version .. '\n\n' ..
    [[- Cmd/Ctrl+F : Focus search field
- Arrows/Tab : Navigate
- Esc: Exit

- Enter/Double Click on name : Select in project
- Cmd/Ctrl + Enter/Double Click on name : Show all children if target is folder
- Shift + Enter/Double Click : Add to selection
- Cmd/Ctrl + 1..9 : Select search result 1..9
- Shift + Cmd/Ctrl + 1..9 : Add to sel search result 1..9

- Drag/Drop on TCP/MCP : Create send
- Drag/Drop on FX : Create sidechain send (ch 3-4)
- Cmd/Ctrl while dragging : Create receive
- Shift while dragging : send/receive to/from all selected tracks
]]

local help_text_actions = [[You can define actions to execute before and/or after the track selection happens.
These actions are defined inside the script, search for "USER AREA".
]]
----------------------
-- HELPERS
----------------------

local function table_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

local function table_delete(t)
    for i = 0, #t do t[i] = nil end
end


----------------------
-- APP FUNCS
----------------------

local function IsProjectChanged()
    local buf = r.GetProjectStateChangeCount(0)

    if proj_change_cnt == buf then return false end

    proj_change_cnt = buf
    return true
end

local function GetTrackInfo(track)
    local track_info = {}

    track_info.track = track
    track_info.number = math.floor(r.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER'))
    track_info.name = select(2, r.GetTrackName(track))
    track_info.color = imgui.ColorConvertNative(r.GetTrackColor(track))
    track_info.showtcp = r.GetMediaTrackInfo_Value(track, 'B_SHOWINTCP')
    track_info.showmcp = r.GetMediaTrackInfo_Value(track, 'B_SHOWINMIXER')
    track_info.folderdepth = r.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')

    return track_info
end

local function GetTracks()
    local t = {}

    for i = 1, r.CountTracks(0) do
        local track = r.GetTrack(0, i - 1)

        t[i] = GetTrackInfo(track)
    end

    return t
end

local function IncreaseTrackChannelCnt(track)
    local tr_ch_cnt = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')

    if tr_ch_cnt > 4 then return end
    r.SetMediaTrackInfo_Value(track, 'I_NCHAN', 4)
end

local function UpdateTrackList()
    if search_string == '' then
        filtered_tracks = table_copy(tracks)
        return
    end

    table_delete(filtered_tracks)
    local tracknames = {}

    for i = 1, #tracks do
        if tracks[i] == nil then goto continue end
        tracknames[i] = string.lower(tracks[i].name)
        ::continue::
    end

    local lowercase_search_string = string.lower(search_string)
    -- Word matching
    local words = {}
    for word in lowercase_search_string:gmatch("%S+") do table.insert(words, word) end

    local word_cnt = #words

    for i = 1, #tracknames do
        local match_cnt = 0
        for j = 1, word_cnt do
            if string.match(tracknames[i], words[j]) then
                match_cnt = match_cnt + 1
            end
        end
        if match_cnt == word_cnt then table.insert(filtered_tracks, tracks[i]) end
    end

    if #filtered_tracks > 0 then return end
    -- If word matching fails, proceed to fuzzy search

    local searchresult = fzy.filter(lowercase_search_string, tracknames)
    local targetscore = 0.00001 + 1 / string.len(search_string) -- longer the search string, less precision required

    for i = 1, #searchresult do
        local score = searchresult[i][3]
        if searchresult[i][2][1] == 1 then score = score * 2 end
        if score > targetscore then
            table.insert(filtered_tracks, tracks[searchresult[i][1]])
        end
    end
end

local function UpdateAllData()
    tracks = GetTracks()
    UpdateTrackList()
end

local function DoActions(t)
    for i = 1, #t do
        r.Main_OnCommand(r.NamedCommandLookup(tostring(t[i])), 0)
    end
end

local function ShowTrack(track)
    if settings.show_in_tcp then r.SetMediaTrackInfo_Value(track, 'B_SHOWINTCP', 1) end
    if settings.show_in_mcp then r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1) end
end

local function UncollapseTrackParents(track)
    local depth = r.GetTrackDepth(track.track)
    local track_buf = track.track

    for i = depth, 1, -1 do
        local parent = r.GetParentTrack(track_buf)

        if parent then track_buf = parent end
        r.SetMediaTrackInfo_Value(track_buf, 'I_FOLDERCOMPACT', 0)
    end
end

local function ShowTrackParents(track)
    local buf = track.track

    for j = r.GetTrackDepth(buf), 0, -1 do
        buf = r.GetParentTrack(buf)
        if buf then ShowTrack(buf) end
    end
end

local function ShowTrackChildren(track)
    for i = track.number, #tracks - 1 do
        local buf = r.GetTrack(0, i)
        if r.GetTrackDepth(buf) < track.folderdepth then break end

        ShowTrack(buf)
    end
end

local function DoActionOnTrack(track, add_to_selection, unhide_children)
    if not track then return end
    if unhide_children == nil then unhide_children = false end

    r.Undo_BeginBlock()

    if PRE_ACTIONS and settings.do_pre_actions == true then DoActions(PRE_ACTIONS) end

    ShowTrack(track.track)

    if settings.uncollapse_if_folder and track.folderdepth > 0 then
        r.SetMediaTrackInfo_Value(track.track, 'I_FOLDERCOMPACT', 0)
    end
    if settings.uncollapse_selection then UncollapseTrackParents(track) end
    if settings.unhide_parents then ShowTrackParents(track) end
    if unhide_children and track.folderdepth > 0 then ShowTrackChildren(track) end


    if add_to_selection then
        r.SetTrackSelected(track.track, true)
    else
        r.SetOnlyTrackSelected(track.track)
    end

    r.Main_OnCommand(40913, 0) -- Vertical scroll to track
    r.SetMixerScroll(track.track)

    if POST_ACTIONS and settings.do_post_actions == true then DoActions(POST_ACTIONS) end

    r.Undo_EndBlock("Change Track Selection", -1)
    r.TrackList_AdjustWindows(true)

    if settings.close_on_action then app_open = false end
end

local function DoAlfredStyleCmd()
    if not imgui.IsKeyDown(ctx, imgui.Mod_Ctrl) then return end

    local trackidx = -1

    for i = 1, 9 do
        local key = imgui["Key_" .. i]
        local keypadKey = imgui["Key_Keypad" .. i]
        if imgui.IsKeyPressed(ctx, key) or imgui.IsKeyPressed(ctx, keypadKey) then
            trackidx = i
            break
        end
    end

    if trackidx > 0 then DoActionOnTrack(filtered_tracks[trackidx], imgui.IsKeyDown(ctx, imgui.Mod_Shift)) end
end

local function DoNavModeAction(track)
    if track.showtcp == 0 and track.showmcp == 0 then return end

    r.SetOnlyTrackSelected(track.track)

    if track.showtcp == 1 then
        r.Main_OnCommand(40913, 0) -- Vertical scroll to track
    end
    if track.showmcp == 1 then
        r.SetMixerScroll(track.track)
    end
end

local function ReadSettingsFromExtState()
    if not r.HasExtState(extstate_section, 'version') then return end

    for k, v in pairs(settings) do
        if r.HasExtState(extstate_section, k) then
            local extstate = r.GetExtState(extstate_section, k)
            if tonumber(extstate) then
                settings[k] = tonumber(extstate)
            else
                settings[k] = extstate == "true" and true or false
            end
        end
    end
end

local function WriteSettingsToExtState()
    for k, v in pairs(settings) do
        r.SetExtState(extstate_section, k, tostring(v), true)
    end
end

----------------------
-- GUI FUNCS
----------------------

local function IsSearchShortcutPressed()
    return imgui.IsKeyDown(ctx, imgui.Mod_Ctrl) and
        imgui.IsKeyPressed(ctx, imgui.Key_F)
end


local function IsItemDoubleClicked()
    return imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0)
end


local function IsEnterPressedOnItem()
    local enter = imgui.IsKeyPressed(ctx, imgui.Key_Enter) or
        imgui.IsKeyPressed(ctx, imgui.Key_KeypadEnter)
    return imgui.IsItemFocused(ctx) and enter
end


local function DrawSettingsMenu()
    if imgui.BeginPopup(ctx, 'settings', imgui.SelectableFlags_DontClosePopups) then
        imgui.MenuItem(ctx, 'Show:', nil, nil, false)
        _, settings.show_track_number = imgui.MenuItem(ctx, 'Track Number', nil, settings.show_track_number)
        _, settings.show_color_box = imgui.MenuItem(ctx, 'Track Color', nil, settings.show_color_box)

        imgui.Separator(ctx)
        imgui.MenuItem(ctx, 'Unhide in:', nil, nil, false)
        _, settings.show_in_tcp = imgui.MenuItem(ctx, 'TCP', nil, settings.show_in_tcp)
        _, settings.show_in_mcp = imgui.MenuItem(ctx, 'MCP', nil, settings.show_in_mcp)
        _, settings.unhide_parents = imgui.MenuItem(ctx, 'Unhide Parents', nil, settings.unhide_parents)

        imgui.Separator(ctx)

        _, settings.uncollapse_if_folder = imgui.MenuItem(ctx, 'Uncollapse if Folder', nil,
            settings.uncollapse_if_folder)
        _, settings.uncollapse_selection = imgui.MenuItem(ctx, 'Uncollapse Parents', nil, settings
            .uncollapse_selection)

        imgui.Separator(ctx)

        imgui.MenuItem(ctx, 'Run Actions (?):', nil, nil, false)
        if imgui.IsItemHovered(ctx, imgui.HoveredFlags_AllowWhenDisabled) then
            if imgui.BeginTooltip(ctx) then
                imgui.PushFont(ctx, tooltip_font)
                imgui.Text(ctx, help_text_actions)
                imgui.PopFont(ctx)
                imgui.EndTooltip(ctx)
            end
        end
        _, settings.do_pre_actions = imgui.MenuItem(ctx, 'Pre-Actions (' .. #PRE_ACTIONS .. ')', nil,
            settings.do_pre_actions)
        _, settings.do_post_actions = imgui.MenuItem(ctx, 'Post-Actions (' .. #POST_ACTIONS .. ')', nil,
            settings.do_post_actions)


        imgui.Separator(ctx)
        _, settings.nav_mode = imgui.MenuItem(ctx, 'Nav Mode', nil, settings.nav_mode)
        _, settings.close_on_action = imgui.MenuItem(ctx, 'Quit after Selection', nil, settings.close_on_action)

        imgui.Separator(ctx)

        if imgui.BeginMenu(ctx, 'GUI') then
            _, settings.hide_titlebar = imgui.MenuItem(ctx, 'Hide Titlebar', nil, settings.hide_titlebar)
            _, settings.dim_hidden_tracks = imgui.MenuItem(ctx, 'Dim Hidden Track Names', nil,
                settings.dim_hidden_tracks)
            _, settings.use_routing_cursor = imgui.MenuItem(ctx, 'Use Routing Cursor', nil,
                settings.use_routing_cursor,
                js_api)
            if not js_api then
                if imgui.IsItemHovered(ctx, imgui.HoveredFlags_AllowWhenDisabled) then
                    if imgui.IsMouseClicked(ctx, 0) then
                        r.ReaPack_BrowsePackages('JS_ReascriptAPI')
                    end

                    if imgui.BeginTooltip(ctx) then
                        imgui.PushFont(ctx, tooltip_font)
                        imgui.Text(ctx, 'Requires JS_Api.\n(Click to install)')
                        imgui.PopFont(ctx)
                        imgui.EndTooltip(ctx)
                    end
                end
            end
            imgui.Separator(ctx)

            imgui.AlignTextToFramePadding(ctx)
            imgui.Text(ctx, 'Font Size:')
            imgui.SameLine(ctx)
            imgui.SetNextItemWidth(ctx, 50)

            _, new_font_size = imgui.InputInt(ctx, "##FontSize", new_font_size, 0)
            new_font_size = new_font_size < 10 and 10 or new_font_size > 20 and 20 or new_font_size
            imgui.EndMenu(ctx)
        end

        -- HELP here
        if imgui.BeginMenu(ctx, 'Help') then
            imgui.MenuItem(ctx, help_text, nil, nil, false)
            imgui.EndMenu(ctx)
        end

        imgui.EndPopup(ctx)
    end
end


local function DrawSearchFilter()
    local changed = false

    if IsSearchShortcutPressed() or first_frame then imgui.SetKeyboardFocusHere(ctx) end

    imgui.SetNextItemWidth(ctx, -FLT_MIN)

    imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, 2)
    changed, search_string =
        imgui.InputTextWithHint(ctx, '##searchfilter', settings.hide_titlebar and 'Search Tracks' or '',
            search_string)
    imgui.PopStyleVar(ctx)

    -- Tooltip
    if imgui.IsItemHovered(ctx) and not open_settings then
        imgui.PushFont(ctx, tooltip_font)
        if imgui.BeginTooltip(ctx) then
            imgui.Text(ctx, 'Right-Click: options')
            imgui.EndTooltip(ctx)
            imgui.PopFont(ctx)
        end
    end

    -- If search filter is focused and enter is pressed, do thing to first search result
    if imgui.IsItemFocused(ctx) and imgui.IsKeyPressed(ctx, imgui.Key_Enter) then
        DoActionOnTrack(filtered_tracks[1], imgui.IsKeyDown(ctx, imgui.Mod_Shift),
            imgui.IsKeyDown(ctx, imgui.Mod_Ctrl))
    end


    if imgui.IsItemClicked(ctx, 1) then imgui.OpenPopup(ctx, 'settings') end
    DrawSettingsMenu()

    return changed
end



local function SetupDragDrop(track)
    if imgui.BeginDragDropSource(ctx) then
        imgui.SetDragDropPayload(ctx, 'dragdrop', 'track', 0)
        if js_api and settings.use_routing_cursor and routing_cursor then
            r.JS_Mouse_SetCursor(routing_cursor)
        end

        was_dragging = true
        dragged_track = track.track
        dest_track, info = r.GetThingFromPoint(r.GetMousePosition())

        dest_track = (info:match('tcp') or info:match('mcp') or info:match('fx_')) and dest_track or nil
        local dest_track_name = dest_track and select(2, r.GetTrackName(dest_track)) or '...'
        if imgui.IsKeyDown(ctx, imgui.Mod_Shift) then dest_track_name = "ALL SELECTED" end

        if imgui.BeginTooltip(ctx) then
            if info:match('fx_') then
                imgui.Text(ctx,
                    'SEND (Sidechain 3-4):\n\n[ ' .. track.name .. ' ]\n\nTO:\n\n[ ' .. dest_track_name ..
                    ' ]')
            else
                if imgui.IsKeyDown(ctx, imgui.Mod_Ctrl) then
                    imgui.Text(ctx, 'SEND:\n\n[ ' .. dest_track_name .. ' ]\n\nTO:\n\n[ ' .. track.name .. ' ]') -- RECEIVE
                else
                    imgui.Text(ctx, 'SEND:\n\n[ ' .. track.name .. ' ]\n\nTO:\n\n[ ' .. dest_track_name .. ' ]') -- SEND
                end
            end
        end
        imgui.EndTooltip(ctx)

        imgui.EndDragDropSource(ctx)
    end
    -- End of DragnDrop so create send
    if was_dragging and not imgui.IsMouseDown(ctx, 0) then
        if js_api and settings.use_routing_cursor then
            ---@diagnostic disable-next-line: param-type-mismatch
            r.JS_Mouse_SetCursor(normal_cursor)
        end


        if dest_track and dragged_track then
            r.Undo_BeginBlock()

            -- RECEIVES
            if imgui.IsKeyDown(ctx, imgui.Mod_Ctrl) then
                if not info:match('fx_') then
                    -- RECEIVE FROM SELECTED
                    if imgui.IsKeyDown(ctx, imgui.Mod_Shift) then
                        for i = 0, r.CountSelectedTracks(0) - 1 do
                            r.CreateTrackSend(r.GetSelectedTrack(0, i), dragged_track)
                        end
                    else
                        r.CreateTrackSend(dest_track, dragged_track)
                    end
                end
            else
                -- SEND
                local send_idx = nil
                if imgui.IsKeyDown(ctx, imgui.Mod_Shift) then
                    for i = 0, r.CountSelectedTracks(0) - 1 do
                        r.CreateTrackSend(dragged_track, r.GetSelectedTrack(0, i))
                    end
                else
                    send_idx = r.CreateTrackSend(dragged_track, dest_track)
                end
                -- SIDECHAIN
                if info:match('fx_') then
                    IncreaseTrackChannelCnt(dest_track)
                    ---@diagnostic disable-next-line: param-type-mismatch
                    r.SetTrackSendInfo_Value(dragged_track, 0, send_idx, 'I_DSTCHAN', 2)
                end
            end


            r.Undo_EndBlock("Create Send", -1)
        end

        was_dragging = false
        dragged_track = nil
    end
end


local function DrawTrackNode(track, idx)
    -- Alfred IDX
    if idx < 10 and not dragged_track and imgui.IsKeyDown(ctx, imgui.Mod_Ctrl) then
        imgui.SameLine(ctx)
        imgui.TextColored(ctx, 0xFFFFFF55, '[' .. idx .. ']')
    end

    if settings.show_color_box then
        imgui.SameLine(ctx)

        local cursor_pos_x, cursor_pos_y = imgui.GetCursorPos(ctx)
        imgui.SetCursorPos(ctx, cursor_pos_x, cursor_pos_y + 3)

        imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, 12)
        imgui.ColorButton(ctx, 'color', track.color, colorbox_flags, colorbox_size, colorbox_size)
        imgui.PopStyleVar(ctx)

        imgui.SetCursorPos(ctx, cursor_pos_x, cursor_pos_y)
    end


    imgui.SameLine(ctx, nil, 5)
    local displayed_string = settings.show_track_number and track.number .. ': ' .. track.name or track.name
    local displayed_color = 0xFFFFFFFF


    imgui.TextColored(ctx, (settings.dim_hidden_tracks and track.showtcp == 0) and 0xFFFFFF55 or 0xFFFFFFFF,
        displayed_string)
end


local function SetupTrackTree()
    local is_parent_open = true
    local depth = 0
    local open_depth = 0

    for i = 1, #filtered_tracks do
        local track = filtered_tracks[i]
        if track == nil then goto continue end

        -- check is folder and prevent depth + delta being < 0
        local depth_delta = math.max(track.folderdepth, -depth)
        local is_folder = depth_delta > 0

        if (is_parent_open or depth <= open_depth) then
            -- Close child folders first
            for current_level = depth, open_depth - 1 do
                imgui.TreePop(ctx)
                open_depth = depth
            end


            local node_flags = is_folder and node_flags_base or node_flags_leaf

            local fp_x, fp_y = imgui.GetStyleVar(ctx, imgui.StyleVar_FramePadding)

            is_parent_open = imgui.TreeNodeEx(ctx, 'treenode' .. i, '', node_flags)

            if settings.nav_mode and imgui.IsItemFocused(ctx) then
                DoNavModeAction(track)
            end

            if IsItemDoubleClicked() or IsEnterPressedOnItem() then
                DoActionOnTrack(track,
                    imgui.IsKeyDown(ctx, imgui.Mod_Shift), imgui.IsKeyDown(ctx, imgui.Mod_Ctrl))
            end
            SetupDragDrop(track)
            DrawTrackNode(track, i)
        end

        depth = depth + depth_delta
        if (is_folder and is_parent_open) then open_depth = depth end

        ::continue::
    end

    for current_level = 0, open_depth - 1 do
        imgui.TreePop(ctx)
    end
end


local function BeginTrackTree()
    if #filtered_tracks == 0 then
        imgui.PushStyleVar(ctx, imgui.StyleVar_Alpha, 0.5)
        imgui.Text(ctx, #tracks == 0 and 'No Tracks' or 'No Match')
        imgui.PopStyleVar(ctx)

        return
    end

    SetupTrackTree()
end


local function DrawWindow()
    local changed = DrawSearchFilter()
    if changed then UpdateTrackList() end

    BeginTrackTree()
end

local function UpdateFontSizes()
    settings.font_size = new_font_size
    tooltip_font_size = settings.font_size - 3
    font = imgui.CreateFont('sans-serif', settings.font_size)
    tooltip_font = imgui.CreateFont('sans-serif', tooltip_font_size)

    colorbox_size = settings.font_size * 0.6

    imgui.Attach(ctx, font)
    imgui.Attach(ctx, tooltip_font)
end

local function BeginGui()
    if new_font_size ~= settings.font_size then UpdateFontSizes() end

    imgui.PushFont(ctx, font)
    imgui.PushStyleVar(ctx, imgui.StyleVar_WindowRounding, 5)
    imgui.SetNextWindowSize(ctx, 250, 350, imgui.Cond_FirstUseEver)

    visible, app_open = imgui.Begin(ctx, script_name, true,
        settings.hide_titlebar and notitle_wflags or default_wflags)

    if visible then
        DrawWindow()
        imgui.End(ctx)
    end

    imgui.PopStyleVar(ctx)
    imgui.PopFont(ctx)

    if imgui.IsKeyPressed(ctx, imgui.Key_Escape) then app_open = false end
end


----------------------
-- MAIN
----------------------

local function main()
    if IsProjectChanged() then UpdateAllData() end

    BeginGui()
    if not dragged_track then DoAlfredStyleCmd() end

    if app_open then r.defer(main) end
    if first_frame then first_frame = false end
end

local function PrepRandomShit()
    new_font_size = settings.font_size
    tooltip_font_size = settings.font_size - 3
    colorbox_size = settings.font_size * 0.6

    font = imgui.CreateFont('sans-serif', settings.font_size)
    tooltip_font = imgui.CreateFont('sans-serif', tooltip_font_size)

    imgui.Attach(ctx, font)
    imgui.Attach(ctx, tooltip_font)
    imgui.SetConfigVar(ctx, imgui.ConfigVar_MouseDoubleClickTime, 0.2)

    local os = r.GetOS()
    if os:match("OSX") or os:match("macOS") then is_macOS = true end
    if is_macOS then imgui.SetConfigVar(ctx, imgui.ConfigVar_MacOSXBehaviors, 1) end

    if not js_api then settings.use_routing_cursor = false end
end

local function init()
    ReadSettingsFromExtState()
    PrepRandomShit()
    UpdateAllData()
end

local function exit()
    WriteSettingsToExtState()
end


r.atexit(exit)
init()
main()
