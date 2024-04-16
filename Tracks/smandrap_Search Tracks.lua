-- @description Search Tracks
-- @author smandrap
-- @version 1.8.3e9
-- @donation https://paypal.me/smandrap
-- @changelog
--   + Greatly improve search
--   + Add font scaling
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

dofile(reaper.GetResourcePath() ..
  '/Scripts/ReaTeam Extensions/API/imgui.lua') '0.8'


local script_name = "Search Tracks"
local reaper = reaper
if not reaper.ImGui_GetVersion then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

local js_api = false
if reaper.APIExists('JS_ReaScriptAPI_Version') then js_api = true end
local routing_cursor = js_api and reaper.JS_Mouse_LoadCursor(186) -- REAPER routing cursor
local normal_cursor = js_api and reaper.JS_Mouse_LoadCursor(0)

package.path = package.path ..
    ';' ..
    debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] ..
    "?.lua;" -- GET DIRECTORY FOR REQUIRE
local fzy = require("smandrap_Search Tracks.modules.fzy")

local extstate_section = 'smandrap_SearchTracks'

----------------------
-- DEFAULT SETTINGS
----------------------


local settings = {
  version = '1.8.2',
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
  font_size = 13
}

----------------------
-- APP VARS
----------------------

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

local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()

local ctx = reaper.ImGui_CreateContext(script_name, reaper.ImGui_ConfigFlags_NavEnableKeyboard())
local visible
local open
local first_frame = true

local open_settings = false

local new_font_size
local tooltip_font_size
local colorbox_size

local font
local tooltip_font

local default_wflags = reaper.ImGui_WindowFlags_NoCollapse()
local notitle_wflags = default_wflags | reaper.ImGui_WindowFlags_NoTitleBar()

local node_flags_base = reaper.ImGui_TreeNodeFlags_OpenOnArrow()
    | reaper.ImGui_TreeNodeFlags_DefaultOpen()
    | reaper.ImGui_TreeNodeFlags_SpanAvailWidth()

local node_flags_leaf = node_flags_base
    | reaper.ImGui_TreeNodeFlags_Leaf()
    | reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen()

local colorbox_flags = reaper.ImGui_ColorEditFlags_NoAlpha()
    | reaper.ImGui_ColorEditFlags_NoTooltip()

local was_dragging = false

