-- @description Search Tracks
-- @author smandrap
-- @version 1.5
-- @donation https://paypal.me/smandrap
-- @changelog
--  + Add option to show all parents of actioned track (default: on)
-- @about
--  Cubase style track search with routing capabilities

-- TODO: 

--  Fix buggy Tab navigation
--  Font scaling
--  Draw hierarchy tree left of track list
--  Reduce tree identation
--  Define disabled tracks (muted? locked? fx_offline?)
--  Custom cursor for sends
--  Filters (is:muted, is:soloed, is:hidden, etc)
--  Pin searchbar to top of window
--  Shift click on node: collapse/uncollapse all
--  Make clear that routing is possible
--  Always show parent?


local script_name = "Search Tracks"
local reaper = reaper
if not reaper.ImGui_GetVersion() then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end


----------------------
-- DEFAULT SETTINGS
----------------------


local settings = {
  version = '1.5',
  uncollapse_selection = false,
  show_in_tcp = true,
  show_in_mcp = false,
  unhide_parents = true,
  close_on_action = true,
  show_track_number = false,
  show_color_box = true,
  hide_titlebar = false
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

local font_size = 13
local tooltip_font_size = font_size - 3
local font = reaper.ImGui_CreateFont('sans-serif', font_size)
local tooltip_font = reaper.ImGui_CreateFont('sans-serif', tooltip_font_size)

local default_wflags =  reaper.ImGui_WindowFlags_NoCollapse()
local notitle_wflags = default_wflags | reaper.ImGui_WindowFlags_NoTitleBar()

local node_flags_base = reaper.ImGui_TreeNodeFlags_OpenOnArrow() 
                      | reaper.ImGui_TreeNodeFlags_DefaultOpen()
                      | reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
                      
local node_flags_leaf = node_flags_base 
                      | reaper.ImGui_TreeNodeFlags_Leaf() 
                      | reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen()
                      
                      
local colorbox_size = font_size * 0.6
local colorbox_flags =  reaper.ImGui_ColorEditFlags_NoAlpha() 
                      | reaper.ImGui_ColorEditFlags_NoTooltip()
                  
local was_dragging = false

local enter_tracklist_focus = false

local help_text = script_name..' v'..settings.version..'\n\n'..
[[- Cmd/Ctrl+F : Focus search field
- Arrows/Tab : Navigate
- Enter/Double Click on name : Select in project
- Drag/Drop on TCP/MCP : Create send
- Drag/Drop on FX : Create sidechain send (ch 3-4)
- Cmd/Ctrl while dragging : Create receive
- Esc: Exit]]


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
  
  proj_change_cnt = buffer
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
  tr_ch_cnt = reaper.SetMediaTrackInfo_Value(track, 'I_NCHAN', 4)

end

local function UpdateTrackList()
  if search_filter == '' then 
    filtered_tracks = table_copy(tracks)
    return
  end
  
  table_delete(filtered_tracks)
  --filtered_tracks = {}
  
  for i = 1, #tracks do
    if tracks[i] == nil then goto continue end
    
    if string.match(string.lower(tracks[i].name), string.lower(search_string)) then
      table.insert(filtered_tracks, tracks[i])
    end
    
    ::continue::
  end
end


local function UpdateAllData()
  tracks = GetTracks()
  UpdateTrackList()
end


local function DoActionOnTrack(track)
  if not track then return end
  
  reaper.Undo_BeginBlock()
  
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
  
  -- Select
  reaper.SetOnlyTrackSelected(track.track)
  reaper.Main_OnCommand(40913, 0) -- Vertical scroll to track
  
  reaper.Undo_EndBlock("Change Track Selection", -1)
  
  -- Close program
  if settings.close_on_action then open = false end
end


local function ReadSettingsFromExtState()
  if not reaper.HasExtState('smandrap_SearchTracks', 'version') then return end
  
  for k, v in pairs(settings) do
    settings[k] = reaper.GetExtState('smandrap_SearchTracks', tostring(k)) == 'true' and true or false
  end

end

local function WriteSettingsToExtState()
  for k, v in pairs(settings) do
    reaper.SetExtState('smandrap_SearchTracks', k, tostring(v), true)
  end
end

----------------------
-- GUI FUNCS
----------------------

local function IsSearchShortcutPressed()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F()) 
end


local function IsItemDoubleClicked()
  return reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)
end


