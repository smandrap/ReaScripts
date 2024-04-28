--TODO: GUI
--TODO: implement stevie insert/delete bars
--TODO: Replace bars
--TODO: Refactor ReinterpretBars function into smaller functions
--TODO: prevent startbar input < projmeasoffs

--FIXME: Restore state of "ignore project tempo" on items that precedently had it set
--FIXME: measures are zero based, account for this
--FIXME: override audio items timebase to time?
--FIXME: break if tpos > sec_end (doesn't belong to the current measure)
--FIXME: preserve linear tempo changes at start of measures


local reaper = reaper

local start_bar = -3
local length_in_bars = 3
local target_timesig_num = 3
local target_timesig_denom = 4

local function ReinterpretBars()
  start_bar = start_bar + math.abs(reaper.SNM_GetIntConfigVar('projmeasoffs', 0)) - 1
  local end_bar = start_bar + length_in_bars

  -- Cache measure information
  local tempos = {}
  for i = start_bar, end_bar - 1 do
    local _, _, _, timesig_num, timesig_denom, tempo = reaper.TimeMap_GetMeasureInfo(0, i)
    tempos[i] = {
      timesig_num = timesig_num,
      timesig_denom = timesig_denom,
      tempo = tempo
    }
  end

  -- OVERRIDE TIMEBASES
  local timebase_tempoenv = reaper.SNM_GetIntConfigVar('tempoenvtimelock', -1)
  local timebase_itemmarkers = reaper.SNM_GetIntConfigVar('tempoenvtimelock', -1)
  reaper.SNM_SetIntConfigVar('tempoenvtimelock', 0)
  reaper.SNM_SetIntConfigVar('itemtimelock', 0)

  local sel_items = {}
  local midi_items = {}

  --FIXME: override audio items timebase to time?
  for i = 1, reaper.CountMediaItems(0) do
    local item = reaper.GetMediaItem(0, i - 1)
    if reaper.IsMediaItemSelected(item) then sel_items[#sel_items + 1] = item end
    if reaper.TakeIsMIDI(reaper.GetActiveTake(item)) then midi_items[#midi_items + 1] = item end
  end


  reaper.Main_OnCommand(40289, 0) --unselect all items

  for i = 1, #midi_items do
    reaper.SetMediaItemSelected(midi_items[i], true)
  end

  reaper.Main_OnCommand(43096, 0) -- Set midi item timebase to beats, ignore project tempo

  -- BEGIN
  local tempochange_cnt = reaper.CountTempoTimeSigMarkers(0)

  -- If time is not reinterpreted (bars are already of the target time signature) there's no need to add tempo markers
  local add_final_tempomarker = false

  for i = start_bar, end_bar - 1 do
    local _, qn_start, qn_end, timesig_num, timesig_denom, tempo = reaper.TimeMap_GetMeasureInfo(0, i)

    if timesig_num ~= target_timesig_num then
      add_final_tempomarker = true
      local sec_start = reaper.TimeMap_QNToTime(qn_start)
      local sec_end = reaper.TimeMap_QNToTime(qn_start)
      local target_tempo = tempos[i].tempo * (target_timesig_num / target_timesig_denom) / (timesig_num / timesig_denom)

      --FIXME: preserve linear tempo changes
      --local _, _, _, _, _, _, _, is_linear = reaper.GetTempoTimeSigMarker(0, j)

      reaper.SetTempoTimeSigMarker(0, -1, -1, i, 0, target_tempo, i == start_bar and target_timesig_num or 0,
        i == start_bar and target_timesig_denom or 0, false)

      -- Scale all tempo markers in this measure
      for j = 0, tempochange_cnt - 1 do
        --FIXME: break if tpos > sec_end (doesn't belong to the current measure)
        local _, tpos, measpos, beatpos, bpm, ts_num, ts_denom, lin = reaper.GetTempoTimeSigMarker(0, j)
        local is_in_current_measure = (measpos == i) and (tpos > sec_start) and (tpos < sec_end)

        if is_in_current_measure then
          local scaled_tempo = bpm * (target_timesig_num / target_timesig_denom) / (ts_num / ts_denom)
          reaper.SetTempoTimeSigMarker(0, j, tpos, -1, -1, scaled_tempo, -1, -1, lin)
        end
      end
    end
  end

  -- Restore whatever is needed at end, but only if some stuff were altered
  if add_final_tempomarker then
    local last_tmrk = tempos[end_bar - 1] -- index [end_bar - 1] is the last tempo_marker in table
    reaper.SetTempoTimeSigMarker(0, -1, -1, end_bar, 0, last_tmrk.tempo, last_tmrk.timesig_num,
      last_tmrk.timesig_denom, false)
  end

  -- RESTORE TIMEBASE AND SELECTIONS
  reaper.Main_OnCommand(40289, 0) --unselect all items

  for i = 1, #sel_items do
    reaper.SetMediaItemSelected(sel_items[i], true)
  end

  reaper.SNM_SetIntConfigVar('tempoenvtimelock', timebase_tempoenv)
  reaper.SNM_SetIntConfigVar('itemtimelock', timebase_itemmarkers)

  reaper.UpdateTimeline()
end

reaper.Undo_BeginBlock()
ReinterpretBars()
reaper.Undo_EndBlock("Reinterpret Bars", -1)
