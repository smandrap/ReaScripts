-- @description Duplicate Tracks
-- @author smandrap
-- @version 1.5.1
-- @changelog
--    # Add minimum required REAPER version (7.03) check
-- @donation https://paypal.me/smandrap
-- @about
--   Pro Tools style Duplicate Tracks window

local reaper = reaper
local script_name = "Duplicate Tracks"

local reaper_version = tonumber(string.sub(reaper.GetAppVersion(), 0, 4))
if reaper_version < 7.03 then
  reaper.MB('REAPER v7.03 or later is required to run this script.\n Update from website.', 'Wrong REAPER Version', 0)
end

if not reaper.ImGui_GetVersion() then
  local ok = reaper.MB('Install now?\n\n(REAPER restart is required after install)', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

if not reaper.CF_GetSWSVersion then
  local ok = reaper.MB('Install now?\n\n(REAPER restart is required after install)', 'SWS Extensions Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("SWS Extensions") end
  return
end

-- APP

reaper.set_action_options(3)

local extstate_section = 'smandrap_Duplicate Tracks'

local _ = nil
local dupenum = 1

local dupeElements = {}

dupeElements.activeLane = true
dupeElements.otherLanes = true
dupeElements.envelopes = true
dupeElements.fx = true
dupeElements.instruments = true
dupeElements.sends = true
dupeElements.receives = true
dupeElements.groupAssign = true
dupeElements.renameDupes = true

local duplicated_tracks = {}

local insertLastSel = false


local function DeleteActiveLanes(track)
  local numlanes = reaper.GetMediaTrackInfo_Value(track, 'I_NUMFIXEDLANES')
  local itm_cnt = reaper.CountTrackMediaItems(track)
  local itm_toDelete = {}

  local playingLanes = {}

  for i = 0, numlanes - 1 do
    local laneplays = reaper.GetMediaTrackInfo_Value(track, 'C_LANEPLAYS:' .. i)
    playingLanes[i] = laneplays > 0 and true or false
  end

  for i = 0, itm_cnt - 1 do
    local itm = reaper.GetTrackMediaItem(track, i)
    local itm_lane = reaper.GetMediaItemInfo_Value(itm, 'I_FIXEDLANE')

    if playingLanes[itm_lane] == true then
      itm_toDelete[#itm_toDelete + 1] = itm
    end
  end

  for i = 1, #itm_toDelete do
    reaper.DeleteTrackMediaItem(track, itm_toDelete[i])
  end

  reaper.Main_OnCommand(42689, 0) -- Track lanes: Delete lanes with no media items
end


-- This is better but API has bug
local function DeleteActiveLanes(track)
  --local track = reaper.GetTrack(0, 0)
  if not reaper.ValidatePtr(track, "MediaTrack*") then return end

  local numlanes = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  for i = 0, numlanes - 1 do
    local laneplays = reaper.GetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i)

    reaper.SetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i, laneplays == 0 and 2 or 0)
  end

  reaper.Main_OnCommand(42691, 0) --Track lanes: Delete lanes (including media items) that are not playing

  numlanes = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  for i = 0, numlanes - 1 do
    reaper.SetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i, 0)
  end
end

-- Sexan/ArkaData function
local function DeleteAllEnvelopes(track)
  for i = reaper.CountTrackEnvelopes(track), 1, -1 do
    local env = reaper.GetTrackEnvelope(track, i - 1)
    reaper.SetCursorContext(2, env)
    reaper.Main_OnCommand(40332, 0) -- select all points
    reaper.Main_OnCommand(40333, 0) -- delete all points
    reaper.Main_OnCommand(40065, 0) -- remove env
  end
end

local function DeleteFXinContainer(track, cont_idx)
  local _, fx_cnt = reaper.TrackFX_GetNamedConfigParm(track, cont_idx, 'container_count')
  for i = fx_cnt - 1, 0, -1 do
    local _, fx_id = reaper.TrackFX_GetNamedConfigParm(track, cont_idx, 'container_item.' .. i)
    fx_id = tonumber(fx_id)
    local _, fx_type = reaper.TrackFX_GetNamedConfigParm(track, fx_id, 'fx_type')
    local is_container = fx_type == "Container"

    if is_container then --Call recursively
      DeleteFXinContainer(track, fx_id)
    else
      local is_instrument = fx_type:sub(-1) == 'i'

      if is_instrument and not dupeElements.instruments then
        reaper.TrackFX_Delete(track, fx_id)
      elseif not is_instrument and not dupeElements.fx then
        reaper.TrackFX_Delete(track, fx_id)
      end
    end

    local _, new_fx_cnt = reaper.TrackFX_GetNamedConfigParm(track, cont_idx, 'container_count')
    if tonumber(new_fx_cnt) == 0 then
      reaper.TrackFX_Delete(track, cont_idx)
    end
  end
