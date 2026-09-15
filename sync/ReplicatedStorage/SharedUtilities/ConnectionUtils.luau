local connectionUtilities = {}

function connectionUtilities.disconnectConnection(connection: RBXScriptConnection?)
	if connection then
		connection:Disconnect()
	end
end

function connectionUtilities.disconnectConnections(connections: { [any]: RBXScriptConnection? })
	for connectionName, connection in pairs(connections) do
		connectionUtilities.disconnectConnection(connection)
		connections[connectionName] = nil
	end
end

return connectionUtilities
