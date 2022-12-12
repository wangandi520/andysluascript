--[[
 inherit:https://github.com/X-Raym/REAPER-ReaScripts
 v0.1:
 first upload
 2022.12.12
--]]

function toint(num)
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
    retval0, fx_name = reaper.TrackFX_GetFXName(getSelectedTrack, 0, "")
	if retval0 then
		getIndex = string.find(fx_name,": ")
		fx_name = string.sub(fx_name, getIndex + 1)
		fx_name = fx_name:gsub(" %(.-%)", "")
	end
    -- fx_name = fx_name:gsub("VSTi: ", "")
    -- fx_name = fx_name:gsub("VST: ", "")
    -- fx_name = fx_name:gsub("AU: ", "")
    -- fx_name = fx_name:gsub("AUi: ", "")
    -- fx_name = fx_name:gsub("VST3i: ", "")
    -- fx_name = fx_name:gsub("VST3: ", "")
    -- fx_name = fx_name:gsub("JS: ", "")
    -- fx_name = fx_name:gsub("DX: ", "")
    -- fx_name = fx_name:gsub(" %(.-%)", "")

    --retval, presetname = reaper.TrackFX_GetPreset(track, vsti_id, "")
   -- retval1, presetname = reaper.TrackFX_GetPreset(track, 0, "")
	--result0 = fx_name and "true" or "false"
    --reaper.ShowConsoleMsg(result0)
    --reaper.ShowConsoleMsg(presetname)
	--result1 = retval1 and "true" or "false"
    retval1, presetname = reaper.TrackFX_GetPreset(getSelectedTrack, 0, "")
	
	if string.len(presetname) == 0 then
		retval1 = false
		presetname = nil
	end
	
    if retval0 and retval1 then
      track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(getSelectedTrack, "P_NAME",
        fx_name .. " - " .. presetname, true)
    elseif retval0 and not retval1 then
        track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(getSelectedTrack, "P_NAME", fx_name, true)
    elseif not retval0 and not retval1 then
        track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(getSelectedTrack, "P_NAME", "Track" .. string.format("%03d",toint(getTrackIndex)), true)
    end
  end
end

-- INIT
tracks_count = reaper.CountSelectedTracks(0)

if tracks_count > 0 then

  reaper.PreventUIRefresh(1)

  reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.

  main()

  reaper.Undo_EndBlock("Rename tracks with first VSTi and its preset name", -1) -- End of the undo block. Leave it at the bottom of your main function.

  reaper.PreventUIRefresh(-1)

end
