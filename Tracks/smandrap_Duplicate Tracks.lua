-- @description Duplicate Tracks
-- @author smandrap
-- @version 1.0.2
-- @changelog
--    # Set duplicated tracks as selected after duplication
-- @donation https://paypal.me/smandrap
-- @about
--   Pro Tools style Duplicate Tracks window

local reaper = reaper
local script_name = "Duplicate Tracks"

if not reaper.ImGui_GetVersion() then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

-- APP

reaper.set_action_options(3)

local _ = nil
local dupenum = 1

local activeLane = true
local otherLanes = true
local envelopes = true
local fx = true
local instruments = true
local sends = true
local receives = true
local groupAssign = true

local duplicated_tracks = {}

local insertLastSel = false

local function DeleteActiveLanes()
  local track = reaper.GetTrack(0, 0)
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

local function DoDuplicateStuff()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(-1)
  for i = 1, dupenum do
    reaper.Main_OnCommand(40062, 0) --Dupe

    local sel_tracks = {}
    for j = 0, reaper.CountSelectedTracks(0) - 1 do
      sel_tracks[#sel_tracks + 1] = reaper.GetSelectedTrack(0, j)
    end

    -- TODO: ACTIVE LANES (bug in API)
    --[[ if not activeLane then
      DeleteActiveLanes()
    end ]]

    -- NON-ACTIVE LANES
    --Track lanes: Delete lanes (including media items) that are not playing
    if not otherLanes then reaper.Main_OnCommand(42691, 0) end

    -- ENVELOPES
    if not envelopes then
      reaper.Main_OnCommand(41148, 0) -- Show All Envelopes on track
      for j = 1, #sel_tracks do
        DeleteAllEnvelopes(sel_tracks[j])
      end
    end


    if not fx then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_CLRFXCHAIN3"), 0) end
    if not sends then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_SENDS6"), 0) end
    if not receives then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_SENDS5"), 0) end
    if not groupAssign then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_REMOVE_TR_GRP"), 0) end

    for j = 1, #sel_tracks do
      duplicated_tracks[#duplicated_tracks + 1] = sel_tracks[j]
    end
  end

  -- Select all duplicated tracks
  for i = 1, #duplicated_tracks do
    reaper.SetTrackSelected(duplicated_tracks[i], true)
  end

  reaper.PreventUIRefresh(1)
  reaper.Undo_EndBlock("Duplicate Tracks " .. dupenum .. " times", 0)
end



-- GUI

local ctx = reaper.ImGui_CreateContext(script_name)
local visible, open
local window_flags = reaper.ImGui_WindowFlags_NoCollapse() |
    reaper.ImGui_WindowFlags_NoResize()   |
    reaper.ImGui_WindowFlags_AlwaysAutoResize()
local btn_w = 80
local first_frame = true
local font = reaper.ImGui_CreateFont('sans-serif', 12)
reaper.ImGui_Attach(ctx, font)

local function DrawWindow()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 5)

  reaper.ImGui_AlignTextToFramePadding(ctx)
  reaper.ImGui_Text(ctx, "Number of duplicates:")

  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_PushItemWidth(ctx, 100)
  if first_frame then reaper.ImGui_SetKeyboardFocusHere(ctx) end
  _, dupenum = reaper.ImGui_InputInt(ctx, '##dupenum', dupenum, 0)
  dupenum = dupenum < 1 and 1 or dupenum

  reaper.ImGui_Dummy(ctx, 0, 10)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, 10)

  reaper.ImGui_Text(ctx, "Data to duplicate")

  reaper.ImGui_Indent(ctx)

  --_, activeLane = reaper.ImGui_Checkbox(ctx, 'Active Lane', activeLane)
  _, otherLanes = reaper.ImGui_Checkbox(ctx, 'Non-Active Lanes', otherLanes)
  _, envelopes = reaper.ImGui_Checkbox(ctx, 'Envelopes', envelopes)
  _, fx = reaper.ImGui_Checkbox(ctx, 'FX', fx)
  --_, instruments = reaper.ImGui_Checkbox(ctx, 'Instruments', instruments)
  _, sends = reaper.ImGui_Checkbox(ctx, 'Sends', sends)
  _, receives = reaper.ImGui_Checkbox(ctx, 'Receives', receives)
  _, groupAssign = reaper.ImGui_Checkbox(ctx, 'Group Assignments', groupAssign)

  reaper.ImGui_Unindent(ctx)

  --reaper.ImGui_Dummy(ctx, 0, 20)
  --_, insertLastSel = reaper.ImGui_Checkbox(ctx, 'Insert after last selected track', insertLastSel)


  reaper.ImGui_Dummy(ctx, 0, 10)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, 2)

  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - btn_w * 2 - 15)

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x5D5D5DAA)
  if reaper.ImGui_Button(ctx, "Cancel", btn_w) then open = false end
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_SameLine(ctx)

  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - btn_w - 10)
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_Button(ctx, "OK", btn_w) then
    DoDuplicateStuff()
    open = false
  end

  reaper.ImGui_PopStyleVar(ctx) -- Frame rounding
end

local function guiloop()
  reaper.ImGui_SetNextWindowSize(ctx, 240, 330, reaper.ImGui_Cond_FirstUseEver())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 5)
  reaper.ImGui_PushFont(ctx, font)

  visible, open = reaper.ImGui_Begin(ctx, script_name, true, window_flags)
  reaper.ImGui_PopStyleVar(ctx)

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then open = false end

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
