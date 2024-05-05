-- @description Duplicate Tracks
-- @author smandrap
-- @version 1.5.3
-- @changelog
--    # Update to ReaImGui 0.9
--    # Support using Numpad Enter key for Apply
-- @donation https://paypal.me/smandrap
-- @about
--   Pro Tools style Duplicate Tracks window

local r = reaper
local script_name = "Duplicate Tracks"

local reaper_version = tonumber(string.sub(r.GetAppVersion(), 0, 4))
if reaper_version < 7.03 then
  r.MB('REAPER v7.03 or later is required to run this script.\n Update from website.', 'Wrong REAPER Version', 0)
end

if not r.ImGui_GetVersion then
  local ok = r.MB('Install now?\n\n(REAPER restart is required after install)', 'ReaImGui Missing', 1)
  if ok == 1 then r.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

if not r.CF_GetSWSVersion then
  local ok = r.MB('Install now?\n\n(REAPER restart is required after install)', 'SWS Extensions Missing', 1)
  if ok == 1 then r.ReaPack_BrowsePackages("SWS Extensions") end
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

-- APP

r.set_action_options(3)

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
  local numlanes = r.GetMediaTrackInfo_Value(track, 'I_NUMFIXEDLANES')
  local itm_cnt = r.CountTrackMediaItems(track)
  local itm_toDelete = {}

  local playingLanes = {}

  for i = 0, numlanes - 1 do
    local laneplays = r.GetMediaTrackInfo_Value(track, 'C_LANEPLAYS:' .. i)
    playingLanes[i] = laneplays > 0 and true or false
  end

  for i = 0, itm_cnt - 1 do
    local itm = r.GetTrackMediaItem(track, i)
    local itm_lane = r.GetMediaItemInfo_Value(itm, 'I_FIXEDLANE')

    if playingLanes[itm_lane] == true then
      itm_toDelete[#itm_toDelete + 1] = itm
    end
  end

  for i = 1, #itm_toDelete do
    r.DeleteTrackMediaItem(track, itm_toDelete[i])
  end

  r.Main_OnCommand(42689, 0) -- Track lanes: Delete lanes with no media items
end


-- This is better but API has bug
local function DeleteActiveLanes(track)
  --local track = r.GetTrack(0, 0)
  if not r.ValidatePtr(track, "MediaTrack*") then return end

  local numlanes = r.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")

  if numlanes == 1 then
    if r.GetMediaTrackInfo_Value(track, "C_LANEPLAYS:0") > 0 then
      for i = r.CountTrackMediaItems(track) - 1, 0, -1 do
        r.DeleteTrackMediaItem(track, r.GetTrackMediaItem(track, i))
      end
    end
    return
  end

  for i = 0, numlanes - 1 do
    local laneplays = r.GetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i)
    r.SetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i, laneplays == 0 and 2 or 0)
  end

  r.Main_OnCommand(42691, 0) --Track lanes: Delete lanes (including media items) that are not playing

  numlanes = r.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  for i = 0, numlanes - 1 do
    r.SetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i, 0)
  end
end

-- Sexan/ArkaData function
local function DeleteAllEnvelopes(track)
  for i = r.CountTrackEnvelopes(track), 1, -1 do
    local env = r.GetTrackEnvelope(track, i - 1)
    r.SetCursorContext(2, env)
    r.Main_OnCommand(40332, 0) -- select all points
    r.Main_OnCommand(40333, 0) -- delete all points
    r.Main_OnCommand(40065, 0) -- remove env
  end
end

local function DeleteFXinContainer(track, cont_idx)
  local _, fx_cnt = r.TrackFX_GetNamedConfigParm(track, cont_idx, 'container_count')
  for i = fx_cnt - 1, 0, -1 do
    local _, fx_id = r.TrackFX_GetNamedConfigParm(track, cont_idx, 'container_item.' .. i)
    fx_id = tonumber(fx_id)
    local _, fx_type = r.TrackFX_GetNamedConfigParm(track, fx_id, 'fx_type')
    local is_container = fx_type == "Container"

    if is_container then --Call recursively
      DeleteFXinContainer(track, fx_id)
    else
      local is_instrument = fx_type:sub(-1) == 'i'

      if is_instrument and not dupeElements.instruments then
        r.TrackFX_Delete(track, fx_id)
      elseif not is_instrument and not dupeElements.fx then
        r.TrackFX_Delete(track, fx_id)
      end
    end

    local _, new_fx_cnt = r.TrackFX_GetNamedConfigParm(track, cont_idx, 'container_count')
    if tonumber(new_fx_cnt) == 0 then
      r.TrackFX_Delete(track, cont_idx)
    end
  end
