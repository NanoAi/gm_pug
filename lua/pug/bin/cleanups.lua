local hook, physenv, table, ents = hook, physenv, table, ents
local hasConstraints = constraint.HasConstraints
local u = PUG.util

local clean = {}

local function haltPhysEnv( callback )
	physenv.SetPhysicsPaused( true )
	print("-- PHYS ENV PAUSED --")

	callback(function()
		u.addJob(function() 
			physenv.SetPhysicsPaused( false )
			print("-- PHYS ENV RESUMED --")
		end, 1, 1)
	end)
end

function clean.unfrozen()
	for _, ent in next, ents.GetAll() do
		local valid, phys = u.isValidPhys( ent )
		if valid and ent.PUGBadEnt then
			phys:EnableMotion( false )
			if phys:IsPenetrating() and not hasConstraints( ent ) then
				ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
				ent:CollisionRulesChanged()
			end
			if u.isGhostState(ent, 1) then
				ent:Remove()
			end
		end
	end
end

function clean.nonContraptions()
	for _, ent in next, ents.GetAll() do
		local valid, phys = u.isValidPhys( ent )
		if valid and ent.PUGBadEnt then
			if phys:IsMotionEnabled() and not hasConstraints( ent ) then
				ent:Remove()
			end
		end
	end
end

function clean.clusters()
	haltPhysEnv( function( done )
		local bad = {}
		clean.unfrozen()

		for _, v in next, ents.GetAll() do
			local valid, phys = u.isValidPhys( v )
			if valid and phys then
				if phys:IsMotionEnabled() then
					if v.isFadingDoor and ent.PUGBadEnt then
						SafeRemoveEntity(v)
					else
						table.insert(bad, ent)
					end
				end
			end
		end

		for _, v in next, bad do
			local count = 0

			local owner = PUG:getEntOwner( v.ent )
			local space = ents.FindInSphere( v.ent:GetPos(), 7 )
			local cache = {}

			for _, ent in next, space do
				if owner == PUG:getEntOwner( ent ) then
					count = count + 1
					table.insert(cache, ent)
				end
			end

			if count > 4 then
				for _, ent in next, cache do
					if ent.PUGBadEnt then
						ent:Remove()
					end
				end
			end
		end

		done()
	end )
end

function clean.reset()
	haltPhysEnv( function( done )
		cleanup.CC_AdminCleanup( nil, nil, {} )
		u.addJob(function()
			done()
		end)
	end )
end

function clean.custom()
	haltPhysEnv( function( done )
		hook.Run("PUG.Cleanup.CustomCall")
		u.addJob(function()
			done()
		end)
	end )
end

return clean