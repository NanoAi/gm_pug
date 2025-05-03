local u = PUG.util

local hooks = {}
local settings = {
	["MaxObjectCollisions"] = 23,
	["VelocityDamping"] = 0,
	["Cooldown"] = 3,
}

settings = u.getSettings( settings )

local maxCollisions = settings[ "MaxObjectCollisions" ]
local velocityDamp = settings[ "VelocityDamping" ]
local cooldown = settings[ "Cooldown" ]

u.addHook("PUG.EntityPhysicsCollide", "SleepyPhys", function( ent, data )
	local hit = data.HitObject
	local hitEnt = data.HitEntity
	local entPhys = data.PhysObject

	if hitEnt == Entity(0) then return end
	if not hitEnt.PUGBadEnt then return end

	if IsValid( ent ) and IsValid( hit ) and IsValid( entPhys ) then
		if entPhys:IsAsleep() then return end

		if not entPhys:IsMotionEnabled() then return end
		if not entPhys:IsCollisionEnabled() then return end
		if not entPhys:IsPenetrating() then return end

		ent["PUG_TrackPhysics"] = ent["PUG_TrackPhysics"] or {}

		local obj = ent["PUG_TrackPhysics"]
		local speed = 0

		obj.collisions = ( obj.collisions or 0 ) + 1

		obj.collisionTime = obj.collisionTime or ( CurTime() + cooldown )
		obj.lastCollision = CurTime()

		if obj.collisions > ( maxCollisions * 0.75 ) then
			speed = select( 2, u.physIsMoving( entPhys, 0 ) )

			if velocityDamp > 0 then
				if speed < 3 then
					entPhys:Sleep()
				else
					local per = ( velocityDamp / 100 )
					local angvel = entPhys:GetAngleVelocity()

					entPhys:SetVelocity( entPhys:GetVelocity() * per )
					entPhys:AddAngleVelocity( angvel * -1 )

					u.tasks.add(function()
						entPhys:AddAngleVelocity( angvel * per )
					end, 1, 0)
				end
			end
		end

		if obj.collisions > maxCollisions then
			obj.collisions = 0
			if speed > 0 then
				u.tasks.add(function()
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
end, hooks)

local function physCollide(ent, data)
	hook.Run( "PUG.EntityPhysicsCollide", ent, data )
end

u.addHook("OnEntityCreated", "HookEntityCollision", function( ent )
	u.tasks.add(function()
		if not ent.PUGBadEnt then return end
		if not IsValid( ent ) then return end
		if not ent:IsSolid() then return end
		ent.PUG_CollisionCallbackHook = ent:AddCallback( "PhysicsCollide", physCollide )
	end)
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}
