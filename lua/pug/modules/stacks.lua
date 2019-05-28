local u = PUG.util

local hooks = {}
local settings = {
	["StackArea"] = 7,
	["MaxStackSize"] = 4,
}

local safeRemoveEntity = SafeRemoveEntity
local stackArea = settings[ "StackArea" ]
local stackSize = settings[ "MaxStackSize" ]

local function checkStack( ent, pcount )
	if not ent.PUGBadEnt then return end

	local efound = ents.FindInSphere( ent:GetPos(), stackArea )
	local count = 0

	for _, v in next, efound do
		if v.PUGBadEnt then
			count = count + 1
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

return {
	hooks = hooks,
	settings = settings,
}