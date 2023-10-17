-- @description Search Tracks
-- @author smandrap
-- @version 1.1
-- @donation https://paypal.me/smandrap
-- @changelog
--  + Add basic send tooltip (maybe will improve)
--  + Dim font color on tcp hidden tracks
--  + Add settings menu (right click search filter, config stored in REAPER/Data folder)
--  + Add option to display track color indicator (deafault: on)
--  + Add option to keep script open after selection (default: off)
--  + Add option to uncollapse actioned track if it's a folder (default: off)
--  + Add options to unhide tracks in TCP/MCP after selection (default: TCP on, MCP off)
--  + Add option to show track number (default: off)
--  + Add help menu
--  # Internal refactor (fetch track data on project update)
--  # Avoid creating sends by dragging on arrange view
--  # Fix close button if no matches or no tracks in project
--  # Change first use window size
--  # Increase font size by 1 px
-- @about
--  Cubase style track search.
--  Shortcuts:
--    Cmd/Ctrl+F : focus search field
--    Arrows/Tab: navigate
--    Enter/Double Click on name: GO
--    Drag/Drop on Track: Create send
--    Esc: Exit

-- TODO: 

--  Draw hierarchy tree left of track list
--  Reduce tree identation
--  Define disabled tracks (muted? locked? fx_offline?)
--  Support adding receives
--  Custom cursor for sends
--  Better Tooltip for sends dragndrop
--  Filters (is:muted, is:soloed, is:hidden, etc)
--  Pin searchbar to top of window
--  Shift click on node: collapse/uncollapse all
--  Make clear that routing is possible


local script_name = "Search Tracks"
local version = 1.1
local reaper = reaper
if not reaper.ImGui_GetVersion() then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end


