local u = PUG.util
local ents = ents
local folder = u.settings.folder

local hooks = {}
local _s = u.settings.set({
	buster = folder({
		enabled = false,
		count = 1,
	}, "enabled"),
})

u.addHook("Think", "GhostBuster", function()
	if (not _s.buster.enabled) then return end
	if (not PUG.UnGhost) then return end

	local iter = 0
	for _, ent in ents.Iterator() do
		if ( IsValid(ent) and ent.PUGGhosted == 2 and not u.isEntityHeld( ent ) ) then
			iter = iter + 1
			PUG:UnGhost(ent)
			if (iter >= _s.buster.count) then
				break
			end
		end
	end
end, hooks, (not _s.buster.enabled))

return u.settings.release(hooks, _s)
