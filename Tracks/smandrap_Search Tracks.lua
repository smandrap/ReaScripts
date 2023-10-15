-- @description Search Tracks
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--  Cubase style track search. REQUIRES REAIMGUI !!
--  Shortcuts:
--    Cmd/Ctrl+F : focus search field
--    Arrows/Tab: navigate
--    Enter/Double Click on name: GO
--    Drag/Drop on Track: Create send
--    Esc: Exit

local script_name = "Search Tracks"
local reaper = reaper

if not reaper.ImGui_GetVersion() then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

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
local visible, open
local font = reaper.ImGui_CreateFont('sans-serif', 12)


local first_frame = true
local window_flags =  reaper.ImGui_WindowFlags_NoCollapse()

local node_flags_base = reaper.ImGui_TreeNodeFlags_OpenOnArrow() 
                      | reaper.ImGui_TreeNodeFlags_DefaultOpen()
                      | reaper.ImGui_TreeNodeFlags_SpanAvailWidth()
local node_flags_leaf = node_flags_base 
                      | reaper.ImGui_TreeNodeFlags_Leaf() 
                      | reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen()                  
                  
local was_dragging = false

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
    t[i] = reaper.GetTrack(0, i - 1)
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
    
    local _, tr_name = reaper.GetTrackName(tracks[i])
    
    if string.match(string.lower(tr_name), string.lower(search_string)) then
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
   -- TODO: option to uncollapse folder if it's the track we searched
  
  local depth = reaper.GetTrackDepth(track)
  local track_buf = track
  
  for i = depth, 1, -1 do
    local parent = reaper.GetParentTrack(track_buf)
    
    if parent then track_buf = parent end
    reaper.SetMediaTrackInfo_Value(track_buf, 'I_FOLDERCOMPACT', 0)
  end
  
  -- Show
  reaper.SetMediaTrackInfo_Value(track, 'B_SHOWINTCP', 1)
  reaper.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
  
  -- Select
  reaper.SetOnlyTrackSelected(track)
  reaper.Main_OnCommand(40913, 0) -- Vertical scroll to track
  
  reaper.Undo_EndBlock("Change Track Selection", -1)
  
  -- Close program
  open = false
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


local function DrawSearchFilter()
  local changed = false
  
  if IsSearchShortcutPressed() or first_frame or #filtered_tracks == 0 then reaper.ImGui_SetKeyboardFocusHere(ctx) end

  reaper.ImGui_SetNextItemWidth(ctx, reaper.ImGui_GetWindowWidth(ctx) - 15)
  changed, search_string = reaper.ImGui_InputTextWithHint(ctx, '##searchfilter', 'Search' , search_string)
  
  -- If search filter is focused and enter is pressed, do thing to first search result
  if reaper.ImGui_IsItemFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
    DoActionOnTrack(filtered_tracks[1])
  end

  
  return changed
end


local function SetupDragDrop(track)
    -- TODO: Custom cursor??
    if reaper.ImGui_BeginDragDropSource(ctx) then
      was_dragging = true
      dragged_track = track
      
      reaper.ImGui_EndDragDropSource(ctx)
    end

    -- End of DragnDrop
    if was_dragging and not reaper.ImGui_IsMouseDown(ctx, 0) then
      
      local tr = reaper.GetTrackFromPoint(reaper.GetMousePosition())
      if tr and dragged_track then
          reaper.Undo_BeginBlock()
          
          local sendidx = reaper.CreateTrackSend(dragged_track, tr)
          
          reaper.Undo_EndBlock("Create Send", -1)
      end 
      
      was_dragging = false
      dragged_track = nil
    end
end


local function DrawTrackTree()
  local parent_open, depth, open_depth = true, 0, 0
  
  for i = 1, #filtered_tracks do
    local track = filtered_tracks[i]
    if track == nil then goto continue end
    
    local _, tr_name = reaper.GetTrackName(track)
    
    -- check is folder
    local depth_delta = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')
    depth_delta = math.max(depth_delta, -depth) -- prevent depth + delta being < 0
    local is_folder = depth_delta > 0
    
    if parent_open or depth <= open_depth then
      -- Close child folders first
      for level = depth, open_depth - 1 do
          reaper.ImGui_TreePop(ctx)
          open_depth = depth
      end
      
      local node_flags = is_folder and node_flags_base or node_flags_leaf
      
      -- Maybe do stuff here if track is hidden/muted etc??
      
      reaper.ImGui_PushID(ctx, i)
      parent_open = reaper.ImGui_TreeNode(ctx, tr_name, node_flags)
      reaper.ImGui_PopID(ctx)
      
      
      -- Double Click
      if IsItemDoubleClicked() or IsEnterPressedOnItem() then
        DoActionOnTrack(track)
      end
      
      SetupDragDrop(track)
    end
    
    depth = depth + depth_delta
    if is_folder and parent_open then
        open_depth = depth
    end
    
    ::continue::
  end
  
  for level = 0, open_depth - 1 do
      reaper.ImGui_TreePop(ctx)
  end
  
end


local function BeginTrackList()
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

  DrawTrackTree()
  
end


local function DrawWindow()
  local changed = DrawSearchFilter()
  if changed then UpdateTrackList() end
  
  BeginTrackList()
end


local function BeginGui()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 5)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 300, reaper.ImGui_Cond_FirstUseEver())
  
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
  if IsProjectChanged() == true then 
  UpdateAllData() end
  
  BeginGui()
  
  if open then reaper.defer(main) end
  first_frame = false
end


local function init()
  reaper.ImGui_Attach(ctx, font)
  
  reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_MouseDoubleClickTime(), 0.2)
  UpdateAllData()
end

init()
main()
