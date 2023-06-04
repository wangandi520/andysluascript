--[[
 * ReaScript Name: reaper Show chord and note in window
 * Author: wangandi520
 * Author Homepage: https://github.com/wangandi520/andysluascript
 * Inherited and inspired: Lil Chordbox 1.6.4 https://github.com/iliaspoulakis/Reaper-Tools/blob/master/MIDI%20editor/Lil%20Chordbox.lua
 * REAPER: 6.71
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2022-12-13)
 	+ Initial Release
--]]

local box_x_offs = 0
local box_y_offs = 0
local box_w_offs = 0
local box_h_offs = 0

local notes_view
local piano_pane

local curr_chords
local curr_sel_chord
local curr_scale_intervals
local curr_start_time
local curr_end_time

local input_timer
local input_note_map = {}
local input_note_cnt = 0

local prev_hwnd
local prev_hash
local prev_take
local prev_mode
local prev_time
local prev_input_idx
local prev_piano_pane_w
local prev_cursor_pos
local prev_chord_name
local prev_color_theme
local prev_mouse_state
local prev_play_state
local prev_input_chord_name
local prev_is_key_snap
local prev_midi_scale_root
local prev_midi_scale
local prev_item_chunk

local scale
local font_size
local bitmap
local lice_font

local bm_x, bm_y, bm_w, bm_h

-- Check if js_ReaScriptAPI extension is installed
if not reaper.JS_Window_SetPosition then
    reaper.MB('Please install js_ReaScriptAPI extension', 'Error', 0)
    return
end

-- Check REAPER version
local version = tonumber(reaper.GetAppVersion():match('[%d.]+'))
if version < 6.4 then
    reaper.MB('Please install REAPER v6.40 or later', 'Error', 0)
    return
end

local _, _, sec, cmd = reaper.get_action_context()

local extname = 'FTC.LilChordBox'

local user_bg_color = reaper.GetExtState(extname, 'bg_color')
local user_border_color = reaper.GetExtState(extname, 'border_color')
local user_text_color = reaper.GetExtState(extname, 'text_color')
local user_sel_color = reaper.GetExtState(extname, 'sel_color')
local user_play_color = reaper.GetExtState(extname, 'play_color')
local user_rec_color = reaper.GetExtState(extname, 'rec_color')

local os = reaper.GetOS()
local is_windows = os:match('Win')
local is_macos = os:match('OSX') or os:match('macOS')
local is_linux = os:match('Other')

local piano_pane_scale1_w = is_windows and 128 or is_macos and 145 or 161
local edit_box_scale1_w = is_windows and 52 or is_macos and 60 or 68

local chord_names = {}
-- Dyads
chord_names['1 2'] = ' minor 2nd'
chord_names['1 3'] = ' major 2nd'
chord_names['1 4'] = ' minor 3rd'
chord_names['1 5'] = ' major 3rd'
chord_names['1 6'] = ' perfect 4th'
chord_names['1 7'] = '5-'
chord_names['1 8'] = '5'
chord_names['1 9'] = ' minor 6th'
chord_names['1 10'] = ' major 6th'
chord_names['1 11'] = ' minor 7th'
chord_names['1 12'] = ' major 7th'
chord_names['1 13'] = ' octave'

-- Compound intervals
chord_names['1 14'] = ' minor 9th'
chord_names['1 15'] = ' major 9th'
chord_names['1 16'] = ' minor 10th'
chord_names['1 17'] = ' major 10th'
chord_names['1 18'] = ' perfect 11th'
chord_names['1 19'] = ' minor 12th'
chord_names['1 20'] = ' perfect 12th'
chord_names['1 21'] = ' minor 13th'
chord_names['1 22'] = ' major 13th'
chord_names['1 23'] = ' minor 14th'
chord_names['1 24'] = ' major 14th'

-- Major chords
chord_names['1 5 8'] = 'maj'
chord_names['1 8 12'] = 'maj7 omit3'
chord_names['1 5 12'] = 'maj7 omit5'
chord_names['1 5 8 12'] = 'maj7'
chord_names['1 3 5 12'] = 'maj9 omit5'
chord_names['1 3 5 8 12'] = 'maj9'
chord_names['1 3 5 6 12'] = 'maj11 omit5'
chord_names['1 5 6 8 12'] = 'maj11 omit9'
chord_names['1 3 5 6 8 12'] = 'maj11'
chord_names['1 3 5 6 10 12'] = 'maj13 omit5'
chord_names['1 5 6 8 10 12'] = 'maj13 omit9'
chord_names['1 3 5 6 8 10 12'] = 'maj13'
chord_names['1 8 10'] = '6 omit3'
chord_names['1 5 8 10'] = '6'
chord_names['1 3 5 10'] = '6/9 omit5'
chord_names['1 3 5 8 10'] = '6/9'

-- Dominant/Seventh
chord_names['1 8 11'] = '7 omit3'
chord_names['1 5 11'] = '7 omit5'
chord_names['1 5 8 11'] = '7'
chord_names['1 3 8 11'] = '9 omit3'
chord_names['1 3 5 11'] = '9 omit5'
chord_names['1 3 5 8 11'] = '9'
chord_names['1 3 5 10 11'] = '13 omit5'
chord_names['1 5 8 10 11'] = '13 omit9'
chord_names['1 3 5 8 10 11'] = '13'
chord_names['1 5 7 11'] = '7#11 omit5'
chord_names['1 5 7 8 11'] = '7#11'
chord_names['1 3 5 7 11'] = '9#11 omit5'
chord_names['1 3 5 7 8 11'] = '9#11'

-- Altered
chord_names['1 2 5 11'] = '7b9 omit5'
chord_names['1 2 5 8 11'] = '7b9'
chord_names['1 2 5 7 8 11'] = '7b9#11'
chord_names['1 4 5 11'] = '7#9 omit5'
chord_names['1 4 5 8 11'] = '7#9'
chord_names['1 4 5 9 11'] = '7#5#9'
chord_names['1 4 5 7 8 11'] = '7#9#11'
chord_names['1 2 5 8 10 11'] = '13b9'
chord_names['1 3 5 7 8 10 11'] = '13#11'
chord_names['1 5 7 12'] = 'maj7#11 omit5'
chord_names['1 5 7 8 12'] = 'maj7#11'
chord_names['1 3 5 7 12'] = 'maj9#11 omit5'
chord_names['1 3 5 7 8 12'] = 'maj9#11'
chord_names['1 3 5 7 10 12'] = 'maj13#11 omit5'
chord_names['1 5 7 8 10 12'] = 'maj13#11 omit9'
chord_names['1 3 5 7 8 10 12'] = 'maj13#11'

