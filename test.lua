local ctx = reaper.ImGui_CreateContext('mainContext')

local function loop()
  local visible, open = reaper.ImGui_Begin(ctx, 'reaper Show chord and note in window', true)
  if visible then
	reaper.ImGui_SetWindowSize(ctx, 400, 200)
    reaper.ImGui_Text(ctx, 'date')
    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)