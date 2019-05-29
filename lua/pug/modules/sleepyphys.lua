local u = PUG.util

local hooks = {}
local settings = {
	["MaxObjectCollisions"] = 23,
	["Cooldown"] = 5,
}

settings = u.getSettings( settings )

local maxCollisions = settings[ "MaxObjectCollisions" ]
local cooldown = settings[ "Cooldown" ]
local zero = Vector( 0, 0, 0 )

local function collCall(ent, data)
	local hit = data.HitObject
	local hitEnt = data.HitEntity
	local entPhys = data.PhysObject

	if hitEnt == Entity(0) then return end

	if IsValid( ent ) and IsValid( hit ) and IsValid( entPhys ) then
		ent["frzr9k"] = ent["frzr9k"] or {}

		local obj = ent["frzr9k"]
		obj.collisions = ( obj.collisions or 0 ) + 1

		obj.collisionTime = obj.collisionTime or ( CurTime() + cooldown )
		obj.lastCollision = CurTime()

		if obj.collisions > maxCollisions then
			obj.collisions = 0
			for _, e in next, { entPhys, hit } do
				e:SetVelocityInstantaneous( zero )
				e:AddAngleVelocity( e:GetAngleVelocity() * -1 )
				e:Sleep()
			end
		end

		if obj.collisionTime < obj.lastCollision then
			local subtract = 1
			local mem = obj.collisionTime

			while true do
				mem = mem + 5
				subtract = subtract + 1
				if mem >= obj.lastCollision then
					break
				end
			end

			obj.collisions = ( obj.collisions - subtract )
			obj.collisions = ( obj.collisions > 1 ) and obj.collisions or 1

			obj.collisionTime = ( CurTime() + cooldown )
		end
	end
end

u.addHook("OnEntityCreated", "hookPhysics", function( ent )
	u.addJob(function()
		if not ent.PUGBadEnt then return end
		if not IsValid( ent ) then return end
		if not ent:IsSolid() then return end
		ent:AddCallback( "PhysicsCollide", collCall )
	end)
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}