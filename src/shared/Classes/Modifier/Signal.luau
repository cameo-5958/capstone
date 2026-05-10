--!strict

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Once: (self: Signal, callback: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Destroy: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: Connection)
	local selfAny = self :: any
	local listeners = selfAny._listeners :: { [number]: (...any) -> () }
	local index = selfAny._index :: number?
	if not index then
		return
	end

	listeners[index] = nil;
	selfAny._index = nil
end

function Signal.new(): Signal
	local self = setmetatable({}, Signal);
	local selfAny = self :: any
	selfAny._listeners = {}
	selfAny._nextId = 0
	selfAny._destroyed = false
	return selfAny :: Signal
end

function Signal.Connect(self: Signal, callback: (...any) -> ()): Connection
	local selfAny = self :: any
	assert(not selfAny._destroyed, "Cannot connect to a destroyed Signal")

	local listeners = selfAny._listeners :: { [number]: (...any) -> () }
	local nextId = (selfAny._nextId :: number) + 1
	selfAny._nextId = nextId
	listeners[nextId] = callback

	return setmetatable({
		_listeners = listeners,
		_index = nextId,
	}, Connection) :: any
end

function Signal.Once(self: Signal, callback: (...any) -> ()): Connection
	local connection: Connection? = nil
	connection = self:Connect(function(...)
		if connection then
			connection:Disconnect()
		end
		callback(...)
	end)

	return connection
end

function Signal.Fire(self: Signal, ...: any)
	if (self :: any)._destroyed then
		return
	end

	for _, callback in pairs((self :: any)._listeners :: { [number]: (...any) -> () }) do
		callback(...)
	end
end

function Signal.Destroy(self: Signal)
	local selfAny = self :: any
	if selfAny._destroyed then
		return
	end

	selfAny._destroyed = true
	table.clear(selfAny._listeners :: { [number]: (...any) -> () })
end

return table.freeze(Signal)