-- Suspended
chord_names['1 6 8'] = 'sus4'
chord_names['1 3 8'] = 'sus2'
chord_names['1 6 11'] = '7sus4 omit5'
chord_names['1 6 8 11'] = '7sus4'
chord_names['1 3 6 11'] = '11 omit5'
chord_names['1 6 8 11'] = '11 omit9'
chord_names['1 3 6 8 11'] = '11'

-- Minor
chord_names['1 4 8'] = 'm'
chord_names['1 4 11'] = 'm7 omit5'
chord_names['1 4 8 11'] = 'm7'
chord_names['1 4 12'] = 'm/maj7 omit5'
chord_names['1 4 8 12'] = 'm/maj7'
chord_names['1 3 4 12'] = 'm/maj9 omit5'
chord_names['1 3 4 8 12'] = 'm/maj9'
chord_names['1 3 4 11'] = 'm9 omit5'
chord_names['1 3 4 8 11'] = 'm9'
chord_names['1 3 4 6 11'] = 'm11 omit5'
chord_names['1 4 6 8 11'] = 'm11 omit9'
chord_names['1 3 4 6 8 11'] = 'm11'
chord_names['1 3 4 6 10 11'] = 'm13 omit5'
chord_names['1 4 6 8 10 11'] = 'm13 omit9'
chord_names['1 3 4 6 8 10 11'] = 'm13'
chord_names['1 4 8 10'] = 'm6'
chord_names['1 3 4 10'] = 'm6/9 omit5'
chord_names['1 3 4 8 10'] = 'm6/9'

-- Diminished
chord_names['1 4 7'] = 'dim'
chord_names['1 4 7 10'] = 'dim7'
chord_names['1 2 4 7 11'] = 'm7b5'
chord_names['1 3 4 7 11'] = 'm9b5'
chord_names['1 3 4 6 7 11'] = 'm11b5'
chord_names['1 3 5 7 10 11'] = '13b5'

-- Augmented
chord_names['1 5 9'] = 'aug'
chord_names['1 5 9 11'] = 'aug7'
chord_names['1 5 9 12'] = 'aug/maj7'

-- Additions
chord_names['1 3 4 8'] = 'm add9'
chord_names['1 3 5 8'] = 'maj add9'
chord_names['1 5 10 11'] = '7 add13'

local degrees = {
    'I',
    'II',
    'II',
    'III',
    'III',
    'IV',
    'V',
    'V',
    'VI',
    'VI',
    'VII',
    'VII',
}

local note_names_abc = {
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
}

local note_names_solfege = {
    'Do ',
    'Do# ',
    'Re ',
    'Re# ',
    'Mi ',
    'Fa ',
    'Fa ',
    'Sol ',
    'Sol# ',
    'La ',
    'La# ',
    'Si ',
}

local use_input = reaper.GetExtState(extname, 'input') ~= '0'

local use_solfege = reaper.GetExtState(extname, 'solfege') == '1'
local note_names = use_solfege and note_names_solfege or note_names_abc