local separator = (reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64") and "\\" or "/"
local data_path = reaper.GetResourcePath()..separator..'Data'
local config_filename = 'smandrap_SearchTracks_cfg.ini'
local config_path = data_path..separator..config_filename

----------------------
-- DEFAULT SETTINGS
----------------------

local settings = {
  uncollapse_selection = false,
  show_in_tcp = true,
  show_in_mcp = false,
  close_on_action = true,
  show_track_number = false,
  show_color_box = true
}

----------------------
-- APP VARS
----------------------

local proj_change_cnt = 0

local tracks = {}
local filtered_tracks = {}

local selected_track
local dragged_track

local search_string = ''

----------------------
-- GUI VARS
----------------------

local ctx = reaper.ImGui_CreateContext(script_name, reaper.ImGui_ConfigFlags_NavEnableKeyboard())
local visible
local open
local first_frame = true

local open_settings = false

local font_size = 13
local tooltip_font_size = font_size - 3
local font = reaper.ImGui_CreateFont('sans-serif', font_size)
local tooltip_font = reaper.ImGui_CreateFont('sans-serif', tooltip_font_size)
local window_flags =  reaper.ImGui_WindowFlags_NoCollapse()

local node_flags_base = reaper.ImGui_TreeNodeFlags_OpenOnArrow() 
                      | reaper.ImGui_TreeNodeFlags_DefaultOpen()
                      | reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
                      
local node_flags_leaf = node_flags_base 
                      | reaper.ImGui_TreeNodeFlags_Leaf() 
                      | reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen()
                      
local colorbox_flags =  reaper.ImGui_ColorEditFlags_NoAlpha() 
                      | reaper.ImGui_ColorEditFlags_NoTooltip()
                  
local was_dragging = false

local help_text = script_name..' v'..tostring(version)..'\n'..
[[- Cmd/Ctrl+F : focus search field
- Arrows/Tab: navigate
- Enter/Double Click on name: GO
- Drag/Drop on Track: Create send
- Esc: Exit]]

----------------------
-- APP FUNCS
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

local function IsProjectChanged()
  
  local buf = reaper.GetProjectStateChangeCount(0)
  
  if proj_change_cnt == buf then return false end
  
  proj_change_cnt = buffer
  return true

end

local function GetTracks()
  local t = {}
  
  for i = 1, reaper.CountTracks(0) do
    local track_info = {}
    local track = reaper.GetTrack(0, i - 1)
    
    track_info.track = track
    track_info.number = i
    track_info.name = select(2, reaper.GetTrackName(track))
    track_info.color = reaper.ImGui_ColorConvertNative(reaper.GetTrackColor(track))
    track_info.showtcp = reaper.GetMediaTrackInfo_Value(track, 'B_SHOWINTCP')
    track_info.showmcp = reaper.GetMediaTrackInfo_Value(track, 'B_SHOWINMIXER')
    track_info.folderdepth = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')
    
    t[i] = track_info
  end
  
  return t
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
  
  -- Select
  reaper.SetOnlyTrackSelected(track.track)
  reaper.Main_OnCommand(40913, 0) -- Vertical scroll to track
  
  reaper.Undo_EndBlock("Change Track Selection", -1)
  
  -- Close program
  if settings.close_on_action then open = false end
end

local function ReadSettingsFromConfigFile()
  if not reaper.file_exists(config_path) then return end  -- Use defaults if file not found
  
  local file = io.open(config_path, 'r')
  local config = {}
    
  for cfg_line in file:lines() do
    table.insert(config, cfg_line)    
  end
  file:close()

  for i = 1, #config do
    for k, v in config[i]:gmatch('(.+)=(.+)') do
      settings[k] = (v == 'true') and true or false
    end
  end

end


local function WriteSettingsToConfigFile()
  local file = io.open(config_path, 'w')
  local buf = {}
  
  for k, v in pairs(settings) do

    table.insert(buf, k..'='..tostring(v))
  end
  
  file:write(table.concat(buf, '\n'))
  
  io.close(file)
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
    
    reaper.ImGui_Separator(ctx)
    
    _, settings.uncollapse_selection = reaper.ImGui_MenuItem(ctx, 'Uncollapse folder', nil, settings.uncollapse_selection)
    
    reaper.ImGui_Separator(ctx)
    
    _, settings.close_on_action = reaper.ImGui_MenuItem(ctx, 'Quit after selection', nil, settings.close_on_action)
    
    reaper.ImGui_Separator(ctx)
    
    
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

  reaper.ImGui_SetNextItemWidth(ctx, reaper.ImGui_GetWindowWidth(ctx) - 15)
  changed, search_string = reaper.ImGui_InputTextWithHint(ctx, '##searchfilter', 'Search' , search_string)
  
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
    if reaper.ImGui_BeginDragDropSource(ctx) then
      reaper.ImGui_SetDragDropPayload(ctx, '_TREENODE', nil, 0)
      
      -- TODO: Improve this
      reaper.ImGui_Text(ctx, 'Send '..track.name..' to..')
      
      was_dragging = true
      dragged_track = track.track
      
      reaper.ImGui_EndDragDropSource(ctx)
    end
    
    -- End of DragnDrop
    if was_dragging and not reaper.ImGui_IsMouseDown(ctx, 0) then
    
      local mousepos_x, mousepos_y = reaper.GetMousePosition()
      local dest_track, info = reaper.GetThingFromPoint(mousepos_x, mousepos_y)

      if dest_track and dragged_track and info:match('tcp') then
          reaper.Undo_BeginBlock()
          
          local sendidx = reaper.CreateTrackSend(dragged_track, dest_track)
          
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
    reaper.ImGui_ColorButton(ctx, 'color', track.color, colorbox_flags, 8, 8)
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
      
      is_parent_open = reaper.ImGui_TreeNodeEx(ctx, i, '', node_flags)
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
  
  BeginTrackTree()
end


local function BeginGui()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 5)
  reaper.ImGui_SetNextWindowSize(ctx, 250, 350, reaper.ImGui_Cond_FirstUseEver())
  
  visible, open = reaper.ImGui_Begin(ctx, script_name, true, window_flags)
  
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
  
  ReadSettingsFromConfigFile()
  UpdateAllData()
end

local function exit()
  WriteSettingsToConfigFile()
end


reaper.atexit(exit)
init()
main()
