---@meta

-- version: 1.0
---
---
---@class PUG.util
local u = {}

-- ! HOOKS --
do
	---Prepare hooks for the current module.
  ---@param hasTimers boolean
  ---@return { h: {}, t: {} | nil }
	function u.declareHooks(hasTimers) end

	---Remove a hook from PUG.
	---@param callID string
  ---@param id string
  ---@param store table
	function u.remHook(callID, id, store)	end

	---Add a hook to PUG so that it can be removed when the module is unloaded.
  ---@param callID string
  ---@param id string
  ---@param callback function
  ---@param store table
  ---@param remCond boolean|function Boolean values are inverted.
	function u.addHook(callID, id, callback, store, remCond) end

	---Remove a Timer added to PUG
	---@param timerID string
	---@param store table
	function u.remTimer(timerID, store) end

	---Adds a timer to PUG.
  ---@param timerID string
  ---@param delay number
  ---@param reps number
  ---@param callback function
  ---@param store table
  ---@param cond boolean|function Boolean values are inverted.
	function u.addTimer(timerID, delay, reps, callback, store, cond) end

  ---Get the "real" hook name of a hook or timer.
  ---@param id string
  ---@return string
	function u.getHookID(id) end
end

PUG.util = u
return PUG.util
