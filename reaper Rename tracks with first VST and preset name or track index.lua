--[[
	homepage:https://github.com/wangandi520/andysluascript
	inherit:https://github.com/X-Raym/REAPER-ReaScripts
 
	v0.1:
	first upload
	2022.12.12
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