local help_text = script_name .. ' v' .. settings.version .. '\n\n' ..
    [[- Cmd/Ctrl+F : Focus search field
- Arrows/Tab : Navigate
- Esc: Exit

- Enter/Double Click on name : Select in project
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
  local buf = reaper.GetProjectStateChangeCount(0)

  if proj_change_cnt == buf then return false end

  proj_change_cnt = buf
  return true
end

local function GetTrackInfo(track)
  local track_info = {}

  track_info.track = track
  track_info.number = math.floor(reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER'))
  track_info.name = select(2, reaper.GetTrackName(track))
  track_info.color = reaper.ImGui_ColorConvertNative(reaper.GetTrackColor(track))
  track_info.showtcp = reaper.GetMediaTrackInfo_Value(track, 'B_SHOWINTCP')
  track_info.showmcp = reaper.GetMediaTrackInfo_Value(track, 'B_SHOWINMIXER')
  track_info.folderdepth = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')

  return track_info
end

local function GetTracks()
  local t = {}

  for i = 1, reaper.CountTracks(0) do
    local track = reaper.GetTrack(0, i - 1)

    t[i] = GetTrackInfo(track)
  end

  return t
end

local function IncreaseTrackChannelCnt(track)
  local tr_ch_cnt = reaper.GetMediaTrackInfo_Value(track, 'I_NCHAN')

  if tr_ch_cnt > 4 then return end
  reaper.SetMediaTrackInfo_Value(track, 'I_NCHAN', 4)
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
    reaper.Main_OnCommand(reaper.NamedCommandLookup(tostring(t[i])), 0)
  end
end

local function DoActionOnTrack(track, add_to_selection)
  if not track then return end

  reaper.Undo_BeginBlock()

  if PRE_ACTIONS and settings.do_pre_actions == true then DoActions(PRE_ACTIONS) end

  -- Uncollapse Parents

  local depth = reaper.GetTrackDepth(track.track)
  local track_buf = track.track

  for i = settings.uncollapse_selection and (depth + 1) or depth, 1, -1 do
    local parent = reaper.GetParentTrack(track_buf)

    if parent then track_buf = parent end
    reaper.SetMediaTrackInfo_Value(track_buf, 'I_FOLDERCOMPACT', 0)
  end

  -- Show
  if settings.show_in_tcp then reaper.SetMediaTrackInfo_Value(track.track, 'B_SHOWINTCP', 1) end
  if settings.show_in_mcp then reaper.SetMediaTrackInfo_Value(track.track, 'B_SHOWINMIXER', 1) end

  -- Unhide Parents
  if settings.unhide_parents then
    local buf = track.track

    for j = reaper.GetTrackDepth(buf), 0, -1 do
      buf = reaper.GetParentTrack(buf)
      if buf then
        if settings.show_in_tcp then reaper.SetMediaTrackInfo_Value(buf, 'B_SHOWINTCP', 1) end
        if settings.show_in_mcp then reaper.SetMediaTrackInfo_Value(buf, 'B_SHOWINMIXER', 1) end
      end
    end
  end


  if add_to_selection then
    reaper.SetTrackSelected(track.track, true)
  else
    reaper.SetOnlyTrackSelected(track.track)
  end
  reaper.Main_OnCommand(40913, 0) -- Vertical scroll to track
  reaper.SetMixerScroll(track.track)

  if POST_ACTIONS and settings.do_post_actions == true then DoActions(POST_ACTIONS) end

  reaper.Undo_EndBlock("Change Track Selection", -1)

  -- Close program
  if settings.close_on_action then open = false end
end

local function DoAlfredStyleCmd()
  local trackidx = -1

  if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) then
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_1())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad1())
    then
      trackidx = 1
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_2())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad2())
    then
      trackidx = 2
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_3())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad3())
    then
      trackidx = 3
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_4())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad4())
    then
      trackidx = 4
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_5())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad5())
    then
      trackidx = 5
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_6())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad6())
    then
      trackidx = 6
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_7())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad7())
    then
      trackidx = 7
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_8())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad8())
    then
      trackidx = 8
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_9())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Keypad9())
    then
      trackidx = 9
    end
  end


  if trackidx > 0 then DoActionOnTrack(filtered_tracks[trackidx], reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())) end
end


local function ReadSettingsFromExtState()
  if not reaper.HasExtState(extstate_section, 'version') then return end

  for k, v in pairs(settings) do
    local extstate = reaper.GetExtState(extstate_section, k)
    if tonumber(extstate) then
      settings[k] = tonumber(extstate)
    else
      settings[k] = extstate == "true" and true or false
    end
  end
end

local function WriteSettingsToExtState()
  for k, v in pairs(settings) do
    reaper.SetExtState(extstate_section, k, tostring(v), true)
  end
end

----------------------
-- GUI FUNCS
----------------------

local function IsSearchShortcutPressed()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) and
      reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F())
end


local function IsItemDoubleClicked()
  return reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)
end


local function IsEnterPressedOnItem()
  local enter = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or
      reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter())
  return reaper.ImGui_IsItemFocused(ctx) and enter
end


