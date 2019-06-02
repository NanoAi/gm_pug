local u = PUG.util

local hooks = {}
local settings = {
	["MaxObjectCollisions"] = 42,
	["Cooldown"] = 3,
}

settings = u.getSettings( settings )

local maxCollisions = settings[ "MaxObjectCollisions" ]
local cooldown = settings[ "Cooldown" ]

local function collCall(ent, data)
	local hit = data.HitObject
	local hitEnt = data.HitEntity
	local entPhys = data.PhysObject

	if hitEnt == Entity(0) then return end
	if not hitEnt.PUGBadEnt then return end

	if IsValid( ent ) and IsValid( hit ) and IsValid( entPhys ) then
		if entPhys:IsAsleep() then return end
		if not entPhys:IsMotionEnabled() then return end

		ent["frzr9k"] = ent["frzr9k"] or {}

		local obj = ent["frzr9k"]
		obj.collisions = ( obj.collisions or 0 ) + 1

		obj.collisionTime = obj.collisionTime or ( CurTime() + cooldown )
		obj.lastCollision = CurTime()

		if obj.collisions > maxCollisions then
			obj.collisions = 0
			if u.checkEntity( ent ) then
				u.addJob(function()
					ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
					ent:CollisionRulesChanged()
				end)
				for _, e in next, { entPhys, hit } do
					e:EnableMotion( false )
				end
			end
		end

		if obj.collisionTime < obj.lastCollision then
			obj.collisions = 1
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