local PUG = PUG
local timer = timer
local u = PUG.util

local hooks = {}
local settings = {
	["GhostColour"] = {4, 20, 36, 250},
	["GhostsNoCollide"] = 0,
}

settings = u.getSettings( settings )

u.addHook("PUG_SetCollisionGroup", "PUGCollision", function( ent, group )
	local isGroupNone = ( group == COLLISION_GROUP_NONE )
	local checkEnt = ( ent.PUGBadEnt and not PUG:isGoodEnt( ent ) )
	if isGroupNone and checkEnt and ( not ent.PUGFrozen ) then
		return COLLISION_GROUP_INTERACTIVE
	end
end, hooks)

u.addHook("PUG_EnableMotion", "PUGCollision", function( ent, _, bool )
	if bool and ent.PUGBadEnt then
		if ent:GetCollisionGroup( ) ~= COLLISION_GROUP_WORLD then
			ent:SetCollisionGroup( COLLISION_GROUP_INTERACTIVE )
		end
	end
end, hooks)

local function isTrap( ent )
	local check = false

	local isVehicle = u.isVehicle( ent )
	local center = ent:LocalToWorld( ent:OBBCenter() )
	local bRadius = ent:BoundingRadius()

	for _,v in next, ents.FindInSphere( center, bRadius ) do
		local isLivingPlayer = ( v:IsPlayer() and v:Alive() )

		if isVehicle then
			if isLivingPlayer then
				-- Check if the distance between the sphere centers is less
				-- than the sum of their radius.
				local vCenter = v:LocalToWorld( v:OBBCenter() )
				if center:Distance( vCenter ) < v:BoundingRadius() then
					check = v
					break
				end
			end
		else
			if isLivingPlayer then
				local pos = v:GetPos()
				local trace = { start = pos, endpos = pos, filter = v }
				local tr = util.TraceEntity( trace, v )

				if tr.Entity == ent then
					check = v
					break
				end
			end
		end
	end

	return check and true or false
end

function PUG:Ghost( ent )
	if ent.PUGGhosted then return end
	if ent.jailWall then return end
	if not ent.PUGBadEnt then return end
	if not ent:IsSolid() then return end
	if type( u.getCPPIOwner( ent ) ) ~= "Player" then return end

	ent.FPPAntiSpamIsGhosted = nil -- Override FPP Ghosting.
	ent.PUGGhost = ent.PUGGhost or {}
	ent.PUGGhost.collision = ent.PUGGhost.collision or ent:GetCollisionGroup()

	-- If and old collision group was set get it.
	if ent.OldCollisionGroup then -- FPP Compatibility
		ent.PUGGhost.collision = ent.OldCollisionGroup
	end

	if ent.DPP_oldCollision then -- DPP Compatibility
		ent.PUGGhost.collision = ent.DPP_oldCollision
	end

	ent.OldCollisionGroup = nil
	ent.DPP_oldCollision = nil
	ent.PUGGhosted = true

	timer.Simple(0, function()
		if not IsValid( ent ) then return end

		if not ent.PUGGhost.colour then
			ent.PUGGhost.colour = ent:GetColor()

			-- Compatibility with other Ghosting
			if ent.OldColor then
				ent.PUGGhost.colour = ent.OldColor
			end

			if ent.__DPPColor then
				ent.PUGGhost.colour = ent.__DPPColor
			end

			ent.OldColor = nil
			ent.__DPPColor = nil
		end

		if not ent.PUGGhost.material then
			ent.PUGGhost.material = ent:GetMaterial()
		end

		ent:SetColor( Color( unpack( settings[ "GhostColour" ] ) ) )
		ent:SetMaterial("models/debug/debugwhite")
	end)

	ent.PUGGhost.render = ent:GetRenderMode()
	ent:SetRenderMode( RENDERMODE_TRANSALPHA )
	ent:DrawShadow( false )

	if settings[ "GhostsNoCollide" ] then
		ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
	else
		ent:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
	end

	do -- Fix magic surfing
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableCollisions( false )
			timer.Simple(0, function()
				if IsValid(phys) then
					phys:EnableCollisions( true )
				end
			end)
		end
	end

	ent:CollisionRulesChanged()
end

