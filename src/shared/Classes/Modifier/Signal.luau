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
	local listeners = (self :: any)._listeners :: { [number]: (...any) -> () }
	local index = (self :: any)._index :: number?
	if not index then
		return
	end

	listeners[index] = nil;
	(self :: any)._index = nil
end

function Signal.new(): Signal
	local self = setmetatable({}, Signal);
	(self :: any)._listeners = {}
	(self :: any)._nextId = 0
	(self :: any)._destroyed = false
	return (self :: any) :: Signal
end

function Signal.Connect(self: Signal, callback: (...any) -> ()): Connection
	assert(not (self :: any)._destroyed, "Cannot connect to a destroyed Signal")

	local listeners = (self :: any)._listeners :: { [number]: (...any) -> () }
	local nextId = ((self :: any)._nextId :: number) + 1
	(self :: any)._nextId = nextId
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
	if (self :: any)._destroyed then
		return
	end

	(self :: any)._destroyed = true
	table.clear((self :: any)._listeners :: { [number]: (...any) -> () })
end

return table.freeze(Signal)