local function IsEnterPressedOnItem()
  local enter =  reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter())
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
    
    _, settings.uncollapse_selection = reaper.ImGui_MenuItem(ctx, 'Uncollapse folder', nil, settings.uncollapse_selection)
    
    reaper.ImGui_Separator(ctx)
    
    _, settings.close_on_action = reaper.ImGui_MenuItem(ctx, 'Quit after selection', nil, settings.close_on_action)
    
    reaper.ImGui_Separator(ctx)
    
    if reaper.ImGui_BeginMenu(ctx, 'GUI') then
      _, settings.hide_titlebar = reaper.ImGui_MenuItem(ctx, 'Hide Titlebar', nil, settings.hide_titlebar)
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
    reaper.ImGui_InputTextWithHint(ctx, '##searchfilter', settings.hide_titlebar and 'Search Tracks' or '' , search_string)
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
    DoActionOnTrack(filtered_tracks[1])
  end
  
  if reaper.ImGui_IsItemClicked(ctx, 1) then reaper.ImGui_OpenPopup(ctx, 'settings') end
  DrawSettingsMenu()
  
  return changed
end



local function SetupDragDrop(track)
    -- TODO: Custom cursor??
    -- TODO: Optimize Drag drop
    
    
    -- TODO: OMG REFACTOR THIS SHIT
    
    if reaper.ImGui_BeginDragDropSource(ctx) then
      reaper.ImGui_SetDragDropPayload(ctx, '_TREENODE', nil, 0)
      
      was_dragging = true
      dragged_track = track.track
      dest_track, info = reaper.GetThingFromPoint(reaper.GetMousePosition())
      
      dest_track = (info:match('tcp') or info:match('fx_')) and dest_track or nil
      local dest_track_name = dest_track and select(2, reaper.GetTrackName(dest_track)) or '...'
      
      if info:match('fx_') then
        reaper.ImGui_Text(ctx, 'SEND (Sidechain 3-4):\n\n[ '..track.name..' ]\n\nTO:\n\n[ '..dest_track_name..' ]')
      else
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) then
          reaper.ImGui_Text(ctx, 'SEND:\n\n[ '..dest_track_name..' ]\n\nTO:\n\n[ '..track.name..' ]') -- RECEIVE
        else
          reaper.ImGui_Text(ctx, 'SEND:\n\n[ '..track.name..' ]\n\nTO:\n\n[ '..dest_track_name..' ]') -- SEND
        end
      end
      
      reaper.ImGui_EndDragDropSource(ctx)
    end
    
    -- End of DragnDrop so create send
    if was_dragging and not reaper.ImGui_IsMouseDown(ctx, 0) then
      
      if dest_track and dragged_track then
        reaper.Undo_BeginBlock()
        
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) then
          if not info:match('fx_') then reaper.CreateTrackSend(dest_track, dragged_track) end
        else
          -- SEND
          local send_idx = reaper.CreateTrackSend(dragged_track, dest_track)
          
          -- SIDECHAIN
          if info:match('fx_') then
            IncreaseTrackChannelCnt(dest_track)
            reaper.SetTrackSendInfo_Value(dragged_track, 0, send_idx, 'I_DSTCHAN', 2)
          end
        end
        
        
        reaper.Undo_EndBlock("Create Send", -1)
      end 
      
      was_dragging = false
      dragged_track = nil
    end
end


local function DrawTrackNode(track)
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
  local displayed_string = settings.show_track_number and track.number..': '..track.name or track.name
  reaper.ImGui_TextColored(ctx, not track.showintcp and 0xFFFFFFFF or 0xFFFFFF55, displayed_string)

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
    
    if (parent_open or depth <= open_depth) then
    
      -- Close child folders first
      for current_level = depth, open_depth - 1 do
          reaper.ImGui_TreePop(ctx)
          open_depth = depth
      end
      
      
      local node_flags = is_folder and node_flags_base or node_flags_leaf
      
      is_parent_open = reaper.ImGui_TreeNodeEx(ctx, 'treenode'..i, '', node_flags)
      if IsItemDoubleClicked() or IsEnterPressedOnItem() then DoActionOnTrack(track) end
      SetupDragDrop(track)
      DrawTrackNode(track)
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
  
  --[[
  if reaper.ImGui_BeginChild(ctx, 'tracklist') then
    if enter_tracklist_focus then           -- CFILLION FUNCTION
      reaper.ImGui_SetKeyboardFocusHere(ctx)
      enter_tracklist_focus = false
    end
  end
  --]]
  
  BeginTrackTree()
  
  --[[
  reaper.ImGui_EndChild( ctx )
  if reaper.ImGui_IsItemFocused(ctx) then
    enter_tracklist_focus = true
  end
  --]]
end


local function BeginGui()
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
  
  if open then reaper.defer(main) end
  if first_frame then first_frame = false end
end

local function init()
  reaper.ImGui_Attach(ctx, font)
  reaper.ImGui_Attach(ctx, tooltip_font)
  reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_MouseDoubleClickTime(), 0.2)
  
  ReadSettingsFromExtState()
  UpdateAllData()
end

local function exit()
  WriteSettingsToExtState()
end


reaper.atexit(exit)
init()
main()
