-- @description Options: Toggle show faint peaks in automation envelope lanes
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Toggles Preferences > Peaks/Waveforms > Draw faint peaks in automation envelope lanes. Requires SWS.


local envlanes_flags = reaper.SNM_GetIntConfigVar('envlanes', -1)
local faintpeaks = envlanes_flags & 4 == 4

reaper.SNM_SetIntConfigVar('envlanes', faintpeaks and envlanes_flags & ~4 or envlanes_flags | 4)
reaper.UpdateArrange()
