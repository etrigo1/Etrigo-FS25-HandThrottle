--------------------------------------------------------------------------------
-- HandThrottleEvent.lua
-- Sincroniza o estado do acelerador de mão (modo, % e RPM alvo).
-- Cliente -> servidor -> restantes clientes.
--------------------------------------------------------------------------------

HandThrottleEvent = {}
local HandThrottleEvent_mt = Class(HandThrottleEvent, Event)

InitEventClass(HandThrottleEvent, "HandThrottleEvent")


function HandThrottleEvent.emptyNew()
    return Event.new(HandThrottleEvent_mt)
end


function HandThrottleEvent.new(vehicle, mode, percent, rpm)
    local self = HandThrottleEvent.emptyNew()
    self.vehicle = vehicle
    self.mode = mode
    self.percent = percent
    self.rpm = rpm
    return self
end


function HandThrottleEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUIntN(streamId, 2)
    self.percent = streamReadUInt8(streamId)
    self.rpm = streamReadUInt16(streamId)
    self:run(connection)
end


function HandThrottleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.mode, 2)
    streamWriteUInt8(streamId, self.percent)
    streamWriteUInt16(streamId, self.rpm)
end


function HandThrottleEvent:run(connection)
    -- no servidor, reenvia para os outros clientes
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end

    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() and self.vehicle.setHandThrottleState ~= nil then
        self.vehicle:setHandThrottleState(self.mode, self.percent, self.rpm, true)
    end
end


function HandThrottleEvent.sendEvent(vehicle, mode, percent, rpm, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HandThrottleEvent.new(vehicle, mode, percent, rpm), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(HandThrottleEvent.new(vehicle, mode, percent, rpm))
        end
    end
end