function print(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end

function PitchToName(pitch) return note_names[pitch % 12 + 1] end

function ToggleSolfegeMode()
    use_solfege = not use_solfege
    note_names = use_solfege and note_names_solfege or note_names_abc
    reaper.SetExtState(extname, 'solfege', use_solfege and '1' or '0', true)
end

function ToggleInputMode()
    use_input = not use_input
    input_note_map = {}
    prev_input_idx = reaper.MIDI_GetRecentInputEvent(0)
    reaper.SetExtState(extname, 'input', use_input and '1' or '0', true)
end

function IdentifyChord(notes)
    -- Get chord root
    local root = math.maxinteger
    for _, note in ipairs(notes) do
        root = note.pitch < root and note.pitch or root
    end
    -- Remove duplicates and move notes closer
    local intervals = {}
    for _, note in ipairs(notes) do
        intervals[(note.pitch - root) % 12 + 1] = 1
    end

    -- Create chord key string
    local interval_cnt = 0
    local key = '1'
    for i = 2, 12 do
        if intervals[i] then
            key = key .. ' ' .. i
            interval_cnt = interval_cnt + 1
        end
    end

    -- Check for compound chords / octaves
    if interval_cnt <= 1 then
        intervals = {}
        for _, note in ipairs(notes) do
            local diff = note.pitch - root
            if diff >= 12 then intervals[diff % 12 + 13] = 1 end
        end
        -- Create compound chord key string
        local comp_key = '1'
        for i = 12, 24 do
            if intervals[i] then comp_key = comp_key .. ' ' .. i end
        end

        -- Check if compound chord name exists for key
        if chord_names[comp_key] then return comp_key, root end
    end

    -- Check if chord name exists for key
    if chord_names[key] then return key, root end

    local key_nums = {}
    for key_num in key:gmatch('%d+') do key_nums[#key_nums + 1] = key_num end

    -- Create all possible inversions
    for n = 2, #key_nums do
        local diff = key_nums[n] - key_nums[1]
        intervals = {}
        for i = 1, #key_nums do
            intervals[(key_nums[i] - diff - 1) % 12 + 1] = 1
        end
        local inv_key = '1'
        for i = 2, 12 do
            if intervals[i] then inv_key = inv_key .. ' ' .. i end
        end
        -- Check if chord name exists for inversion key
        if chord_names[inv_key] then return inv_key, root + diff end
    end
end

function BuildChord(notes)
    local chord_key, chord_root = IdentifyChord(notes)
    if chord_key then
        local chord = {notes = notes, root = chord_root, key = chord_key}
        if notes[1].sppq then
            -- Determine chord start and end ppq position
            local min_eppq = math.maxinteger
            local max_sppq = math.mininteger
            for _, note in ipairs(notes) do
                min_eppq = note.eppq < min_eppq and note.eppq or min_eppq
                max_sppq = note.sppq > max_sppq and note.sppq or max_sppq
            end
            chord.sppq = max_sppq
            chord.eppq = min_eppq
        end
        return chord
    end
end

function GetChordDegree(chord)
    local scale_root = prev_midi_scale_root
    -- Return without degree if a note of the chord is not included in scale
    for _, note in ipairs(chord.notes) do
        if not curr_scale_intervals[(note.pitch - scale_root) % 12 + 1] then
            return
        end
    end
    -- Check the third and and the fifth to get degree info (minor,augmented etc.)
    local scale_note_cnt = 0
    local third
    local fifth
    for i = 0, 8 do
        if curr_scale_intervals[(chord.root + i - scale_root) % 12 + 1] then
            scale_note_cnt = scale_note_cnt + 1
            if scale_note_cnt == 3 then third = i end
            if scale_note_cnt == 5 then fifth = i end
        end
    end
    -- Build degree string based on info
    local degree = degrees[(chord.root - scale_root) % 12 + 1]
    if third == 3 then degree = degree:lower() end
    if fifth == 6 then degree = degree .. 'o' end
    if fifth == 8 then degree = degree .. '+' end
    return degree
end

function BuildChordName(chord)
    if not chord then return '' end
    if chord.name then return chord.name end
    local name = PitchToName(chord.root) .. chord_names[chord.key]
    local degree = prev_is_key_snap and GetChordDegree(chord)
    if degree then name = name .. ' - ' .. degree end
    return name
end

function GetChords(take)
    local _, note_cnt = reaper.MIDI_CountEvts(take)

    local chords = {}
    local notes = {}
    local sel_notes = {}

    local chord_min_eppq

    for i = 0, note_cnt - 1 do
        local _, sel, _, sppq, eppq, _, pitch = reaper.MIDI_GetNote(take, i)

        local note_info = {pitch = pitch, sel = sel, sppq = sppq, eppq = eppq}
        if sel then sel_notes[#sel_notes + 1] = note_info end

        chord_min_eppq = chord_min_eppq or eppq
        chord_min_eppq = eppq < chord_min_eppq and eppq or chord_min_eppq

        if sppq >= chord_min_eppq then
            local new_notes = {}
            if #notes >= 2 then
                local chord = BuildChord(notes)
                if chord then chords[#chords + 1] = chord end
                for n = 3, #notes do
                    -- Remove notes that end prior to chord_min_eppq
                    for _, note in ipairs(notes) do
                        if note.eppq > chord_min_eppq then
                            new_notes[#new_notes + 1] = note
                        end
                    end
                    -- Try to build chords
                    chord = BuildChord(new_notes)
                    if chord then
                        chord.sppq = chord_min_eppq
                        chord.eppq = math.min(chord.eppq, sppq)
                        -- Ignore short chords
                        if chord.eppq - chord.sppq >= 240 then
                            chords[#chords + 1] = chord
                        end
                        chord_min_eppq = chord.eppq
                    end
                    new_notes = {}
                end
                -- Remove notes that end prior to the start of current note
                chord_min_eppq = eppq
                for _, note in ipairs(notes) do
                    if note.eppq > sppq then
                        new_notes[#new_notes + 1] = note
                        if note.eppq < chord_min_eppq then
                            chord_min_eppq = note.eppq
                        end
                    end
                end
            else
                chord_min_eppq = eppq
            end
            notes = new_notes
        else
            if #notes >= 2 then
                local chord = BuildChord(notes)
                if chord then
                    chord.eppq = math.min(chord.eppq, sppq)
                    -- Ignore very short arpeggiated chords
                    if chord.eppq - chord.sppq >= 180 then
                        chords[#chords + 1] = chord
                    end
                end
            end
        end
        notes[#notes + 1] = note_info
    end

    local sel_chord
    if #sel_notes >= 2 then
        sel_chord = BuildChord(sel_notes) or {name = 'none'}
    end
    if #notes >= 2 then
        local chord = BuildChord(notes)
        if chord then chords[#chords + 1] = chord end
        for n = 3, #notes do
            local new_notes = {}
            -- Remove notes that end prior to chord_min_eppq
            for _, note in ipairs(notes) do
                if note.eppq > chord_min_eppq then
                    new_notes[#new_notes + 1] = note
                end
            end
            -- Try to build chords
            chord = BuildChord(new_notes)
            if chord then
                chord.sppq = chord_min_eppq
                -- Ignore short chords
                if chord.eppq - chord.sppq >= 240 then
                    chords[#chords + 1] = chord
                end
                chord_min_eppq = chord.eppq
            end
        end
    end

    return chords, sel_chord
end

function GetMIDIInputChord(track)
    local rec_in = reaper.GetMediaTrackInfo_Value(track, 'I_RECINPUT')
    local rec_arm = reaper.GetMediaTrackInfo_Value(track, 'I_RECARM')
    local is_recording_midi = rec_arm == 1 and rec_in & 4096 == 4096
    if not is_recording_midi then return end

    local filter_channel = rec_in & 31
    local filter_dev_id = (rec_in >> 5) & 127

    prev_input_idx = prev_input_idx or 0

    local idx, buf, _, dev_id = reaper.MIDI_GetRecentInputEvent(0)
    if idx > prev_input_idx then
        local new_idx = idx
        local i = 0
        repeat
            if prev_input_idx ~= 0 and #buf == 3 then
                local is_vkb_dev = dev_id == 62
                local is_all_dev = filter_dev_id == 63
                if not is_vkb_dev and (is_all_dev or dev_id == filter_dev_id) then

                    local msg1 = buf:byte(1)
                    local msg2 = buf:byte(2)
                    local msg3 = buf:byte(3)

                    local channel = msg1 & 0x0F
                    if filter_channel == 0 or filter_channel == channel then
                        local is_note_on = msg1 & 0xF0 == 0x90
                        local is_note_off = msg1 & 0xF0 == 0x80
                        -- Check for 0x90 note offs with 0 velocity
                        if is_note_on and msg3 == 0 then
                            is_note_on = false
                            is_note_off = true
                        end
                        if is_note_on and not input_note_map[msg2] then
                            input_note_map[msg2] = 1
                            input_note_cnt = input_note_cnt + 1
                        end
                        if is_note_off and input_note_map[msg2] == 1 then
                            input_note_map[msg2] = nil
                            input_note_cnt = input_note_cnt - 1
                        end

                    end
                end
            end
            i = i + 1
            idx, buf, _, dev_id = reaper.MIDI_GetRecentInputEvent(i)
        until idx == prev_input_idx

        prev_input_idx = new_idx
    end

    if input_note_cnt >= 2 then
        local notes = {}
        for n = 0, 127 do
            if input_note_map[n] == 1 then
                notes[#notes + 1] = {pitch = n}
            end
        end
        return BuildChord(notes)
    end
end

function IsBitmapHovered(hwnd)
    local x, y = reaper.GetMousePosition()
    if hwnd ~= reaper.JS_Window_FromPoint(x, y) then return false end
    x, y = reaper.JS_Window_ScreenToClient(hwnd, x, y)
    return x >= bm_x and y > bm_y and x < bm_x + bm_w and y <= bm_y + bm_h
end

function ConcatPath(...) return table.concat({...}, package.config:sub(1, 1)) end

function GetStartupHookCommandID()
    -- Note: Startup hook commands have to be in the main section
    local _, script_file, section, cmd_id = reaper.get_action_context()
    if section == 0 then
        -- Save command name when main section script is run first
        local cmd_name = '_' .. reaper.ReverseNamedCommandLookup(cmd_id)
        reaper.SetExtState(extname, 'hook_cmd_name', cmd_name, true)
    else
        -- Look for saved command name by main section script
        local cmd_name = reaper.GetExtState(extname, 'hook_cmd_name')
        cmd_id = reaper.NamedCommandLookup(cmd_name)
        if cmd_id == 0 then
            -- Add the script to main section (to get cmd id)
            cmd_id = reaper.AddRemoveReaScript(true, 0, script_file, true)
            if cmd_id ~= 0 then
                -- Save command name to avoid adding script on next run
                cmd_name = '_' .. reaper.ReverseNamedCommandLookup(cmd_id)
                reaper.SetExtState(extname, 'hook_cmd_name', cmd_name, true)
            end
        end
    end
    return cmd_id
end

function IsStartupHookEnabled()
    local res_path = reaper.GetResourcePath()
    local startup_path = ConcatPath(res_path, 'Scripts', '__startup.lua')
    local cmd_id = GetStartupHookCommandID()
    local cmd_name = reaper.ReverseNamedCommandLookup(cmd_id)

    if reaper.file_exists(startup_path) then
        -- Read content of __startup.lua
        local startup_file = io.open(startup_path, 'r')
        local content = startup_file:read('*a')
        startup_file:close()

        -- Find line that contains command id (also next line if available)
        local pattern = '[^\n]+' .. cmd_name .. '\'?\n?[^\n]+'
        local s, e = content:find(pattern)

        -- Check if line exists and whether it is commented out
        if s and e then
            local hook = content:sub(s, e)
            local comment = hook:match('[^\n]*%-%-[^\n]*reaper%.Main_OnCommand')
            if not comment then return true end
        end
    end
    return false
end

function SetStartupHookEnabled(is_enabled, comment, var_name)
    local res_path = reaper.GetResourcePath()
    local startup_path = ConcatPath(res_path, 'Scripts', '__startup.lua')
    local cmd_id = GetStartupHookCommandID()
    local cmd_name = reaper.ReverseNamedCommandLookup(cmd_id)

    local content = ''
    local hook_exists = false

    -- Check startup script for existing hook
    if reaper.file_exists(startup_path) then

        local startup_file = io.open(startup_path, 'r')
        content = startup_file:read('*a')
        startup_file:close()

        -- Find line that contains command id (also next line if available)
        local pattern = '[^\n]+' .. cmd_name .. '\'?\n?[^\n]+'
        local s, e = content:find(pattern)

        if s and e then
            -- Add/remove comment from existing startup hook
            local hook = content:sub(s, e)
            local repl = (is_enabled and '' or '-- ') .. 'reaper.Main_OnCommand'
            hook = hook:gsub('[^\n]*reaper%.Main_OnCommand', repl, 1)
            content = content:sub(1, s - 1) .. hook .. content:sub(e + 1)

            -- Write changes to file
            local new_startup_file = io.open(startup_path, 'w')
            new_startup_file:write(content)
            new_startup_file:close()

            hook_exists = true
        end
    end

    -- Create startup hook
    if is_enabled and not hook_exists then
        comment = comment and '-- ' .. comment .. '\n' or ''
        var_name = var_name or 'cmd_name'
        local hook = '%slocal %s = \'_%s\'\nreaper.\z
            Main_OnCommand(reaper.NamedCommandLookup(%s), 0)\n\n'
        hook = hook:format(comment, var_name, cmd_name, var_name)
        local startup_file = io.open(startup_path, 'w')
        startup_file:write(hook .. content)
        startup_file:close()
    end
end

function SetCustomColors()
    local title = 'Custom Colors'
    local captions = 'Record icon: (e.g. #FF0000),Selection icon:,Play icon\z
        :,Background:,Border:,Text:'

    local curr_vals = {}
    local function AddCurrentValue(color)
        local hex_num = tonumber(color, 16)
        curr_vals[#curr_vals + 1] = hex_num and ('#%.6X'):format(hex_num) or ''
    end

    AddCurrentValue(user_rec_color)
    AddCurrentValue(user_sel_color)
    AddCurrentValue(user_play_color)
    AddCurrentValue(user_bg_color)
    AddCurrentValue(user_border_color)
    AddCurrentValue(user_text_color)

    local curr_vals_str = table.concat(curr_vals, ',')

    local ret, inputs = reaper.GetUserInputs(title, 6, captions, curr_vals_str)
    if not ret then return end

    local colors = {}
    for input in (inputs .. ','):gmatch('[^,]*') do
        colors[#colors + 1] = input:gsub('^#', '')
    end

    local invalid_flag = false
    local function ValidateColor(color)
        local is_valid = #color <= 6 and tonumber(color, 16)
        if not is_valid and color ~= '' then invalid_flag = true end
        return is_valid and color or ''
    end

    user_rec_color = ValidateColor(colors[1])
    user_sel_color = ValidateColor(colors[2])
    user_play_color = ValidateColor(colors[3])
    user_bg_color = ValidateColor(colors[4])
    user_border_color = ValidateColor(colors[5])
    user_text_color = ValidateColor(colors[6])

    reaper.SetExtState(extname, 'rec_color', user_rec_color, true)
    reaper.SetExtState(extname, 'sel_color', user_sel_color, true)
    reaper.SetExtState(extname, 'play_color', user_play_color, true)
    reaper.SetExtState(extname, 'bg_color', user_bg_color, true)
    reaper.SetExtState(extname, 'border_color', user_border_color, true)
    reaper.SetExtState(extname, 'text_color', user_text_color, true)

    if invalid_flag then
        local msg = 'Please specify colors in hexadecimal format! (#RRGGBB)'
        reaper.MB(msg, 'Invalid input', 0)
    end
end

function MenuCreateRecursive(menu)
    local str = ''
    if menu.title then str = str .. '>' .. menu.title .. '|' end

    for i, entry in ipairs(menu) do
        if #entry > 0 then
            str = str .. MenuCreateRecursive(entry) .. '|'
        else
            local arg = entry.arg

            if entry.IsGrayed and entry.IsGrayed(arg) or entry.is_grayed then
                str = str .. '#'
            end

            if entry.IsChecked and entry.IsChecked(arg) or entry.is_checked then
                str = str .. '!'
            end

            if menu.title and i == #menu then str = str .. '<' end

            if entry.title or entry.separator then
                str = str .. (entry.title or '') .. '|'
            end
        end
    end
    return str:sub(1, #str - 1)
end

function MenuReturnRecursive(menu, idx, i)
    i = i or 1
    for _, entry in ipairs(menu) do
        if #entry > 0 then
            i = MenuReturnRecursive(entry, idx, i)
            if i < 0 then return i end
        elseif entry.title then
            if i == math.floor(idx) then
                if entry.OnReturn then entry.OnReturn(entry.arg) end
                return -1
            end
            i = i + 1
        end
    end
    return i
end

function ShowMenu(menu_str)
    -- Toggle fullscreen
    local is_full_screen = reaper.GetToggleCommandState(40346) == 1

    -- On Windows and MacOS (fullscreen), a dummy window is required to show menu
    if is_windows or is_macos and is_full_screen then
        local offs = is_windows and {x = 10, y = 20} or {x = 0, y = 0}
        local x, y = reaper.GetMousePosition()
        gfx.init('LCB', 0, 0, 0, x + offs.x, y + offs.y)
        gfx.x, gfx.y = gfx.screentoclient(x + offs.x / 2, y + offs.y / 2)
        if reaper.JS_Window_Find then
            local hwnd = reaper.JS_Window_FindTop('LCB', true)
            reaper.JS_Window_Show(hwnd, 'HIDE')
        end
    end
    local ret = gfx.showmenu(menu_str)
    gfx.quit()
    return ret
end

function GetTakeChunk(take, item_chunk)
    if not item_chunk then
        local item = reaper.GetMediaItemTake_Item(take)
        item_chunk = select(2, reaper.GetItemStateChunk(item, '', false))
    end
    local tk = reaper.GetMediaItemTakeInfo_Value(take, 'IP_TAKENUMBER')

    local take_start_ptr = 0
    local take_end_ptr = 0

    for _ = 0, tk do
        take_start_ptr = take_end_ptr
        take_end_ptr = item_chunk:find('\nTAKE[%s\n]', take_start_ptr + 1)
    end
    return item_chunk:sub(take_start_ptr, take_end_ptr)
end

function GetTakeChunkHZoom(chunk)
    local pattern = 'CFGEDITVIEW (.-) (.-) '
    return chunk:match(pattern)
end

function GetTakeChunkTimeBase(chunk)
    local pattern = 'CFGEDIT ' .. ('.- '):rep(18) .. '(.-) '
    return tonumber(chunk:match(pattern))
end

function GetMIDIEditorView(hwnd, item_chunk)
    local take = reaper.MIDIEditor_GetTake(hwnd)
    if not reaper.ValidatePtr(take, 'MediaItem_Take*') then return end

    local GetProjTimeFromPPQ = reaper.MIDI_GetProjTimeFromPPQPos

    local take_chunk = GetTakeChunk(take, item_chunk)
    local start_ppq, hzoom_lvl = GetTakeChunkHZoom(take_chunk)
    if not start_ppq then return end

    local timebase = GetTakeChunkTimeBase(take_chunk) or 0
    -- 0 = Beats (proj) 1 = Project synced 2 = Time (proj) 4 = Beats (source)

    local end_ppq
    local start_time, end_time

    local midi_view = reaper.JS_Window_FindChildByID(hwnd, 1001)
    local _, width_in_pixels = reaper.JS_Window_GetClientSize(midi_view)
    if timebase == 0 or timebase == 4 then
        -- For timebase 0 and 4, hzoom_lvl is in pixel/ppq
        end_ppq = start_ppq + width_in_pixels / hzoom_lvl
    else
        -- For timebase 1 and 2, hzoom_lvl is in pixel/time
        start_time = GetProjTimeFromPPQ(take, start_ppq)
        end_time = start_time + width_in_pixels / hzoom_lvl
    end

    -- Convert ppq to time based units
    start_time = start_time or GetProjTimeFromPPQ(take, start_ppq)
    end_time = end_time or GetProjTimeFromPPQ(take, end_ppq)

    return start_time, end_time
end

function CreateChordRegions()
    local hwnd = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(hwnd)
    if not reaper.ValidatePtr(take, 'MediaItem_Take*') then return end

    local item = reaper.GetMediaItemTake_Item(take)
    local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local item_start_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local item_end_pos = item_start_pos + item_length

    local EnumMarkers = reaper.EnumProjectMarkers2
    local SetMarker = reaper.SetProjectMarker2
    local AddMarker = reaper.AddProjectMarker

    local GetProjTimeFromPPQPos = reaper.MIDI_GetProjTimeFromPPQPos
    local GetPPQPosFromProjTime = reaper.MIDI_GetPPQPosFromProjTime

    reaper.Undo_BeginBlock()

    -- Delete regions over item
    for i = reaper.CountProjectMarkers(0) - 1, 0, -1 do
        local _, is_reg, start_pos, end_pos, name, idx = EnumMarkers(0, i)
        if is_reg then
            -- Delete regions within item bounds
            if start_pos >= item_start_pos and end_pos <= item_end_pos then
                reaper.DeleteProjectMarker(0, idx, true)
            end
            -- Shorten regions that exceed item end
            if start_pos < item_end_pos and end_pos > item_end_pos then
                SetMarker(0, idx, true, item_end_pos, end_pos, name)
            end
            -- Shorten regions that proceed item start
            if start_pos < item_start_pos and end_pos > item_start_pos then
                SetMarker(0, idx, true, start_pos, item_start_pos, name)
            end
        end
    end

    -- Note: Keep this for debugging purposes
    --[[ for _, chord in ipairs(curr_chords) do
        local start_pos = reaper.MIDI_GetProjTimeFromPPQPos(take, chord.sppq)
        local end_pos = reaper.MIDI_GetProjTimeFromPPQPos(take, chord.eppq)

        print(chord.sppq .. ' ' .. chord.eppq)
        local chord_name = BuildChordName(chord)
        reaper.AddProjectMarker(0, true, start_pos, end_pos, chord_name, -1)
    end
    reaper.Undo_EndBlock('Create chord regions', -1)
    if true then return end ]]

    local loops = 1
    local source_ppq_length = 0
    -- Calculate how often item is looped (and loop length)
    if reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') == 1 then
        local source = reaper.GetMediaItemTake_Source(take)
        local source_length = reaper.GetMediaSourceLength(source)
        local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
        local end_qn = start_qn + source_length
        source_ppq_length = reaper.MIDI_GetPPQPosFromProjQN(take, end_qn)

        local item_start_ppq = GetPPQPosFromProjTime(take, item_start_pos)
        local item_end_ppq = GetPPQPosFromProjTime(take, item_end_pos)
        local item_ppq_length = item_end_ppq - item_start_ppq
        -- Note: Looped items repeat after full ppq length
        loops = math.ceil(item_ppq_length / source_ppq_length)
    end

    local prev_name
    local prev_start_pos
    local prev_end_pos

    for loop = 1, loops do
        for _, chord in ipairs(curr_chords) do
            local loop_ppq = source_ppq_length * (loop - 1)
            local start_pos = GetProjTimeFromPPQPos(take, chord.sppq + loop_ppq)
            local end_pos = GetProjTimeFromPPQPos(take, chord.eppq + loop_ppq)

            if prev_start_pos then
                local reg_start_pos = prev_start_pos
                local reg_end_pos = start_pos
                if reg_start_pos < item_end_pos and reg_end_pos > item_start_pos then
                    reg_start_pos = math.max(reg_start_pos, item_start_pos)
                    if reg_end_pos > item_end_pos then
                        reg_end_pos = math.min(prev_end_pos, item_end_pos)
                    end
                    AddMarker(0, true, reg_start_pos, reg_end_pos, prev_name, -1)
                end
            end

            prev_name = BuildChordName(chord)
            prev_start_pos = start_pos
            prev_end_pos = end_pos
        end
    end

    if prev_start_pos then
        local reg_start_pos = prev_start_pos
        local reg_end_pos = prev_end_pos
        if reg_start_pos < item_end_pos and reg_end_pos > item_start_pos then
            reg_start_pos = math.max(reg_start_pos, item_start_pos)
            reg_end_pos = math.min(reg_end_pos, item_end_pos)
            AddMarker(0, true, reg_start_pos, reg_end_pos, prev_name, -1)
        end
    end

    -- Combine regions with same chord name
    local prev_name
    local prev_idx
    local prev_end_pos
    for i = reaper.CountProjectMarkers(0) - 1, 0, -1 do
        local _, is_reg, start_pos, end_pos, name, idx = EnumMarkers(0, i)
        if is_reg then
            if start_pos >= item_start_pos and end_pos <= item_end_pos then
                if name == prev_name then
                    reaper.DeleteProjectMarker(0, prev_idx, true)
                    SetMarker(0, idx, true, start_pos, prev_end_pos, name)
                end
                prev_name = name
                prev_idx = idx
                prev_end_pos = end_pos
            end
        end
    end

    reaper.Undo_EndBlock('Create chord regions', -1)
end

function CreateChordTakeMarkers()
    local hwnd = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(hwnd)
    if not reaper.ValidatePtr(take, 'MediaItem_Take*') then return end

    local item = reaper.GetMediaItemTake_Item(take)
    local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local item_start_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local item_end_pos = item_start_pos + item_length

    local GetProjTimeFromPPQPos = reaper.MIDI_GetProjTimeFromPPQPos
    local GetPPQPosFromProjTime = reaper.MIDI_GetPPQPosFromProjTime

    reaper.Undo_BeginBlock()

    -- Delete take markers
    for i = reaper.GetNumTakeMarkers(take) - 1, 0, -1 do
        reaper.DeleteTakeMarker(take, i)
    end

    local loops = 1
    local source_ppq_length = 0
    -- Calculate how often item is looped (and loop length)
    if reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') == 1 then
        local source = reaper.GetMediaItemTake_Source(take)
        local source_length = reaper.GetMediaSourceLength(source)
        local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
        local end_qn = start_qn + source_length
        source_ppq_length = reaper.MIDI_GetPPQPosFromProjQN(take, end_qn)

        local item_start_ppq = GetPPQPosFromProjTime(take, item_start_pos)
        local item_end_ppq = GetPPQPosFromProjTime(take, item_end_pos)
        local item_ppq_length = item_end_ppq - item_start_ppq
        -- Note: Looped items repeat after full ppq length
        loops = math.ceil(item_ppq_length / source_ppq_length)
    end

    for loop = 1, loops do
        local prev_name
        for _, chord in ipairs(curr_chords) do
            local loop_ppq = source_ppq_length * (loop - 1)
            local start_pos = GetProjTimeFromPPQPos(take, chord.sppq + loop_ppq)
            local name = BuildChordName(chord)
            if name ~= prev_name then
                local marker_pos = start_pos - item_start_pos
                reaper.SetTakeMarker(take, -1, name, marker_pos)
            end
            prev_name = name
        end
    end
    reaper.Undo_EndBlock('Create chord take markers', -1)
end

function GetCursorPPQPosition(take, cursor_pos)

    local cursor_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursor_pos)

    -- In timebase source simply return cursor ppq position
    local is_timebase_source = reaper.GetToggleCommandStateEx(32060, 40470) == 1
    if is_timebase_source then return cursor_ppq end

    local item = reaper.GetMediaItemTake_Item(take)
    local length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local start_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local end_pos = start_pos + length

    -- Check that cursor position is within arrange view item bounds
    if cursor_pos < start_pos or cursor_pos > end_pos then return end

    -- Adjust cursor ppq position for looped arrange view items
    if reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') == 1 then
        local source = reaper.GetMediaItemTake_Source(take)
        local source_length = reaper.GetMediaSourceLength(source)
        local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
        local end_qn = start_qn + source_length
        local source_ppq_length = reaper.MIDI_GetPPQPosFromProjQN(take, end_qn)

        -- Note: Looped items repeat after full ppq length
        cursor_ppq = cursor_ppq % source_ppq_length
    end

    return cursor_ppq
end

function DrawLICE(chord, mode)
    reaper.JS_LICE_Clear(bitmap, 0)

    local alpha = 0xFF000000
    local bg_color, hl_color, sh_color
    local play_color, sel_color, rec_color

    local text_color = reaper.GetThemeColor('col_main_text', 0) | alpha

    if user_bg_color ~= '' then
        bg_color = tonumber(user_bg_color, 16) | alpha
    else
        bg_color = reaper.GetThemeColor('col_main_editbk', 0) | alpha
    end
    if user_border_color ~= '' then
        hl_color = tonumber(user_border_color, 16) | alpha
        sh_color = hl_color
    else
        hl_color = reaper.GetThemeColor('col_main_3dhl', 0) | alpha
        sh_color = reaper.GetThemeColor('col_main_3dsh', 0) | alpha
    end
    if user_play_color ~= '' then
        play_color = tonumber(user_play_color, 16) | alpha
    else
        play_color = text_color
    end
    if user_sel_color ~= '' then
        sel_color = tonumber(user_sel_color, 16) | alpha
    else
        sel_color = text_color
    end
    if user_rec_color ~= '' then
        rec_color = tonumber(user_rec_color, 16) | alpha
    else
        rec_color = text_color
    end
    if user_text_color ~= '' then
        text_color = tonumber(user_text_color, 16) | alpha
    end

    -- Draw box background
    reaper.JS_LICE_FillRect(bitmap, 0, 0, bm_w, bm_h, bg_color, 1, 0)

    -- Draw box 3D shadow
    reaper.JS_LICE_Line(bitmap, 0, 0, bm_w, 0, sh_color, 1, 0, 0)
    reaper.JS_LICE_Line(bitmap, 0, 0, 0, bm_h, sh_color, 1, 0, 0)

    -- Draw box 3D highlight
    reaper.JS_LICE_Line(bitmap, 0, bm_h - 1, bm_w, bm_h - 1, hl_color, 1, 0, 0)
    reaper.JS_LICE_Line(bitmap, bm_w - 1, 0, bm_w - 1, bm_h, hl_color, 1, 0, 0)

    -- Draw Text
    reaper.JS_LICE_SetFontColor(lice_font, text_color)
    gfx.setfont(1, 'Arial', font_size)
    local text_w, text_h = gfx.measurestr(chord)
    local text_x = (bm_w - text_w) // 2
    local text_y = (bm_h - text_h) // 2
    if is_macos then text_y = text_y + 1 end

    -- Position icon at start of text
    local icon_x = math.floor(text_x - 8 * scale)
    -- Move text slightly to the right when icon is drawn
    text_x = mode == 0 and text_x or math.floor(text_x + 5 * scale)

    if mode == 1 and chord ~= '' then
        local h = bm_h // 2 - 1
        -- Ensure triangle height is uneven
        if h % 2 ~= 1 then h = h - 1 end
        local x1, y1 = icon_x, (bm_h - h) // 2
        local x2, y2 = icon_x, y1 + h
        local x3, y3 = icon_x + h, y1 + h // 2

        reaper.JS_LICE_Line(bitmap, x1, y1, x3, y3, play_color, 1, 0, 1)
        reaper.JS_LICE_Line(bitmap, x2, y2, x3, y3 + 1, play_color, 1, 0, 1)
        reaper.JS_LICE_FillTriangle(bitmap, x1, y1, x2, y2, x3, y3, play_color,
                                    1, 0)
    end

    if mode == 2 then
        local h = bm_h // 2
        -- Ensure square height can be divided by 4
        local mod = h % 4
        if mod ~= 0 then h = h - mod end
        local x1, y1 = icon_x, (bm_h - h) // 2
        local x2, y2 = icon_x + h / 4, y1 + h / 4
        local w1, w2 = h, h / 2
        reaper.JS_LICE_FillRect(bitmap, x1, y1, w1, w1, sel_color, 1, 0)
        reaper.JS_LICE_FillRect(bitmap, x2, y2, w2, w2, bg_color, 1, 0)
    end

    if mode == 3 then
        local x, y = math.floor(icon_x + 5 * scale), bm_h // 2
        local r = math.floor(2.5 * scale * 10) / 10
        reaper.JS_LICE_FillCircle(bitmap, x, y, r, rec_color, 1, 1, true)
    end

    -- Note: Green box to help measure text
    --[[ reaper.JS_LICE_FillRect(bitmap, text_x, text_y, text_w, text_h, 0xFF00FF00,
                            1, 0) ]]

    local len = chord:len()
    reaper.JS_LICE_DrawText(bitmap, lice_font, chord, len, text_x, text_y, bm_w,
                            bm_h)

    -- Refresh window
    reaper.JS_Window_InvalidateRect(piano_pane, bm_x, bm_y, bm_x + bm_w,
                                    bm_y + bm_h, false)
end

function Main()
    local hwnd = reaper.MIDIEditor_GetActive()

    -- Keep process idle when no MIDI editor is open
    if not reaper.ValidatePtr(hwnd, 'HWND*') then
        reaper.defer(Main)
        prev_take = nil
        return
    end

    local is_redraw = false
    local is_forced_redraw = false

    -- Monitor MIDI editor window handle changes
    if hwnd ~= prev_hwnd then
        prev_hwnd = hwnd
		notes_view = reaper.ShowConsoleMsg("\n")
        --notes_view = reaper.JS_Window_FindChildByID(hwnd, 1001)
        piano_pane = reaper.JS_Window_FindChildByID(hwnd, 1003)
        prev_piano_pane_w = nil
    end

    -- Detect width changes (e.g. when editor moves from hdpi to non-hppi monitor)
    local _, piano_pane_w = reaper.JS_Window_GetClientSize(piano_pane)
    if piano_pane_w ~= prev_piano_pane_w then
        prev_piano_pane_w = piano_pane_w
        -- Calculate scale from piano pane width
        scale = piano_pane_w / piano_pane_scale1_w

        -- Use 2 times the size of the boxes above + inbetween padding of 5px
        bm_w = math.ceil(edit_box_scale1_w * scale) * 2 + math.floor(5 * scale)
        bm_h = math.floor(18 * scale)
        bm_x = math.floor(7 * scale)
        bm_y = math.floor(28 * scale)

        bm_x = bm_x + box_x_offs
        bm_y = bm_y + box_y_offs
        bm_w = bm_w + box_w_offs
        bm_h = bm_h + box_h_offs

        -- Find optimal font_size by incrementing until it doesn't fit box
        font_size = 1
        local font_max_height = bm_h - math.floor(4 * scale)
        if is_macos then font_max_height = font_max_height + 2 end
        for i = 1, 100 do
            gfx.setfont(1, 'Arial', i)
            local _, h = gfx.measurestr('F')
            if h > font_max_height then break end
            font_size = i
        end

        -- Prepare LICE bitmap for drawing
        if bitmap then reaper.JS_LICE_DestroyBitmap(bitmap) end
        if lice_font then reaper.JS_LICE_DestroyFont(lice_font) end

        bitmap = reaper.JS_LICE_CreateBitmap(true, bm_w, bm_h)
        lice_font = reaper.JS_LICE_CreateFont()

        local gdi = reaper.JS_GDI_CreateFont(font_size, 0, 0, 0, 0, 0, 'Arial')
        reaper.JS_LICE_SetFontFromGDI(lice_font, gdi, '')
        reaper.JS_GDI_DeleteObject(gdi)

        -- Draw LICE bitmap on piano pane
        reaper.JS_Composite(piano_pane, bm_x, bm_y, bm_w, bm_h, bitmap, 0, 0,
                            bm_w, bm_h)
        reaper.JS_Composite_Delay(piano_pane, 0.03, 0.03, 2)
        is_forced_redraw = true
    end

    -- Monitor color theme changes
    local color_theme = reaper.GetLastColorThemeFile()
    if color_theme ~= prev_color_theme then
        prev_color_theme = color_theme
        is_forced_redraw = true
    end

    -- Keep process idle when no valid take is open
    local take = reaper.MIDIEditor_GetTake(hwnd)
    if not reaper.ValidatePtr(take, 'MediaItem_Take*') then
        reaper.defer(Main)
        return
    end

    -- Flush input events when take changes
    if take ~= prev_take then
        prev_take = take
        prev_input_idx = reaper.MIDI_GetRecentInputEvent(0)
        input_note_map = {}
    end

    -- Open options menu when user clicks on the box
    local mouse_state = reaper.JS_Mouse_GetState(3)
    if mouse_state ~= prev_mouse_state then
        prev_mouse_state = mouse_state
        local is_left_click = mouse_state == 1
        local is_right_click = mouse_state == 2
        if (is_left_click or is_right_click) and IsBitmapHovered(piano_pane) then
            local menu = {
                {title = 'Set custom colors', OnReturn = SetCustomColors},
                {
                    title = 'Create regions from chords',
                    OnReturn = CreateChordRegions,
                },
                {
                    title = 'Create take markers from chords',
                    OnReturn = CreateChordTakeMarkers,
                },
                {
                    title = 'Solfège mode (Do, Re, Mi)',
                    OnReturn = ToggleSolfegeMode,
                    is_checked = use_solfege,
                },
                {
                    title = 'Analyze incoming MIDI (live input)',
                    OnReturn = ToggleInputMode,
                    is_checked = use_input,
                },
                {
                    title = 'Run script on startup',
                    IsChecked = IsStartupHookEnabled,
                    OnReturn = function()
                        local is_enabled = IsStartupHookEnabled()
                        local comment = 'Start script: Lil Chordbox'
                        local var_name = 'chord_box_cmd_name'
                        SetStartupHookEnabled(not is_enabled, comment, var_name)
                    end,
                },
            }
            local menu_str = MenuCreateRecursive(menu)
            local ret = ShowMenu(menu_str)
            MenuReturnRecursive(menu, ret)
            is_forced_redraw = true
        end
    end

    -- Detect MIDI scale changes
    local is_key_snap, midi_scale_root, midi_scale = reaper.MIDI_GetScale(take)

    if is_key_snap ~= prev_is_key_snap then
        prev_is_key_snap = is_key_snap
        is_redraw = true
    end

    if is_key_snap then
        if midi_scale_root ~= prev_midi_scale_root then
            prev_midi_scale_root = midi_scale_root
            is_redraw = true
        end
        if midi_scale ~= prev_midi_scale then
            prev_midi_scale = midi_scale
            curr_scale_intervals = {}
            for i = 0, 11 do
                local mask = (1 << i)
                local has_note = midi_scale & mask == mask
                curr_scale_intervals[i + 1] = has_note and 1
            end
            is_redraw = true
        end
    end

    -- Process input chords that user plays on MIDI keyboard
    local input_chord
    if use_input then
        local track = reaper.GetMediaItemTake_Track(take)
        input_chord = GetMIDIInputChord(track)
    end
    if input_chord then
        input_timer = reaper.time_precise()
        local input_chord_name = BuildChordName(input_chord)
        -- Only redraw LICE bitmap when chord name has changed
        if input_chord_name ~= prev_input_chord_name then
            prev_input_chord_name = input_chord
            DrawLICE(input_chord_name, 3)
        end
        reaper.defer(Main)
        return
    end

    -- Show input chords a bit longer than they are played (linger)
    if input_timer then
        local linger_duration = 0.6
        if reaper.time_precise() < input_timer + linger_duration then
            reaper.defer(Main)
            return
        else
            input_timer = nil
            is_forced_redraw = true
        end
    end

    -- Update take chord information when MIDI hash changes
    local _, hash = reaper.MIDI_GetHash(take, true)
    if hash ~= prev_hash then
        prev_hash = hash
        curr_chords, curr_sel_chord = GetChords(take)
        is_redraw = true
    end

    local mode = -1
    local cursor_pos

    -- Monitor item chunk (for getting time position at mouse)
    -- Note: Avoid using GetItemStateChunk every defer cycle so that tooltips
    -- will show on Windows
    local curr_time = reaper.time_precise()
    if not prev_time or curr_time > prev_time + 0.6 then
        prev_time = curr_time
        local item = reaper.GetMediaItemTake_Item(take)
        local _, item_chunk = reaper.GetItemStateChunk(item, '', false)

        if item_chunk ~= prev_item_chunk then
            prev_item_chunk = item_chunk
            curr_start_time, curr_end_time = GetMIDIEditorView(hwnd, item_chunk)
        end
    end

    -- Calculate time position at mouse using start/end time of the MIDI editor
    if curr_start_time then
        local diff = curr_end_time - curr_start_time
        local _, notes_view_width = reaper.JS_Window_GetClientSize(notes_view)
        local x, y = reaper.GetMousePosition()
        x, y = reaper.JS_Window_ScreenToClient(notes_view, x, y)
        cursor_pos = curr_start_time + x / notes_view_width * diff
        mode = 0
    end

    -- Use play cursor position during playback/record
    local play_state = reaper.GetPlayState()
    if play_state > 0 then
        cursor_pos = reaper.GetPlayPosition()
        mode = 1
    end

    -- Redraw when transport status changes
    if play_state ~= prev_play_state then
        prev_play_state = play_state
        is_redraw = true
    end

    -- Redraw when cursor changes
    if cursor_pos ~= prev_cursor_pos then
        prev_cursor_pos = cursor_pos
        is_redraw = true
    end

    if is_redraw or is_forced_redraw then
        local curr_chord
        -- Get chord name depending on mode
        if curr_sel_chord then
            curr_chord = curr_sel_chord
            mode = 2
        end

        if mode == 1 then
            local cursor_ppq = GetCursorPPQPosition(take, cursor_pos)
            if cursor_ppq then
                for _, chord in ipairs(curr_chords) do
                    if chord.sppq > cursor_ppq then break end
                    curr_chord = chord
                end
            end
        end

        if mode == 0 and cursor_pos then
            local cursor_ppq = GetCursorPPQPosition(take, cursor_pos)
            if cursor_ppq then
                for _, chord in ipairs(curr_chords) do
                    if chord.sppq > cursor_ppq then break end
                    if cursor_ppq >= chord.sppq and cursor_ppq <= chord.eppq then
                        curr_chord = chord
                        break
                    end
                end
            end
        end

        local curr_chord_name = BuildChordName(curr_chord)

        -- Check if redrawing LICE bitmap is necessary
        local has_chord_changed = curr_chord_name ~= prev_chord_name
        local has_mode_changed = mode ~= prev_mode
        if has_chord_changed or has_mode_changed or is_forced_redraw then
            prev_chord_name = curr_chord_name
            prev_mode = mode
            DrawLICE(curr_chord_name, mode)
        end
    end

    reaper.defer(Main)
end

reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)

function Exit()
    reaper.SetToggleCommandState(sec, cmd, 0)
    reaper.RefreshToolbar2(sec, cmd)
    reaper.JS_LICE_DestroyBitmap(bitmap)
    reaper.JS_LICE_DestroyFont(lice_font)
    reaper.JS_Composite_Delay(piano_pane, 0, 0, 0)
end

reaper.atexit(Exit)
reaper.defer(Main)
