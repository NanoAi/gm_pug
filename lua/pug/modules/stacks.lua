local u = PUG.util

local hooks = {}
local settings = {
	["StackArea"] = 7,
	["MaxStackSize"] = 4,
}

settings = u.getSettings( settings )

local safeRemoveEntity = SafeRemoveEntity
local stackArea = settings[ "StackArea" ]
local stackSize = settings[ "MaxStackSize" ]

local function checkStack( ent, pcount )
	if not ent.PUGBadEnt then return end

	local bRadius = ( ent:BoundingRadius() * 0.85 )
	local efound = ents.FindInSphere( ent:GetPos(), bRadius + stackArea )
	local count = 0

	for _, v in next, efound do
		if v.PUGBadEnt then
			local pos = v:GetPos()
			local trace = { start = pos, endpos = pos, filter = v }
			local tr = util.TraceEntity( trace, v )

			if IsValid( tr.Entity ) and tr.Entity.PUGBadEnt then
				count = count + 1
			end
		end
	end

	if count >= ( pcount or stackSize ) then
		ent:Remove()
	end
end

u.addHook("PUG.PostPhysgunPickup", "stackCheck", function( _, ent, canPickup )
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

		for _, v in next, ents.FindInSphere( pos, stackArea ) do
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
				safeRemoveEntity(v)
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