local function DrawSettingsMenu()
  if reaper.ImGui_BeginPopup(ctx, 'settings', reaper.ImGui_SelectableFlags_DontClosePopups()) then
    reaper.ImGui_MenuItem(ctx, 'Show:', nil, nil, false)
    _, settings.show_track_number = reaper.ImGui_MenuItem(ctx, 'Track Number', nil, settings.show_track_number)
    _, settings.show_color_box = reaper.ImGui_MenuItem(ctx, 'Track color', nil, settings.show_color_box)

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_MenuItem(ctx, 'Unhide in:', nil, nil, false)
    _, settings.show_in_tcp = reaper.ImGui_MenuItem(ctx, 'TCP', nil, settings.show_in_tcp)
    _, settings.show_in_mcp = reaper.ImGui_MenuItem(ctx, 'MCP', nil, settings.show_in_mcp)
    _, settings.unhide_parents = reaper.ImGui_MenuItem(ctx, 'Also affect parents', nil, settings.unhide_parents)

    reaper.ImGui_Separator(ctx)

    _, settings.uncollapse_selection = reaper.ImGui_MenuItem(ctx, 'Uncollapse folder', nil, settings
      .uncollapse_selection)

    reaper.ImGui_Separator(ctx)

    reaper.ImGui_MenuItem(ctx, 'Run Actions (?):', nil, nil, false)
    if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenDisabled()) then
      if reaper.ImGui_BeginTooltip(ctx) then
        reaper.ImGui_PushFont(ctx, tooltip_font)
        reaper.ImGui_Text(ctx, help_text_actions)
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_EndTooltip(ctx)
      end
    end
    _, settings.do_pre_actions = reaper.ImGui_MenuItem(ctx, 'Pre-actions (' .. #PRE_ACTIONS .. ')', nil,
      settings.do_pre_actions)
    _, settings.do_post_actions = reaper.ImGui_MenuItem(ctx, 'Post-actions (' .. #POST_ACTIONS .. ')', nil,
      settings.do_post_actions)


    reaper.ImGui_Separator(ctx)
    _, settings.close_on_action = reaper.ImGui_MenuItem(ctx, 'Quit after selection', nil, settings.close_on_action)

    reaper.ImGui_Separator(ctx)

    if reaper.ImGui_BeginMenu(ctx, 'GUI') then
      _, settings.hide_titlebar = reaper.ImGui_MenuItem(ctx, 'Hide Titlebar', nil, settings.hide_titlebar)
      _, settings.dim_hidden_tracks = reaper.ImGui_MenuItem(ctx, 'Dim Hidden track names', nil,
        settings.dim_hidden_tracks)
      _, settings.use_routing_cursor = reaper.ImGui_MenuItem(ctx, 'Use Routing Cursor', nil, settings.use_routing_cursor,
        js_api)
      if not js_api then
        if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenDisabled()) then
          if reaper.ImGui_IsMouseClicked(ctx, 0) then
            reaper.ReaPack_BrowsePackages('JS_ReascriptAPI')
          end

          if reaper.ImGui_BeginTooltip(ctx) then
            reaper.ImGui_PushFont(ctx, tooltip_font)
            reaper.ImGui_Text(ctx, 'Requires JS_Api.\n(Click to install)')
            reaper.ImGui_PopFont(ctx)
            reaper.ImGui_EndTooltip(ctx)
          end
        end
      end
      reaper.ImGui_Separator(ctx)

      reaper.ImGui_AlignTextToFramePadding(ctx)
      reaper.ImGui_Text(ctx, 'Font Size:')
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SetNextItemWidth(ctx, 50)

      _, new_font_size = reaper.ImGui_InputInt(ctx, "##FontSize", new_font_size, 0)
      new_font_size = new_font_size < 10 and 10 or new_font_size > 20 and 20 or new_font_size
      reaper.ImGui_EndMenu(ctx)
    end

    -- HELP here
    if reaper.ImGui_BeginMenu(ctx, 'Help') then
      reaper.ImGui_MenuItem(ctx, help_text, nil, nil, false)
      reaper.ImGui_EndMenu(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
  end
end


local function DrawSearchFilter()
  local changed = false

  if IsSearchShortcutPressed() or first_frame then reaper.ImGui_SetKeyboardFocusHere(ctx) end

  reaper.ImGui_SetNextItemWidth(ctx, -FLT_MIN)

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 2)
  changed, search_string =
      reaper.ImGui_InputTextWithHint(ctx, '##searchfilter', settings.hide_titlebar and 'Search Tracks' or '',
        search_string)
  reaper.ImGui_PopStyleVar(ctx)

  -- Tooltip
  if reaper.ImGui_IsItemHovered(ctx) and not open_settings then
    reaper.ImGui_PushFont(ctx, tooltip_font)
    reaper.ImGui_BeginTooltip(ctx)
    reaper.ImGui_Text(ctx, 'Right-Click: options')
    reaper.ImGui_EndTooltip(ctx)
    reaper.ImGui_PopFont(ctx)
  end

  -- If search filter is focused and enter is pressed, do thing to first search result
  if reaper.ImGui_IsItemFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
    DoActionOnTrack(filtered_tracks[1], reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()))
  end

  if reaper.ImGui_IsItemClicked(ctx, 1) then reaper.ImGui_OpenPopup(ctx, 'settings') end
  DrawSettingsMenu()

  return changed
