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
		oob = folder({
			enabled = false,
			count = 5,
			clock = 2,
			useTrace = false,
		}, "enabled")
	}),
}, nil, true)

-- PrintTable(_s)

local mod = _s.expensive
local function rollbackPosition(ent)
	if ent.PUG_OOB and ent.PUG_OOB.pos then
		if util.IsInWorld(ent.PUG_OOB.pos) then
			ent:SetPos( ent.PUG_OOB.pos )
			ent:SetAngles( ent.PUG_OOB.ang )
			return true
		else
			SafeRemoveEntity(ent)
			return false
		end
	else
		SafeRemoveEntity(ent)
		return false
	end
end

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

local timerSwitch = (mod.oob.enabled and mod.oob.useTrace)
u.addTimer("OOBProcessor", mod.oob.clock, 0, function() 
	local iter = 0
	for _, ent in ents.Iterator() do
		if IsValid(ent) and ent.PUGBadEnt then
			iter = iter + 1
			local tr = util.TraceLine({
				start = ent:LocalToWorld(ent:OBBMins()),
				endpos = ent:LocalToWorld(ent:OBBMaxs()),
				mask = MASK_NPCWORLDSTATIC,
			})
			print(ent, " [TRACE]", tr.HitWorld)
			if not tr.HitWorld then
				ent.PUG_OOB = {
					pos = ent:GetPos(),
					ang = ent:GetAngles(),
				}
			else
				rollbackPosition(ent)
				if (iter >= mod.oob.count) then break end
			end
		end
	end
end, timers, timerSwitch)

if not timerSwitch then
	u.addTimer("OOBProcessor", mod.oob.clock, 0, function()
		local iter = 0
		for _, ent in ents.Iterator() do
			if IsValid(ent) and ent.PUGBadEnt then
				iter = iter + 1
				local pos = ent:GetPos()
				if util.IsInWorld(pos) then
					ent.PUG_OOB = {
						pos = pos,
						ang = ent:GetAngles(),
					}
				else
					rollbackPosition(ent)
					if (iter >= mod.oob.count) then break end
				end
			end
		end
	end, timers, mod.oob.enabled)
end

return u.settings.release(hooks, timers, _s)
