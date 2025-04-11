--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Vendor    = ReplicatedStorage:WaitForChild("Vendor")
local HookEvent = require(Vendor:WaitForChild("HookEvent"))
local Proxy     = require(Vendor:WaitForChild("Proxy"))

local RemoteProximityPrompt = {}


local triggeredRegistry = {} :: TriggeredRegistry
local remoteRegistry    = {} :: RemoteRegistry



local function realizeProximityPrompt(proximityPrompt: ProximityPrompt | RemoteProximityPrompt): ProximityPrompt?
	if typeof(proximityPrompt) == "Instance" then
		return proximityPrompt
	else
		return remoteRegistry[proximityPrompt]
	end
end

local function onTriggeredConnected(proximityPrompt: Instance, _, callback: TriggeredCallback)
	if not triggeredRegistry[proximityPrompt] then
		triggeredRegistry[proximityPrompt] = {}
	end
	
	table.insert(triggeredRegistry[proximityPrompt], callback)
end

local function onTriggeredDisconnected(proximityPrompt: Instance, _, callback: TriggeredCallback)
	local index = table.find(triggeredRegistry[proximityPrompt], callback)
	
	table.remove(triggeredRegistry[proximityPrompt], index)
end

local function triggerProximityPrompt(proximityPrompt: ProximityPrompt, player: Player)
	local callbacks = triggeredRegistry[proximityPrompt]
	if not callbacks then
		return
	end

	for _, callback in callbacks do
		task.spawn(callback, player)
	end
end


function RemoteProximityPrompt:__call(proximityPrompt: ProximityPrompt): RemoteProximityPrompt
	local override, proxy = Proxy(proximityPrompt)
	
	override.Triggered = HookEvent(
		proximityPrompt, 
		"Triggered", 
		onTriggeredConnected, 
		onTriggeredDisconnected
	)
	
	function override:Trigger(player: Player)
		triggerProximityPrompt(proximityPrompt, player)
	end
	
	proximityPrompt.Destroying:Connect(function()
		triggeredRegistry[proximityPrompt] = nil
		remoteRegistry[proxy]              = nil
	end)
	
	remoteRegistry[proxy] = proximityPrompt
	
	return proxy
end

function RemoteProximityPrompt.trigger(proximityPrompt: ProximityPrompt | RemoteProximityPrompt, player: Player)
	local realizedProximityPrompt = realizeProximityPrompt(proximityPrompt)
	if realizedProximityPrompt then
		triggerProximityPrompt(realizedProximityPrompt, player)
	end
end



setmetatable(RemoteProximityPrompt, RemoteProximityPrompt)


type TriggeredCallback = (player: Player) -> ()
type TriggeredRegistry = {
	[Instance]: {TriggeredCallback},
}

type RemoteProximityPrompt = ProximityPrompt & {
	Trigger: (self: RemoteProximityPrompt, player: Player) -> (),
}

type RemoteRegistry = {
	[RemoteProximityPrompt]: ProximityPrompt,
}


return RemoteProximityPrompt
