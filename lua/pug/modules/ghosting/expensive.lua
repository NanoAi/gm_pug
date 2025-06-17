local u = PUG.util
local ents = ents
local folder = u.settings.folder

local timers = {}
local hooks = {}
local _s = u.settings.set({
	expensive = folder({
		buster = folder({
			enabled = false,
			count = 1,
		}, "enabled"),
	}),
}, nil, true)

local mod = _s.expensive
u.addHook("Think", "GhostBuster", function()
	if (not mod.buster.enabled) then return end
	if (not PUG.UnGhost) then return end

	local iter = 0
	for _, ent in ents.Iterator() do
		if ( IsValid(ent) and ent.PUGGhosted == 2 and not u.isEntityHeld( ent ) ) then
			iter = iter + 1
			PUG:UnGhost(ent)
			if (iter >= mod.buster.count) then
				break
			end
		end
	end
end, hooks, mod.buster.enabled)

return u.settings.release(hooks, timers, _s)
