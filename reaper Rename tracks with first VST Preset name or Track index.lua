--[[
 * ReaScript Name: Rename tracks with first VST and preset name or track index
 * Instructions: Select tracks and run
 * Author: wangandi520
 * Author Homepage: https://github.com/wangandi520/andysluascript
 * Inherited and inspired: https://github.com/X-Raym/REAPER-ReaScripts/blob/master/Track%20Properties/X-Raym_Rename%20tracks%20with%20first%20VSTi%20and%20its%20preset%20name.lua
 * REAPER: 6.71
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2022-12-12)
 	+ Initial Release
--]]

function toInt(num)
    local s = tostring(num)
    local i, j = s:find('%.')
    if i then
        return tonumber(s:sub(1, i-1))
    else
        return num
    end
end

function main()
	for i = 0, tracks_count - 1 do
		getSelectedTrack = reaper.GetSelectedTrack(0, i)
		getTrackIndex = reaper.GetMediaTrackInfo_Value(getSelectedTrack, 'IP_TRACKNUMBER')
		retvalFX, fxName = reaper.TrackFX_GetFXName(getSelectedTrack, 0)
	
		if retvalFX then
			getIndex = string.find(fxName,": ")
			fxName = string.sub(fxName, getIndex + 1)
			fxName = fxName:gsub(" %(.-%)", "")
		end
		
		retvalPreset, presetName = reaper.TrackFX_GetPreset(getSelectedTrack, 0, "")
		
		if string.len(presetName) == 0 then
			retvalPreset = false
			presetName = nil
		end
		
		if retvalFX and retvalPreset then
			trackNameRetval, trackName = reaper.GetSetMediaTrackInfo_String(getSelectedTrack, "P_NAME", fxName .. " - " .. presetName, true)
		elseif retvalFX and not retvalPreset then
			trackNameRetval, trackName = reaper.GetSetMediaTrackInfo_String(getSelectedTrack, "P_NAME", fxName, true)
		elseif not retvalFX and not retvalPreset then
			trackNameRetval, trackName = reaper.GetSetMediaTrackInfo_String(getSelectedTrack, "P_NAME", "", false)
			if string.len(trackName) == 0 then
				trackNameRetval, trackName = reaper.GetSetMediaTrackInfo_String(getSelectedTrack, "P_NAME", "Track" .. string.format("%03d",toInt(getTrackIndex)), true)
			end
		end
	end
end

tracks_count = reaper.CountSelectedTracks(0)

if tracks_count > 0 then
	reaper.PreventUIRefresh(1)
	reaper.Undo_BeginBlock()
	
	main()
	
	reaper.Undo_EndBlock("Rename tracks with first VSTi and its preset name", -1)
	reaper.PreventUIRefresh(-1)
end