end

local function DeleteFX(track)
  local fx_cnt = r.TrackFX_GetCount(track)
  for i = fx_cnt - 1, 0, -1 do
    local _, fx_type = r.TrackFX_GetNamedConfigParm(track, i, 'fx_type')
    local is_container = fx_type == "Container"
    local is_instrument = fx_type:sub(-1) == 'i'


    if is_container then
      DeleteFXinContainer(track, i)
    else
      if is_instrument and not dupeElements.instruments then
        r.TrackFX_Delete(track, i)
      elseif not is_instrument and not dupeElements.fx then
        r.TrackFX_Delete(track, i)
      end
    end
  end
end

local function DoDuplicateStuff()
  r.Undo_BeginBlock()
  r.PreventUIRefresh(-1)

  local is_first_dupe = true

  for i = 1, dupenum do
    r.Main_OnCommand(40062, 0) --Dupe

    local sel_tracks = {}
    for j = 1, r.CountSelectedTracks(0) do
      sel_tracks[#sel_tracks + 1] = r.GetSelectedTrack(0, j - 1)

      if is_first_dupe then
        -- NON-ACTIVE LANES
        -- Track lanes: Delete lanes (including media items) that are not playing
        if not dupeElements.otherLanes then
          r.Main_OnCommand(42691, 0)
        end

        -- ACTIVE LANES
        if not dupeElements.activeLane then
          DeleteActiveLanes(sel_tracks[j])
        end

        if not dupeElements.otherLanes and not dupeElements.activeLane then
          r.Main_OnCommand(40752, 0) -- Disable lanes
        end


        -- If only one lane is left and it's playing then disable lanes
        if r.GetMediaTrackInfo_Value(sel_tracks[j], "I_NUMFIXEDLANES") == 1 and
            r.GetMediaTrackInfo_Value(sel_tracks[j], "C_LANEPLAYS:0") > 0 then
          r.Main_OnCommand(40752, 0) -- Disable lanes
        end

        -- ENVELOPES
        if not dupeElements.envelopes then
          r.Main_OnCommand(41148, 0) -- Show All Envelopes on track
          DeleteAllEnvelopes(sel_tracks[j])
        end

        if not dupeElements.fx or not dupeElements.instruments then DeleteFX(sel_tracks[j]) end

        if not dupeElements.sends then r.Main_OnCommand(r.NamedCommandLookup("_S&M_SENDS6"), 0) end
        if not dupeElements.receives then r.Main_OnCommand(r.NamedCommandLookup("_S&M_SENDS5"), 0) end
        if not dupeElements.groupAssign then r.Main_OnCommand(r.NamedCommandLookup("_S&M_REMOVE_TR_GRP"), 0) end
      end

      if dupeElements.renameDupes then
        local _, name = r.GetSetMediaTrackInfo_String(sel_tracks[j], 'P_NAME', '', false)
        name = is_first_dupe and name .. '.dup' .. i or name:gsub("%.dup%d+$", ".dup" .. i)
        r.GetSetMediaTrackInfo_String(sel_tracks[j], 'P_NAME', name, true)
      end
    end


    for j = 1, #sel_tracks do
      duplicated_tracks[#duplicated_tracks + 1] = sel_tracks[j]
    end

    is_first_dupe = false
  end

  -- Select all duplicated tracks
  for i = 1, #duplicated_tracks do
    r.SetTrackSelected(duplicated_tracks[i], true)
  end

  r.PreventUIRefresh(1)
  r.Undo_EndBlock("Duplicate Tracks " .. dupenum .. " times", 0)
end

local function ReadSettingsFromExtState()
  if not r.HasExtState(extstate_section, 'fx') then return end

  for k, v in pairs(dupeElements) do
    local extstate = r.GetExtState(extstate_section, k)
    if tonumber(extstate) then
      dupeElements[k] = tonumber(extstate)
    else
      dupeElements[k] = extstate == "true" and true or false
    end
  end
end

local function WriteSettingsToExtState()
  for k, v in pairs(dupeElements) do
    r.SetExtState(extstate_section, k, tostring(v), true)
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
local config_flags = ImGui.ConfigFlags_NavEnableKeyboard
local ctx = ImGui.CreateContext(script_name, config_flags)
local visible, open
local window_flags = ImGui.WindowFlags_NoCollapse |
    ImGui.WindowFlags_NoResize   |
    ImGui.WindowFlags_AlwaysAutoResize

local font = ImGui.CreateFont('sans-serif', 12)
ImGui.Attach(ctx, font)

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

local inputInt_callback = ImGui.CreateFunctionFromEEL([[
  ( EventChar >= '0' && EventChar <= '9' ) ? EventChar = EventChar : EventChar = 0;
  Buf == '0' ? Buf = '1';
]])

local function InputInt(label, var)
  var = tostring(var)
  _, var = ImGui.InputText(ctx, label, var, ImGui.InputTextFlags_CallbackCharFilter, inputInt_callback)
  return tonumber(var) or 0
end

local function Checkbox(label, val)
  local _, rv = ImGui.Checkbox(ctx, label, val)

  if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) and ImGui.IsItemEdited(ctx) then
    for k, v in pairs(dupeElements) do
      dupeElements[k] = rv
    end
  end

  -- Prevent Enter key to switch the checkbox
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) and ImGui.IsItemFocused(ctx) then
    rv = not rv
  end

  return rv