end



local function SetupDragDrop(track)
  -- TODO: Optimize Drag drop


  -- TODO: OMG REFACTOR THIS SHIT

  if reaper.ImGui_BeginDragDropSource(ctx) then
    reaper.ImGui_SetDragDropPayload(ctx, 'dragdrop', 'track', 0)
    if js_api and settings.use_routing_cursor and routing_cursor then
      reaper.JS_Mouse_SetCursor(routing_cursor)
    end

    was_dragging = true
    dragged_track = track.track
    dest_track, info = reaper.GetThingFromPoint(reaper.GetMousePosition())

    dest_track = (info:match('tcp') or info:match('mcp') or info:match('fx_')) and dest_track or nil
    local dest_track_name = dest_track and select(2, reaper.GetTrackName(dest_track)) or '...'
    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then dest_track_name = "ALL SELECTED" end

    if reaper.ImGui_BeginTooltip(ctx) then
      if info:match('fx_') then
        reaper.ImGui_Text(ctx, 'SEND (Sidechain 3-4):\n\n[ ' .. track.name .. ' ]\n\nTO:\n\n[ ' .. dest_track_name ..
          ' ]')
      else
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) then
          reaper.ImGui_Text(ctx, 'SEND:\n\n[ ' .. dest_track_name .. ' ]\n\nTO:\n\n[ ' .. track.name .. ' ]') -- RECEIVE
        else
          reaper.ImGui_Text(ctx, 'SEND:\n\n[ ' .. track.name .. ' ]\n\nTO:\n\n[ ' .. dest_track_name .. ' ]') -- SEND
        end
      end
    end
    reaper.ImGui_EndTooltip(ctx)

    reaper.ImGui_EndDragDropSource(ctx)
  end
  -- End of DragnDrop so create send
  if was_dragging and not reaper.ImGui_IsMouseDown(ctx, 0) then
    if js_api and settings.use_routing_cursor then
---@diagnostic disable-next-line: param-type-mismatch
      reaper.JS_Mouse_SetCursor(normal_cursor)
    end


    if dest_track and dragged_track then
      reaper.Undo_BeginBlock()

      -- RECEIVES
      if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) then
        if not info:match('fx_') then
          -- RECEIVE FROM SELECTED
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then
            for i = 0, reaper.CountSelectedTracks(0) - 1 do
              reaper.CreateTrackSend(reaper.GetSelectedTrack(0, i), dragged_track)
            end
          else
            reaper.CreateTrackSend(dest_track, dragged_track)
          end
        end
      else
        -- SEND
        local send_idx = nil
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then
          for i = 0, reaper.CountSelectedTracks(0) - 1 do
            reaper.CreateTrackSend(dragged_track, reaper.GetSelectedTrack(0, i))
          end
        else
          send_idx = reaper.CreateTrackSend(dragged_track, dest_track)
        end
        -- SIDECHAIN
        if info:match('fx_') then
          IncreaseTrackChannelCnt(dest_track)
---@diagnostic disable-next-line: param-type-mismatch
          reaper.SetTrackSendInfo_Value(dragged_track, 0, send_idx, 'I_DSTCHAN', 2)
        end
      end


      reaper.Undo_EndBlock("Create Send", -1)
    end

    was_dragging = false
    dragged_track = nil
  end
end