end

local function DeleteFX(track)
  local fx_cnt = reaper.TrackFX_GetCount(track)
  for i = fx_cnt - 1, 0, -1 do
    local _, fx_type = reaper.TrackFX_GetNamedConfigParm(track, i, 'fx_type')
    local is_container = fx_type == "Container"
    local is_instrument = fx_type:sub(-1) == 'i'


    if is_container then
      DeleteFXinContainer(track, i)
    else
      if is_instrument and not dupeElements.instruments then
        reaper.TrackFX_Delete(track, i)
      elseif not is_instrument and not dupeElements.fx then
        reaper.TrackFX_Delete(track, i)
      end
    end
  end
end

local function DoDuplicateStuff()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(-1)

  local is_first_dupe = true

  for i = 1, dupenum do
    reaper.Main_OnCommand(40062, 0) --Dupe

    local sel_tracks = {}
    for j = 1, reaper.CountSelectedTracks(0) do
      sel_tracks[#sel_tracks + 1] = reaper.GetSelectedTrack(0, j - 1)

      if is_first_dupe then
        -- NON-ACTIVE LANES
        -- Track lanes: Delete lanes (including media items) that are not playing
        if not dupeElements.otherLanes then reaper.Main_OnCommand(42691, 0) end

        -- ACTIVE LANES
        if not dupeElements.activeLane then DeleteActiveLanes(sel_tracks[j]) end

        if not dupeElements.otherLanes and not dupeElements.activeLane then
          reaper.Main_OnCommand(40752, 0) -- Disable lanes
        end

        -- ENVELOPES
        if not dupeElements.envelopes then
          reaper.Main_OnCommand(41148, 0) -- Show All Envelopes on track
          DeleteAllEnvelopes(sel_tracks[j])
        end

        if not dupeElements.fx or not dupeElements.instruments then DeleteFX(sel_tracks[j]) end

        if not dupeElements.sends then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_SENDS6"), 0) end
        if not dupeElements.receives then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_SENDS5"), 0) end
        if not dupeElements.groupAssign then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_REMOVE_TR_GRP"), 0) end
      end

      if dupeElements.renameDupes then
        local _, name = reaper.GetSetMediaTrackInfo_String(sel_tracks[j], 'P_NAME', '', false)
        name = is_first_dupe and name .. '.dup' .. i or name:gsub("%.dup%d+$", ".dup" .. i)
        reaper.GetSetMediaTrackInfo_String(sel_tracks[j], 'P_NAME', name, true)
      end
    end


    for j = 1, #sel_tracks do
      duplicated_tracks[#duplicated_tracks + 1] = sel_tracks[j]
    end

    is_first_dupe = false
  end

  -- Select all duplicated tracks
  for i = 1, #duplicated_tracks do
    reaper.SetTrackSelected(duplicated_tracks[i], true)
  end

  reaper.PreventUIRefresh(1)
  reaper.Undo_EndBlock("Duplicate Tracks " .. dupenum .. " times", 0)
end

local function ReadSettingsFromExtState()
  if not reaper.HasExtState(extstate_section, 'fx') then return end

  for k, v in pairs(dupeElements) do
    local extstate = reaper.GetExtState(extstate_section, k)
    if tonumber(extstate) then
      dupeElements[k] = tonumber(extstate)
    else
      dupeElements[k] = extstate == "true" and true or false
    end
  end
end

local function WriteSettingsToExtState()
  for k, v in pairs(dupeElements) do
    reaper.SetExtState(extstate_section, k, tostring(v), true)
  end
end

local function init()
  ReadSettingsFromExtState()
end

local function main()
  DoDuplicateStuff()
  WriteSettingsToExtState()
end

init()

-- GUI
local config_flags = reaper.ImGui_ConfigFlags_NavEnableKeyboard()
local ctx = reaper.ImGui_CreateContext(script_name, config_flags)
local visible, open
local window_flags = reaper.ImGui_WindowFlags_NoCollapse() |
    reaper.ImGui_WindowFlags_NoResize()   |
    reaper.ImGui_WindowFlags_AlwaysAutoResize()

local font = reaper.ImGui_CreateFont('sans-serif', 12)
reaper.ImGui_Attach(ctx, font)

local first_frame = true

local btn_w = 80

local help_tooltip = [[Alt+Click : Set All
Tab/Shift+Tab : Next/Previous field
Spacebar: Toggle focused thingy
Enter : Duplicate Tracks
Escape : Close

Cmd/Ctrl + first letter of option: Toggle option
(Example: Cmd + F -> Toggle FX)
]]

local inputInt_callback = reaper.ImGui_CreateFunctionFromEEL([[
  ( EventChar >= '0' && EventChar <= '9' ) ? EventChar = EventChar : EventChar = 0;
  Buf == '0' ? Buf = '1';
]])

local function InputInt(label, var)
  var = tostring(var)
  _, var = reaper.ImGui_InputText(ctx, label, var, reaper.ImGui_InputTextFlags_CallbackCharFilter(), inputInt_callback)
  return tonumber(var) or 0
end

local function Checkbox(label, val)
  local _, rv = reaper.ImGui_Checkbox(ctx, label, val)

  if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftAlt()) and reaper.ImGui_IsItemEdited(ctx) then
    for k, v in pairs(dupeElements) do
      dupeElements[k] = rv
    end
  end

  -- Prevent Enter key to switch the checkbox
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) and reaper.ImGui_IsItemFocused(ctx) then
    rv = not rv
  end

  return rv
