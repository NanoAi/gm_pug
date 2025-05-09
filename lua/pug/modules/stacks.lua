local u = PUG.util
local safeRemoveEntity = SafeRemoveEntity

local hooks = {}
local _s = u.settings.set({
	stackArea = 25,
	stackSize = 7,
	fadingDoorsOnly = false,
	shouldRemove = true,
})

local collDebris = COLLISION_GROUP_DEBRIS_TRIGGER
local collWorld = COLLISION_GROUP_WORLD

local function rem( ent )
	if _s.shouldRemove then
		safeRemoveEntity( ent )
	else
		ent:SetCollisionGroup( collWorld )
		u.freezeEntity( ent )
	end
end

local function checkStack( ent, pcount )
	if not ent.PUGBadEnt then return end

	local bRadius = ( ent:BoundingRadius() * ( _s.stackArea / 100 ) )
	local efound = ents.FindInSphere( ent:GetPos(), bRadius )
	local count = 0

	for _, v in next, efound do
		if v.PUGBadEnt then
			local pos = v:GetPos()
			local trace = { start = pos, endpos = pos, filter = v }
			local tr = util.TraceEntity( trace, v )
			local tEnt = tr.Entity

			if IsValid( tEnt ) and tEnt.PUGBadEnt then
				local group = tEnt:GetCollisionGroup()
				if group ~= collWorld and group ~= collDebris then
					count = count + 1
				end
			end
		end
	end

	if count >= ( pcount or _s.stackSize ) then
		rem( ent )
	end
end

u.addHook("PUG.PostPhysgunPickup", "stackCheck", function( _, ent, canPickup )
	if _s.fadingDoorsOnly then return end
	if canPickup then
		checkStack( ent )
	end
end, hooks)

local notify = false
local curTime = 0
local lastCall = 0

u.addHook("PUG.FadingDoorToggle", "stackCheck", function(ent, faded, ply)
	curTime = CurTime()

	if IsValid(ent) and faded then
		local pos = ent:GetPos()
		local doors = {}
		local count = 1 -- Start at 1 to include the original fading door
		local bRadius = ( ent:BoundingRadius() * ( _s.stackArea / 100 ) )

		for _, v in next, ents.FindInSphere( pos, bRadius ) do
			if v ~= ent and IsValid(v) and v.isFadingDoor then
				if u.getCPPIOwner( v ) == ply then
					table.insert(doors, v)
					count = count + 1
				end
			end
		end

		if count >= _s.stackSize then
			notify = true
			for _,v in next, doors do
				rem(v)
			end
		end

		if showNotifications and ( curTime > lastCall ) and notify then
			notify = false
		end
	end

	lastCall = curTime + 0.001
end, hooks)

return u.settings.release(hooks, _s)
