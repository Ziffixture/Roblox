--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Vendor = ReplicatedStorage:WaitForChild("Vendor")
local Proxy  = require(Vendor:WaitForChild("Proxy"))



local function hookDisconnect(connection: RBXScriptConnection, onDisconnect: () -> ()): RBXScriptConnection
	local override, proxy = Proxy(connection :: any)
	
	function override:Disconnect()
		onDisconnect()
		
		connection:Disconnect()
	end
	
	return proxy :: any
end

local function HookEvent(instance: Instance, eventName: string, onConnect: EventHook, onDisconnect: EventHook): RBXScriptSignal
	local event           = (instance :: any)[eventName]
	local override, proxy = Proxy(event)
	
	local function hookConnectionMethod(method: "Connect" | "Once")
		override[method] = function(_, callback: EventCallback)
			onConnect(instance, eventName, callback)
			
			local connection = event[method](event, callback)
			
			return hookDisconnect(connection, function()
				onDisconnect(instance, eventName, callback)
			end)
		end
	end
	
	hookConnectionMethod("Connect")
	hookConnectionMethod("Once")
	
	return proxy :: any
end



type EventCallback = (...any) -> () 
type EventHook     = (instance: Instance, eventName: string, callback: EventCallback) -> ()
	
	
return HookEvent
