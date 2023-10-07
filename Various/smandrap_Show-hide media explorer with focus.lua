-- @description Media Explorer: Show/hide media explorer with focus
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--  Opens media explorer window and sets focus to it immediately.
--  Requires JS Api

local reaper = reaper

local function dependency_check()
  if not reaper.JS_ReaScriptAPI_Version() then
    local mb = reaper.MB('This script needs JS_API. You want to install it now?', 'Missing dependency', 1)
    if mb == 2 then return false end
    
    if not reaper.APIExists('ReaPack_BrowsePackages') then
      mb = reaper.MB('https://reapack.com/', 'Get ReaPack first.', 0)
      return false
    end
    
    reaper.ReaPack_BrowsePackages('js_ReaScript API')
  end
  
  return true
end


local function main()
  reaper.Main_OnCommand(50124, 0)
  if reaper.GetToggleCommandState(50124) == 1 then
    
    local hwnd = reaper.JS_Window_Find("Media Explorer", false)
    reaper.JS_Window_SetFocus(hwnd)
  
  end
end

if dependency_check() then main() end