local function DrawTrackNode(track, idx)
  -- Alfred IDX
  if idx < 10 and not dragged_track and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, 0xFFFFFF55, '[' .. idx .. ']')
  end

  if settings.show_color_box then
    reaper.ImGui_SameLine(ctx)

    local cursor_pos_x, cursor_pos_y = reaper.ImGui_GetCursorPos(ctx)
    reaper.ImGui_SetCursorPos(ctx, cursor_pos_x, cursor_pos_y + 3)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 12)
    reaper.ImGui_ColorButton(ctx, 'color', track.color, colorbox_flags, colorbox_size, colorbox_size)
    reaper.ImGui_PopStyleVar(ctx)

    reaper.ImGui_SetCursorPos(ctx, cursor_pos_x, cursor_pos_y)
  end


  reaper.ImGui_SameLine(ctx, nil, 5)
  local displayed_string = settings.show_track_number and track.number .. ': ' .. track.name or track.name
  local displayed_color = 0xFFFFFFFF


  reaper.ImGui_TextColored(ctx, (settings.dim_hidden_tracks and track.showtcp == 0) and 0xFFFFFF55 or 0xFFFFFFFF,
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
        reaper.ImGui_TreePop(ctx)
        open_depth = depth
      end


      local node_flags = is_folder and node_flags_base or node_flags_leaf

      local fp_x, fp_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())

      is_parent_open = reaper.ImGui_TreeNodeEx(ctx, 'treenode' .. i, '', node_flags)

      if IsItemDoubleClicked() or IsEnterPressedOnItem() then
        DoActionOnTrack(track,
          reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()))
      end
      SetupDragDrop(track)
      DrawTrackNode(track, i)
    end

    depth = depth + depth_delta
    if (is_folder and is_parent_open) then open_depth = depth end

    ::continue::
  end

  for current_level = 0, open_depth - 1 do
    reaper.ImGui_TreePop(ctx)
  end
end


local function BeginTrackTree()
  if #tracks == 0 then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), 0.5)
    reaper.ImGui_Text(ctx, 'No Tracks')
    reaper.ImGui_PopStyleVar(ctx)
    return
  end


  if #filtered_tracks == 0 then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), 0.5)
    reaper.ImGui_Text(ctx, 'No Match')
    reaper.ImGui_PopStyleVar(ctx)

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
  font = reaper.ImGui_CreateFont('sans-serif', settings.font_size)
  tooltip_font = reaper.ImGui_CreateFont('sans-serif', tooltip_font_size)

  colorbox_size = settings.font_size * 0.6

  reaper.ImGui_Attach(ctx, font)
  reaper.ImGui_Attach(ctx, tooltip_font)
end

local function BeginGui()
  if new_font_size ~= settings.font_size then UpdateFontSizes() end

  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 5)
  reaper.ImGui_SetNextWindowSize(ctx, 250, 350, reaper.ImGui_Cond_FirstUseEver())

  visible, open = reaper.ImGui_Begin(ctx, script_name, true, settings.hide_titlebar and notitle_wflags or default_wflags)

  if visible then
    DrawWindow()
    reaper.ImGui_End(ctx)
  end

  reaper.ImGui_PopStyleVar(ctx)
  reaper.ImGui_PopFont(ctx)

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then open = false end
end


----------------------
-- MAIN
----------------------

local function main()
  if IsProjectChanged() then UpdateAllData() end

  BeginGui()
  if not dragged_track then DoAlfredStyleCmd() end

  if open then reaper.defer(main) end
  if first_frame then first_frame = false end
end

local function PrepRandomShit()
  new_font_size = settings.font_size
  tooltip_font_size = settings.font_size - 3
  colorbox_size = settings.font_size * 0.6

  font = reaper.ImGui_CreateFont('sans-serif', settings.font_size)
  tooltip_font = reaper.ImGui_CreateFont('sans-serif', tooltip_font_size)

  reaper.ImGui_Attach(ctx, font)
  reaper.ImGui_Attach(ctx, tooltip_font)
  reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_MouseDoubleClickTime(), 0.2)

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


reaper.atexit(exit)
init()
main()
