local u = PUG.util

local hooks = {}
local settings = {
	["StackArea"] = 25,
	["MaxStackSize"] = 7,
	["FadingDoorsOnly"] = false,
	["ShouldRemove"] = true,
}

settings = u.getSettings( settings )

local safeRemoveEntity = SafeRemoveEntity
local stackArea = settings[ "StackArea" ]
local stackSize = settings[ "MaxStackSize" ]
local fadingDoorsOnly = settings[ "FadingDoorsOnly" ]
local shouldRemove = settings[ "shouldRemove" ]

local collDebris = COLLISION_GROUP_DEBRIS_TRIGGER
local collWorld = COLLISION_GROUP_WORLD

local function rem( ent )
	if shouldRemove then
		safeRemoveEntity( ent )
	else
		ent:SetCollisionGroup( collWorld )
		u.freezeEntity( ent )
	end
end

local function checkStack( ent, pcount )
	if not ent.PUGBadEnt then return end

	local bRadius = ( ent:BoundingRadius() * ( stackArea / 100 ) )
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

	if count >= ( pcount or stackSize ) then
		rem( ent )
	end
end

u.addHook("PUG.PostPhysgunPickup", "stackCheck", function( _, ent, canPickup )
	if fadingDoorsOnly then return end
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
		local bRadius = ( ent:BoundingRadius() * ( stackArea / 100 ) )

		for _, v in next, ents.FindInSphere( pos, bRadius ) do
			if v ~= ent and IsValid(v) and v.isFadingDoor then
				if u.getCPPIOwner( v ) == ply then
					table.insert(doors, v)
					count = count + 1
				end
			end
		end

		if count >= stackSize then
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

return {
	hooks = hooks,
	settings = settings,
}