function PUG:UnGhost( ent )
	if not ent.PUGGhosted then return end

	local trap = isTrap(ent)
	local moving = u.entityIsMoving(ent, 9.3)

	if not ( trap or moving ) then
		u.entityForceDrop( ent )
		u.sleepEntity( ent )
		ent:DrawShadow( true )

		ent:SetRenderMode( ent.PUGGhost.render or RENDERMODE_NORMAL )
		ent:SetColor( ent.PUGGhost.colour or Color( 255, 255, 255, 255) )
		ent:SetMaterial( ent.PUGGhost.material or '' )

		local newCollisionGroup = COLLISION_GROUP_INTERACTIVE

		if PUG:isGoodEnt( ent ) then
			newCollisionGroup = ent.PUGGhost.collision
		else
			if ent.PUGGhost.collision == COLLISION_GROUP_WORLD then
				newCollisionGroup = COLLISION_GROUP_WORLD
			else
				if ent.PUGFrozen then
					newCollisionGroup = COLLISION_GROUP_NONE
				end
			end
		end

		ent:SetCollisionGroup( newCollisionGroup )
		ent:CollisionRulesChanged()

		ent.PUGGhosted = nil
		ent.PUGGhost = nil

		return true
	else
		if trap then
			-- Only notify if something is inside this entity.
			print("Entity Trap Detected!")
		end
		return false
	end
end

u.addHook("PUG_PostPhysgunPickup", "PUGGhosting", function(_, ent, canPickup)
	u.addJob(function()
		if not canPickup then return end
		if IsValid( ent ) then
			PUG:Ghost( ent )
			if constraint.HasConstraints( ent ) then
				local cw = constraint.Weld
				local denyMovement = cw(ent, Entity(0), 0, 0, 0, false, false)
				ent.PUGWeld = denyMovement
			end
		end
	end)
end, hooks)

u.addHook("PhysgunDrop", "PUGGhosting", function(_, ent)
	timer.Simple(0.05, function()
		u.addJob(function()
			if u.isEntityHeld(ent) then return end
			if IsValid( ent ) then
				PUG:UnGhost( ent )
				if ent.PUGWeld then
					ent.PUGWeld:Remove()
					ent.PUGWeld = nil
				end
			end
		end)
	end)
end, hooks)

u.addHook("OnEntityCreated", "PUGGhosting", function( ent )
	u.addJob(function()
		if not ent.PUGBadEnt then return end
		if not IsValid( ent ) then return end
		if not ent:IsSolid() then return end
		if ent:GetClass() == "gmod_hands" then return end

		DropEntityIfHeld( ent )
		ent:ForcePlayerDrop()
		u.sleepEntity( ent )

		PUG:Ghost( ent )
	end)
end, hooks)

u.addHook("CanProperty", "PUGGhosting", function( _, _, ent )
	if ent.PUGGhosted then
		--FIXME: Add Notice here!
		return false
	end
end, hooks)

u.addHook("CanTool", "PUGGhosting", function(_, tr, tool)
	local ent = tr.Entity
	if ent.PUGGhosted and tool ~= "remover" then
		return false
	end
end, hooks)

u.addHook("CanTool", "PUGGhosting-FadingDoors", function(ply, tr)
	u.addJob(function()
		local ent = tr.Entity

		if IsValid(ent) then
			if not ent.isFadingDoor then return end
			local state = ent.fadeActive

			if state then
				ent:fadeDeactivate()
			end

			ent.oldFadeActivate = ent.oldFadeActivate or ent.fadeActivate
			ent.oldFadeDeactivate = ent.oldFadeDeactivate or ent.fadeDeactivate

			function ent:fadeActivate()
				if hook.Run("PUG_FadingDoorToggle", self, true, ply) then
					return
				end

				ent:oldFadeActivate()
			end

			function ent:fadeDeactivate()
				if hook.Run("PUG_FadingDoorToggle", self, false, ply) then
					return
				end

				ent:oldFadeDeactivate()
				ent:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
			end

			if state then
				ent:fadeActivate()
			end
		end
	end)
end, hooks)

u.addHook("PUG_FadingDoorToggle", "APG_FadingDoor", function(ent, isFading)
	if ent.PUGGhosted then
		-- Add notification
		if isFading then
			PUG:UnGhost( ent )
		else
			return true
		end
	end

	if ent.PUGBadEnt then
		local ply = u.getCPPIOwner( ent )
		if type( ply ) ~= "Player" then return end

		if not isFading then
			u.addJob(function()
				if IsValid( ply ) and IsValid( ent ) then
					if isTrap( ent ) then
						--FIXME: Add Notifications
						ent.PUGGhost = ent.PUGGhost or {}
						ent.PUGGhost.collision = COLLISION_GROUP_INTERACTIVE
						ent:oldFadeDeactivate()
						PUG:Ghost( ent )
						return true
					end
				end
			end)
		end
	end
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}