--TODO: GUI
--TODO: implement stevie insert/delete bars
--TODO: Replace bars
--TODO: Refactor ReinterpretBars function into smaller functions
--TODO: prevent startbar input < projmeasoffs

--FIXME: Restore state of "ignore project tempo" on items that precedently had it set
--FIXME: measures are zero based, account for this
--FIXME: override audio items timebase to time?
--FIXME: break if tpos > sec_end (doesn't belong to the current measure)
--FIXME: preserved tempo changes at end of op range


local r = reaper

local start_bar = 1
local length_in_bars = 3
local target_timesig_num = 3
local target_timesig_denom = 4

local function ReinterpretBars()
  -- OVERRIDE TIMEBASES
  local timebase_tempoenv = r.SNM_GetIntConfigVar('tempoenvtimelock', -1)
  local timebase_itemmarkers = r.SNM_GetIntConfigVar('tempoenvtimelock', -1)
  r.SNM_SetIntConfigVar('tempoenvtimelock', 0)
  r.SNM_SetIntConfigVar('itemtimelock', 0)

  local sel_items = {}
  local midi_items = {}

  --FIXME: override audio items timebase to time?
  for i = 1, r.CountMediaItems(0) do
    local item = r.GetMediaItem(0, i - 1)
    if r.IsMediaItemSelected(item) then sel_items[#sel_items + 1] = item end
    if r.TakeIsMIDI(r.GetActiveTake(item)) then midi_items[#midi_items + 1] = item end
  end


  r.Main_OnCommand(40289, 0) --unselect all items

  for i = 1, #midi_items do
    r.SetMediaItemSelected(midi_items[i], true)
  end

  r.Main_OnCommand(43096, 0) -- Set midi item timebase to beats, ignore project tempo

  -- BEGIN
  start_bar = start_bar + math.abs(r.SNM_GetIntConfigVar('projmeasoffs', 0)) - 1
  local end_bar = start_bar + length_in_bars

  -- Cache measure information
  local USE_PREVIOUS_TIMESIG = 0 --named constant for "use previous numerator/denominator"

  local tempos = {}
  for i = start_bar, end_bar - 1 do
    local _, _, _, timesig_num, timesig_denom, tempo = r.TimeMap_GetMeasureInfo(0, i)
    tempos[i] = {
      timesig_num = timesig_num,
      timesig_denom = timesig_denom,
      tempo = tempo
    }
  end
  local tempochange_cnt = r.CountTempoTimeSigMarkers(0)

  -- If time is not reinterpreted (bars are already of the target time signature) there's no need to add tempo markers
  local add_final_tempomarker = false

  for i = start_bar, end_bar - 1 do
    local _, qn_start, qn_end, timesig_num, timesig_denom, tempo = r.TimeMap_GetMeasureInfo(0, i)
    local sec_start = r.TimeMap_QNToTime(qn_start)
    local sec_end = r.TimeMap_QNToTime(qn_end)

    if timesig_num ~= target_timesig_num then
      add_final_tempomarker = true
      -- local target_tempo = tempos[i].tempo * (target_timesig_num / target_timesig_denom) / (timesig_num / timesig_denom)
      local target_tempo = tempos[i].tempo * (target_timesig_num / target_timesig_denom) * (timesig_denom / timesig_num)

      --FIXME: preserve linear tempo changes
      local found, _, _, _, _, _, _, is_linear = r.GetTempoTimeSigMarker(0,
        r.FindTempoTimeSigMarker(0, sec_start))
      local num = i == start_bar and target_timesig_num or USE_PREVIOUS_TIMESIG
      local denom = i == start_bar and target_timesig_denom or USE_PREVIOUS_TIMESIG
      r.SetTempoTimeSigMarker(0, -1, -1, i, 0, target_tempo, num, denom, found and is_linear or false)
    end


    -- Scale all tempo markers in this measure
    for j = 0, tempochange_cnt do
      --FIXME: break if tpos > sec_end (doesn't belong to the current measure)
      local _, tpos, measpos, beatpos, bpm, ts_num, ts_denom, lin = r.GetTempoTimeSigMarker(0, j)
      local is_in_current_measure = (measpos == i) and (tpos > sec_start) and (tpos < sec_end)
      if is_in_current_measure then
        -- local scaled_tempo = bpm * (target_timesig_num / target_timesig_denom) / (ts_num / ts_denom)
        local scaled_tempo = bpm * (target_timesig_num / target_timesig_denom) * (ts_denom / ts_num)
        r.SetTempoTimeSigMarker(0, j, tpos, -1, -1, scaled_tempo, USE_PREVIOUS_TIMESIG, USE_PREVIOUS_TIMESIG, lin)
      end
    end
  end

  -- Restore whatever is needed at end, but only if some stuff were altered
  if add_final_tempomarker then
    local last_tmrk = tempos[end_bar - 1] -- index [end_bar - 1] is the last tempo_marker in table
    r.SetTempoTimeSigMarker(0, -1, -1, end_bar, 0, last_tmrk.tempo, last_tmrk.timesig_num, last_tmrk.timesig_denom, false)
  end

  -- RESTORE TIMEBASE AND SELECTIONS
  r.Main_OnCommand(40289, 0) --unselect all items

  for i = 1, #sel_items do
    r.SetMediaItemSelected(sel_items[i], true)
  end

  r.SNM_SetIntConfigVar('tempoenvtimelock', timebase_tempoenv)
  r.SNM_SetIntConfigVar('itemtimelock', timebase_itemmarkers)

  r.UpdateTimeline()
end

r.Undo_BeginBlock()
ReinterpretBars()
r.Undo_EndBlock("Reinterpret Bars", -1)
