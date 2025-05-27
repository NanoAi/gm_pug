local u = PUG.util
local zero = Vector(0,0,0)

local hooks = {}
local timers = {}
local _s = u.settings.set({
	enableHook = true,
	maxCollisions = 23,
	velocityDamp = 0,
	cooldown = 3,
})

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

		-- Entities can be colliding but not penetrating.
		-- if not entPhys:IsPenetrating() then return end

		ent["PUG_TrackPhysics"] = ent["PUG_TrackPhysics"] or {}

		local obj = ent["PUG_TrackPhysics"]
		local speed = 0

		obj.collisions = ( obj.collisions or 0 ) + 1

		obj.collisionTime = obj.collisionTime or ( CurTime() + _s.cooldown )
		obj.lastCollision = CurTime()

		if obj.collisions > ( _s.maxCollisions * 0.75 ) then
			speed = select( 2, u.physIsMoving( entPhys, 0 ) )

			if _s.velocityDamp > 0 then
				if speed < 3 then
					entPhys:Sleep()
				else
					local per = ( _s.velocityDamp / 100 )
					local angvel = entPhys:GetAngleVelocity()

					entPhys:SetVelocity( entPhys:GetVelocity() * per )
					entPhys:AddAngleVelocity( angvel * -1 )

					u.tasks.add(function()
						entPhys:AddAngleVelocity( angvel * per )
					end, 1, 0)
				end
			end
		end

		if obj.collisions > _s.maxCollisions then
			obj.collisions = 0
			if speed > 0 then
				u.tasks.add(function()
					ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
					ent:CollisionRulesChanged()
				end, 0, 0)
				for _, e in next, { entPhys, hit } do
					e:EnableMotion( false )
				end
			end
		end

		if obj.collisionTime < obj.lastCollision then
			obj.collisions = 1
			obj.collisionTime = ( CurTime() + _s.cooldown )
		end
	end
end, hooks, _s.enableHook)

local entitySet = {}
local function push(ent, data)
	local key = #entitySet + 1
	entitySet[key] = {ent = ent, data = data}
end

local hk = u.getHookID("EntityProcessor")
local function physCollide(ent, data)
	if _s.enableHook then
		push(ent, data)
	end
	if timer.Exists(hk) then
		return -- Only make a new timer if one doesn't exist already.
	end
	u.addTimer("EntityProcessor", 0, 0, function()
		local iters = 1000
		for k, v in next, entitySet do
			if iters < 0 then break end
			if k ~= 0 then
				hook.Run( "PUG.EntityPhysicsCollide", v.ent, v.data )
				entitySet[k] = nil
				iters = iters - 1
			end
		end
		if not next(entitySet) then
			timer.Remove(hk)
		end
	end, timers)
end

u.addHook("OnEntityCreated", "HookEntityCollision", function( ent )
	u.tasks.add(function()
		if not ent.PUGBadEnt then return end
		if not IsValid( ent ) then return end
		if not ent:IsSolid() then return end
		ent.PUG_CollisionCallbackHook = ent:AddCallback( "PhysicsCollide", physCollide )
	end, 0, 0)
end, hooks, _s.enableHook)

return u.settings.release(hooks, timers, _s)
