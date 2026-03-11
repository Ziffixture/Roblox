--[[
Author     Ziffixture (74087102)
Date       03/10/2026 (MM/DD/YYYY)
Version    1.0.1
]]



--!strict
local Countdown = {}
Countdown.__index = Countdown



-- Utility
--------------------------------------------------
type Maybe<T> = T?



local function tryExecute<T...>(callback: Maybe<(T...) -> ()>, ...)
	if callback then
		callback(...)
	end
end
--------------------------------------------------


-- Countdown
--------------------------------------------------
type VoidFunction = () -> ()

export type Countdown = {
	_Thread      : thread?,
	_Paused      : boolean,
	_Duration    : number,
	_Resolution  : number,
	_SecondsLeft : number,

	OnStart : Maybe<VoidFunction>,
	OnTick  : Maybe<(secondsLeft: number) -> ()>,
	OnPause : Maybe<VoidFunction>,
	OnEnd   : Maybe<VoidFunction>,
	OnReset : Maybe<VoidFunction>,

	Start : (self: Countdown) -> (),
	Pause : (self: Countdown) -> (),
	Reset : (self: Countdown) -> (),
	
	Paused   : (self: Countdown) -> boolean,
	Duration : (self: Countdown) -> number,
}



local function stepCountdownAsync(countdown: Countdown)
	while countdown._SecondsLeft > 0 do
		countdown._SecondsLeft -= task.wait(countdown._Resolution)

		-- Was the countdown paused while suspended?
		if countdown._Paused then
			coroutine.yield()
		end

		tryExecute(countdown.OnTick, math.ceil(countdown._SecondsLeft))
	end
	
	tryExecute(countdown.OnEnd)
end


function Countdown.new(duration: number, resolution: number?): Countdown
	local self = (setmetatable({}, Countdown) :: any) :: Countdown

	self.OnStart = nil
	self.OnTick  = nil
	self.OnEnd   = nil

	self._Thread      = nil
	self._Paused      = true
	self._Duration    = duration
	self._Resolution  = resolution or 1
	self._SecondsLeft = duration

	return self
end

function Countdown.Start(self: Countdown)
	self._Paused = false
	
	if not self._Thread then
		self._Thread = task.spawn(stepCountdownAsync, self)
	else
		task.spawn(self._Thread)
	end
	
	tryExecute(self.OnStart)
end

function Countdown.Pause(self: Countdown)
	self._Paused = true
	
	tryExecute(self.OnPause)
end

function Countdown.Reset(self: Countdown)
	if self._Thread then
		task.cancel(self._Thread)
		
		self._Thread = nil
	end

	self._Paused      = true
	self._SecondsLeft = self._Duration
	
	tryExecute(self.OnReset)
end

function Countdown.Paused(self: Countdown): boolean
	return self._Paused
end

function Countdown.Duration(self: Countdown): number
	return self._Duration
end
--------------------------------------------------



return Countdown