end




local function DrawCheckboxes()
  reaper.ImGui_Indent(ctx)
  dupeElements.activeLane = Checkbox('Active Lanes', dupeElements.activeLane)
  dupeElements.otherLanes = Checkbox('Non-Active Lanes', dupeElements.otherLanes)
  dupeElements.envelopes = Checkbox('Envelopes', dupeElements.envelopes)

  dupeElements.instruments = Checkbox('Instruments', dupeElements.instruments)
  reaper.ImGui_SameLine(ctx)
  dupeElements.fx = Checkbox('FX', dupeElements.fx)

  dupeElements.sends = Checkbox('Sends', dupeElements.sends)
  reaper.ImGui_SameLine(ctx, nil, 36)
  dupeElements.receives = Checkbox('Receives', dupeElements.receives)
  dupeElements.groupAssign = Checkbox('Group Assignments', dupeElements.groupAssign)
  reaper.ImGui_Unindent(ctx)

  reaper.ImGui_Dummy(ctx, 0, 10)
  dupeElements.renameDupes = Checkbox('Add Label to Track Name', dupeElements.renameDupes)
end

local function DrawOkCancelButtons()
  reaper.ImGui_Dummy(ctx, 0, 10)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, 2)

  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - btn_w * 2 - 15)


  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x5D5D5DAA)
  if reaper.ImGui_Button(ctx, "Cancel", btn_w) then open = false end
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_SameLine(ctx)

  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - btn_w - 10)
  if reaper.ImGui_Button(ctx, "OK", btn_w) then
    main()
    open = false
  end
end

local function DrawHelpTooltip()
  if reaper.ImGui_IsItemHovered(ctx) then
    reaper.ImGui_BeginTooltip(ctx)
    reaper.ImGui_Text(ctx, help_tooltip)
    reaper.ImGui_EndTooltip(ctx)
  end
end

local function HandleShortcuts()
  if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shortcut()) then
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_A()) then dupeElements.activeLane = not dupeElements.activeLane end
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_N()) then dupeElements.otherLanes = not dupeElements.otherLanes end
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_E()) then dupeElements.envelopes = not dupeElements.envelopes end
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_I()) then dupeElements.instruments = not dupeElements.instruments end
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F()) then dupeElements.fx = not dupeElements.fx end
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S()) then dupeElements.sends = not dupeElements.sends end
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_R()) then dupeElements.receives = not dupeElements.receives end
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_G()) then dupeElements.groupAssign = not dupeElements.groupAssign end
  end
end

local function DrawWindow()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 5)

  reaper.ImGui_AlignTextToFramePadding(ctx)
  reaper.ImGui_Text(ctx, "Number of duplicates:")

  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_PushItemWidth(ctx, 100)
  if first_frame then reaper.ImGui_SetKeyboardFocusHere(ctx) end
  dupenum = InputInt('##dupenum', dupenum)
  dupenum = dupenum < 1 and 1 or dupenum

  reaper.ImGui_Dummy(ctx, 0, 10)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, 10)

  reaper.ImGui_Text(ctx, "Data to duplicate:")
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_TextColored(ctx, 0x5D5D5DAA, '[?]')
  DrawHelpTooltip()
  reaper.ImGui_Dummy(ctx, 0, 2)

  DrawCheckboxes()

  DrawOkCancelButtons()

  HandleShortcuts()

  reaper.ImGui_PopStyleVar(ctx) -- Frame rounding
end

local function guiloop()
  reaper.ImGui_SetNextWindowSize(ctx, 240, 330, reaper.ImGui_Cond_FirstUseEver())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 5)
  reaper.ImGui_PushFont(ctx, font)

  visible, open = reaper.ImGui_Begin(ctx, script_name, true, window_flags)
  reaper.ImGui_PopStyleVar(ctx)

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then open = false end
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
    main()
    open = false
  end
  if visible then
    DrawWindow()
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)
  first_frame = false
  if open then
    reaper.defer(guiloop)
  end
end

reaper.defer(guiloop)