end




local function DrawCheckboxes()
  ImGui.Indent(ctx)
  dupeElements.activeLane = Checkbox('Active Lanes', dupeElements.activeLane)
  dupeElements.otherLanes = Checkbox('Non-Active Lanes', dupeElements.otherLanes)
  dupeElements.envelopes = Checkbox('Envelopes', dupeElements.envelopes)

  dupeElements.instruments = Checkbox('Instruments', dupeElements.instruments)
  ImGui.SameLine(ctx)
  dupeElements.fx = Checkbox('FX', dupeElements.fx)

  dupeElements.sends = Checkbox('Sends', dupeElements.sends)
  ImGui.SameLine(ctx, nil, 36)
  dupeElements.receives = Checkbox('Receives', dupeElements.receives)
  dupeElements.groupAssign = Checkbox('Group Assignments', dupeElements.groupAssign)
  ImGui.Unindent(ctx)

  ImGui.Dummy(ctx, 0, 10)
  dupeElements.renameDupes = Checkbox('Add Label to Track Name', dupeElements.renameDupes)
end

local function DrawOkCancelButtons()
  ImGui.Dummy(ctx, 0, 10)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 2)

  ImGui.SetCursorPosX(ctx, ImGui.GetWindowWidth(ctx) - btn_w * 2 - 15)


  ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x5D5D5DAA)
  if ImGui.Button(ctx, "Cancel", btn_w) then open = false end
  ImGui.PopStyleColor(ctx)
  ImGui.SameLine(ctx)

  ImGui.SetCursorPosX(ctx, ImGui.GetWindowWidth(ctx) - btn_w - 10)
  if ImGui.Button(ctx, "OK", btn_w) then
    main()
    open = false
  end
end

local function DrawHelpTooltip()
  if ImGui.IsItemHovered(ctx) then
    _ = ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, help_tooltip)
    ImGui.EndTooltip(ctx)
  end
end

local function HandleShortcuts()
  if ImGui.IsKeyDown(ctx, ImGui.Mod_Shortcut) then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_A) then dupeElements.activeLane = not dupeElements.activeLane end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_N) then dupeElements.otherLanes = not dupeElements.otherLanes end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_E) then dupeElements.envelopes = not dupeElements.envelopes end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_I) then dupeElements.instruments = not dupeElements.instruments end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_F) then dupeElements.fx = not dupeElements.fx end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_S) then dupeElements.sends = not dupeElements.sends end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_R) then dupeElements.receives = not dupeElements.receives end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_G) then dupeElements.groupAssign = not dupeElements.groupAssign end
  end
end

local function DrawWindow()
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 5)

  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, "Number of duplicates:")

  ImGui.SameLine(ctx)
  ImGui.PushItemWidth(ctx, 100)
  if first_frame then ImGui.SetKeyboardFocusHere(ctx) end
  dupenum = InputInt('##dupenum', dupenum)
  dupenum = dupenum < 1 and 1 or dupenum

  ImGui.Dummy(ctx, 0, 10)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 10)

  ImGui.Text(ctx, "Data to duplicate:")
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, 0x5D5D5DAA, '[?]')
  DrawHelpTooltip()
  ImGui.Dummy(ctx, 0, 2)

  DrawCheckboxes()

  DrawOkCancelButtons()

  HandleShortcuts()

  ImGui.PopStyleVar(ctx) -- Frame rounding
end

local function guiloop()
  ImGui.SetNextWindowSize(ctx, 240, 330, ImGui.Cond_FirstUseEver)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 5)
  ImGui.PushFont(ctx, font)

  visible, open = ImGui.Begin(ctx, script_name, true, window_flags)
  ImGui.PopStyleVar(ctx)

  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then open = false end
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter) then
    main()
    open = false
  end
  if visible then
    DrawWindow()
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)
  first_frame = false
  if open then
    r.defer(guiloop)
  end
end

r.defer(guiloop)
