local u = PUG.util
local ents = ents
local folder = u.settings.folder
local vector_origin	= vector_origin or Vector(0,0,0)

local timers = {}
local hooks = {}
local _s = u.settings.set({
	expensive = folder({
		oob = folder({
			enabled = false,
			count = 5,
			clock = 2,
			useTrace = false,
		}, "enabled"),
	}),
}, nil, true)

local mod = _s.expensive
local function rollbackPosition(ent)
	if ent.PUG_OOB and ent.PUG_OOB.pos then
    local now = CurTime()
    ent.PUG_OOB.hit = ent.PUG_OOB.hit or {heat = 0, timeout = now + 10}
    ent.PUG_OOB.hit.heat = ent.PUG_OOB.hit.heat + 1

    if ent.PUG_OOB.hit.timeout < now then
      local amount = math.floor((now - ent.PUG_OOB.hit.timeout) / 10)
      local sum = ent.PUG_OOB.hit - amount
      ent.PUG_OOB.hit = sum < 0 and 0 or sum 
    end

    if ent.PUG_OOB.hit.heat > 3 then
      SafeRemoveEntity(ent)
      return false
    end

		ent:SetPos( ent.PUG_OOB.pos )
    ent:SetAngles( ent.PUG_OOB.ang )

    return true
	else
		SafeRemoveEntity(ent)
		return false
	end
end

local timerSwitch = (mod.oob.enabled and mod.oob.useTrace)
u.addTimer("OOBProcessor", mod.oob.clock, 0, function() 
	local iter = 0
	for _, ent in ents.Iterator() do
		if ent.PUGBadEnt and IsValid(ent) then
			iter = iter + 1
			local tr = util.TraceLine({
				start = ent:LocalToWorld(ent:OBBMins()),
				endpos = ent:LocalToWorld(ent:OBBMaxs()),
				mask = MASK_NPCWORLDSTATIC,
			})
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
			if ent.PUGBadEnt and IsValid(ent) then
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
