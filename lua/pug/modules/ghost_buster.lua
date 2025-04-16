local u = PUG.util
local ents = ents

local hooks = {}
local settings = {
	["Ghosting_Must_Be_Enabled"] = true,
	["GhostsPerIteration"] = 1,
}

settings = u.getSettings( settings )
settings["Ghosting_Must_Be_Enabled"] = true

local _s = {
	ghostCount = settings["GhostsPerIteration"]
}

u.addHook("Think", "GhostBuster", function()
	if (not PUG.UnGhost) then return end
	local iter = 0
	for _, ent in ents.Iterator() do
		if ( IsValid(ent) and ent.PUGGhosted and not u.isEntityHeld( ent ) ) then
			iter = iter + 1
			PUG:UnGhost(ent)
			if (iter >= _s.ghostCount) then
				break
			end
		end
	end
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}
