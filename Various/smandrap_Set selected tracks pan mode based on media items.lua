-- @description Set selected tracks pan mode based on media items
-- @author smandrap
-- @version 1.0
-- @about
--   Set the track to the appropriate pan mode based on the items in the track.
-- 
--   #### Examples: 
--   - Track has only mono media -> Pan Mode: Stereo Balance
--   - Track has stereo media    -> Pan Mode: Stereo Pan
--   - Track has both            -> Pan Mode: Stereo Pan
--
--   Choice between Stereo Pan/Dual Pan in script user area

-------------------------------------------------------------
----------------------    USER AREA   -----------------------
-------------------------------------------------------------


local DUAL_PAN = false -- Set to true to use dual pan mode for track with stereo media


-------------------------------------------------------------
-------------------------------------------------------------


local reaper = reaper

local function process_items_on_track(track)
  local item_cnt = reaper.CountTrackMediaItems(track) - 1
  if item_cnt == -1 then return end
  
  local item
  local take
  local src
  local num_chan
  local chan_mode
  
  for i = 0, item_cnt do

    item = reaper.GetTrackMediaItem(track, i)
    take = reaper.GetActiveTake(item)
    src = reaper.GetMediaItemTake_Source(take)
    
    num_chan = reaper.GetMediaSourceNumChannels(src)
    chan_mode = reaper.GetMediaItemTakeInfo_Value(take, 'I_CHANMODE')
     
    if num_chan > 1 and chan_mode < 2 then
      -- Stereo thing found
      reaper.SetMediaTrackInfo_Value(track, 'I_PANMODE', DUAL_PAN and 6 or 5)
      return
    end
    
  end
  
  -- All items are mono
  reaper.SetMediaTrackInfo_Value(track, 'I_PANMODE', 3)
end


local function main()
  local sel_tr_cnt = reaper.CountSelectedTracks() - 1
  if sel_tr_cnt == -1 then return end
  
  for i = 0, sel_tr_cnt do
    process_items_on_track(reaper.GetSelectedTrack(0, i))
  end
  
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Set selected tracks pan mode based on media items", -1)
