--------------------------------------------------------------------------------
-- HandThrottleEvent.lua
-- Sincroniza o estado completo do acelerador de mão (ver HandThrottle.copyState):
-- modo, modo em pausa, %, RPM, limite de RPM e velocidades (frente/trás).
-- Cliente -> servidor -> restantes clientes.
--------------------------------------------------------------------------------

HandThrottleEvent = {}
local HandThrottleEvent_mt = Class(HandThrottleEvent, Event)

InitEventClass(HandThrottleEvent, "HandThrottleEvent")


function HandThrottleEvent.emptyNew()
    return Event.new(HandThrottleEvent_mt)
end


function HandThrottleEvent.new(vehicle, state)
    local self = HandThrottleEvent.emptyNew()
    self.vehicle = vehicle
    self.state = state
    return self
end


function HandThrottleEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.state = HandThrottle.readStateFromStream(streamId)
    self:run(connection)
end


function HandThrottleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    HandThrottle.writeStateToStream(streamId, self.state)
end


function HandThrottleEvent:run(connection)
    -- no servidor, reenvia para os outros clientes
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end

    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() and self.vehicle.setHandThrottleState ~= nil then
        self.vehicle:setHandThrottleState(self.state, true)
    end
end


function HandThrottleEvent.sendEvent(vehicle, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HandThrottleEvent.new(vehicle, state), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(HandThrottleEvent.new(vehicle, state))
        end
    end
end
