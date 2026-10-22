--------------------------------------------------------------------------------
-- HandThrottle.lua
-- Especialização: acelerador de mão para caixas manuais.
--
-- Modos:  OFF -> % -> RPM -> OFF
--   %   : fixa a posição do acelerador (pedal mínimo).
--   RPM : fixa as RPM alvo; um controlador PI ajusta o pedal sozinho.
--
-- O pedal é injetado no servidor, em Drivable:updateVehiclePhysics:
--   axisForward = max(axisForward, pedalMão)
-- O pedal do jogador ganha sempre; travar (axisForward < 0) suspende a mão.
--------------------------------------------------------------------------------

HandThrottle = {}
HandThrottle.MOD_NAME = g_currentModName
HandThrottle.SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".handThrottle"

HandThrottle.MODE_OFF = 0
HandThrottle.MODE_PERCENT = 1
HandThrottle.MODE_RPM = 2

-- Teclas
HandThrottle.PERCENT_STEP = 5           -- % por toque
HandThrottle.RPM_STEP = 50              -- RPM por toque
HandThrottle.REPEAT_DELAY = 400         -- ms até começar a repetir com a tecla carregada
HandThrottle.REPEAT_INTERVAL = 100      -- ms entre repetições

-- Controlador do modo RPM (erro normalizado pela gama de RPM do motor)
HandThrottle.RPM_KP = 1.5               -- ganho proporcional
HandThrottle.RPM_KI = 0.8               -- ganho integral (por segundo)
HandThrottle.PEDAL_RATE = 1.5           -- variação máxima do pedal da mão (por segundo)

-- HUD (coordenadas normalizadas do ecrã; x = borda direita do texto, y = base do texto)
HandThrottle.HUD_DEFAULT_X = 0.985
HandThrottle.HUD_DEFAULT_Y = 0.30
HandThrottle.HUD_TEXT_SIZE = 0.016
HandThrottle.HUD_BOX_PADDING = 0.004
HandThrottle.SETTINGS_FILE = getUserProfileAppPath() .. "modSettings/Etrigo_HandThrottle.xml"

-- estado do HUD: só local (por jogador), não vai para o savegame nem para a rede
HandThrottle.hud = {
    x = HandThrottle.HUD_DEFAULT_X,
    y = HandThrottle.HUD_DEFAULT_Y,
    isLoaded = false,
    isPositioning = false,
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    textWidth = 0.1,
}


local function getText(key)
    return g_i18n:getText(key, HandThrottle.MOD_NAME)
end


--------------------------------------------------------------------------------
-- Registo
--------------------------------------------------------------------------------
function HandThrottle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Drivable, specializations)
        and SpecializationUtil.hasSpecialization(Motorized, specializations)
end


function HandThrottle.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setHandThrottleState", HandThrottle.setHandThrottleState)
    SpecializationUtil.registerFunction(vehicleType, "getHandThrottleIsManualTransmission", HandThrottle.getHandThrottleIsManualTransmission)
end


function HandThrottle.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics", HandThrottle.updateVehiclePhysics)
end


function HandThrottle.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", HandThrottle)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", HandThrottle)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", HandThrottle)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", HandThrottle)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", HandThrottle)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", HandThrottle)
    SpecializationUtil.registerEventListener(vehicleType, "onStopMotor", HandThrottle)
end


--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function HandThrottle:onLoad(savegame)
    -- a spec é registada como "<modName>.handThrottle"; atalho com nome simples
    self.spec_handThrottle = self[HandThrottle.SPEC_TABLE_NAME] or {}
    local spec = self.spec_handThrottle

    spec.mode = HandThrottle.MODE_OFF
    spec.percent = 0
    spec.rpm = 0

    -- só no servidor
    spec.pedal = 0
    spec.integral = 0
    spec.resetController = true

    -- teclas
    spec.actionEvents = {}
    spec.lastInputTime = {}
    spec.nextRepeatTime = {}
end


function HandThrottle:onReadStream(streamId, connection)
    local spec = self.spec_handThrottle
    spec.mode = streamReadUIntN(streamId, 2)
    spec.percent = streamReadUInt8(streamId)
    spec.rpm = streamReadUInt16(streamId)
end


function HandThrottle:onWriteStream(streamId, connection)
    local spec = self.spec_handThrottle
    streamWriteUIntN(streamId, spec.mode, 2)
    streamWriteUInt8(streamId, spec.percent)
    streamWriteUInt16(streamId, spec.rpm)
end


-- onLeaveVehicle e onStopMotor correm no servidor e nos clientes, por isso não é preciso evento
function HandThrottle:onLeaveVehicle(wasEntered)
    self:setHandThrottleState(HandThrottle.MODE_OFF, 0, 0, true)

    -- só o jogador que estava neste veículo sai do modo posicionar
    if wasEntered and HandThrottle.hud.isPositioning then
        HandThrottle.setHudPositioning(false)
    end
end


function HandThrottle:onStopMotor()
    self:setHandThrottleState(HandThrottle.MODE_OFF, 0, 0, true)
end


--------------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------------
function HandThrottle:setHandThrottleState(mode, percent, rpm, noEventSend)
    local spec = self.spec_handThrottle

    if mode ~= spec.mode then
        spec.resetController = true
    end

    spec.mode = mode
    spec.percent = math.clamp(math.floor(percent + 0.5), 0, 100)
    spec.rpm = math.clamp(math.floor(rpm + 0.5), 0, 65535)

    if mode == HandThrottle.MODE_OFF then
        spec.pedal = 0
        spec.integral = 0
    end

    HandThrottleEvent.sendEvent(self, spec.mode, spec.percent, spec.rpm, noEventSend)

    HandThrottle.updateActionEvents(self)
end


-- Caixa com mudanças e o jogador a meter as mudanças à mão (CVT fica excluída)
function HandThrottle:getHandThrottleIsManualTransmission()
    local motor = self:getMotor()
    if motor == nil then
        return false
    end

    if motor.forwardGears == nil and motor.backwardGears == nil then
        return false
    end

    return not motor:getUseAutomaticGearShifting()
end


local function getCanApplyHandThrottle(vehicle)
    if not vehicle:getIsMotorStarted() then
        return false
    end

    local drivableSpec = vehicle.spec_drivable
    if drivableSpec ~= nil and drivableSpec.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_OFF then
        return false
    end

    return vehicle:getHandThrottleIsManualTransmission()
end


--------------------------------------------------------------------------------
-- Física (servidor)
--------------------------------------------------------------------------------
function HandThrottle:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
    local spec = self.spec_handThrottle

    if spec ~= nil and self.isServer and spec.mode ~= HandThrottle.MODE_OFF then
        if getCanApplyHandThrottle(self) then
            local playerOverrides = axisForward < 0 or axisForward > spec.pedal
            HandThrottle.updatePedal(self, spec, playerOverrides, dt)

            if axisForward >= 0 then
                axisForward = math.max(axisForward, spec.pedal)
            end
        else
            spec.pedal = 0
            spec.integral = 0
            spec.resetController = true
        end
    end

    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
end


function HandThrottle.updatePedal(vehicle, spec, playerOverrides, dt)
    local maxStep = HandThrottle.PEDAL_RATE * dt * 0.001
    local target

    if spec.mode == HandThrottle.MODE_PERCENT then
        target = spec.percent / 100
    else
        local motor = vehicle:getMotor()
        local minRpm, maxRpm = motor:getMinRpm(), motor:getMaxRpm()
        local range = math.max(maxRpm - minRpm, 1)

        -- antecipação: em ponto morto o jogo põe as RPM em minRpm + gama * pedal
        local base = math.clamp((spec.rpm - minRpm) / range, 0, 1)

        if spec.resetController then
            spec.integral = spec.pedal - base
            spec.resetController = false
        end

        -- durante a troca de mudança o jogo põe o pedal a 0: manter tudo como está
        if motor.gearChangeTimer ~= nil and motor.gearChangeTimer >= 0 then
            return
        end

        local err = (spec.rpm - motor:getLastMotorRpm()) / range
        local unclamped = base + HandThrottle.RPM_KP * err + spec.integral
        target = math.clamp(unclamped, 0, 1)

        -- anti-windup: não integrar se saturado nesse sentido ou se o jogador está a mandar no pedal
        local saturated = (unclamped >= 1 and err > 0) or (unclamped <= 0 and err < 0)
        if not saturated and not playerOverrides then
            spec.integral = math.clamp(spec.integral + HandThrottle.RPM_KI * err * dt * 0.001, -1, 1)
        end
    end

    spec.pedal = spec.pedal + math.clamp(target - spec.pedal, -maxStep, maxStep)
end


--------------------------------------------------------------------------------
-- Teclas (cliente)
--------------------------------------------------------------------------------
function HandThrottle:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if not self.isClient then
        return
    end

    local spec = self.spec_handThrottle
    self:clearActionEventsTable(spec.actionEvents)

    if isActiveForInputIgnoreSelection then
        local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_TOGGLE_MODE, self, HandThrottle.actionEventToggleMode, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_VALUE_UP, self, HandThrottle.actionEventChangeValue, false, true, true, true, 1)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_VALUE_DOWN, self, HandThrottle.actionEventChangeValue, false, true, true, true, -1)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_MOVE_HUD, self, HandThrottle.actionEventMoveHud, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW or GS_PRIO_LOW)

        HandThrottle.updateActionEvents(self)
    end
end


function HandThrottle.updateActionEvents(vehicle)
    local spec = vehicle.spec_handThrottle
    if spec == nil or not vehicle.isClient then
        return
    end

    local toggleEvent = spec.actionEvents[InputAction.HT_TOGGLE_MODE]
    if toggleEvent ~= nil then
        g_inputBinding:setActionEventText(toggleEvent.actionEventId, string.format("%s: %s", getText("ht_label"), HandThrottle.getModeValueText(spec)))
    end

    local isOn = spec.mode ~= HandThrottle.MODE_OFF
    for _, actionName in ipairs({InputAction.HT_VALUE_UP, InputAction.HT_VALUE_DOWN}) do
        local actionEvent = spec.actionEvents[actionName]
        if actionEvent ~= nil then
            g_inputBinding:setActionEventActive(actionEvent.actionEventId, isOn)
        end
    end
end


function HandThrottle:actionEventToggleMode(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_handThrottle

    if not self:getHandThrottleIsManualTransmission() then
        if spec.mode ~= HandThrottle.MODE_OFF then
            self:setHandThrottleState(HandThrottle.MODE_OFF, 0, 0)
        end
        g_currentMission:showBlinkingWarning(getText("ht_warning_manualOnly"), 2000)
        return
    end

    if spec.mode == HandThrottle.MODE_OFF then
        -- começa sempre a 0 % para o trator não arrancar sozinho
        self:setHandThrottleState(HandThrottle.MODE_PERCENT, 0, spec.rpm)
    elseif spec.mode == HandThrottle.MODE_PERCENT then
        -- começa nas RPM atuais, arredondadas ao passo
        self:setHandThrottleState(HandThrottle.MODE_RPM, spec.percent, HandThrottle.getClampedRpm(self, self:getMotor():getLastMotorRpm()))
    else
        self:setHandThrottleState(HandThrottle.MODE_OFF, 0, 0)
    end
end


function HandThrottle:actionEventChangeValue(actionName, inputValue, direction, isAnalog)
    local spec = self.spec_handThrottle
    if spec.mode == HandThrottle.MODE_OFF or inputValue <= 0 then
        return
    end

    -- primeiro toque muda logo; com a tecla carregada repete depois de REPEAT_DELAY
    local lastTime = spec.lastInputTime[actionName]
    spec.lastInputTime[actionName] = g_time

    if lastTime == nil or g_time - lastTime > 150 then
        spec.nextRepeatTime[actionName] = g_time + HandThrottle.REPEAT_DELAY
    elseif g_time >= spec.nextRepeatTime[actionName] then
        spec.nextRepeatTime[actionName] = g_time + HandThrottle.REPEAT_INTERVAL
    else
        return
    end

    if spec.mode == HandThrottle.MODE_PERCENT then
        self:setHandThrottleState(spec.mode, math.clamp(spec.percent + direction * HandThrottle.PERCENT_STEP, 0, 100), spec.rpm)
    else
        self:setHandThrottleState(spec.mode, spec.percent, HandThrottle.getClampedRpm(self, spec.rpm + direction * HandThrottle.RPM_STEP))
    end
end


function HandThrottle.getClampedRpm(vehicle, rpm)
    local motor = vehicle:getMotor()
    local step = HandThrottle.RPM_STEP
    rpm = math.floor(rpm / step + 0.5) * step
    return math.clamp(rpm, motor:getMinRpm(), motor:getMaxRpm())
end


--------------------------------------------------------------------------------
-- HUD (cliente)
--------------------------------------------------------------------------------
function HandThrottle.getModeValueText(spec)
    if spec.mode == HandThrottle.MODE_PERCENT then
        return string.format("%d %%", spec.percent)
    elseif spec.mode == HandThrottle.MODE_RPM then
        return string.format("%d RPM", spec.rpm)
    end
    return getText("ht_mode_off")
end


function HandThrottle:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_handThrottle
    local hud = HandThrottle.hud
    if spec.mode == HandThrottle.MODE_OFF and not hud.isPositioning then
        return
    end

    HandThrottle.loadHudPosition()

    local text = string.format("%s: %s", getText("ht_label"), HandThrottle.getModeValueText(spec))
    if spec.mode ~= HandThrottle.MODE_OFF and not getCanApplyHandThrottle(self) then
        text = text .. " " .. getText("ht_inactive")
    end

    local size = HandThrottle.HUD_TEXT_SIZE
    setTextBold(true)
    hud.textWidth = getTextWidth(size, text)

    if hud.isPositioning then
        local bx, by, bw, bh = HandThrottle.getHudBox()
        drawFilledRect(bx, by, bw, bh, 0, 0, 0, 0.5)
    end

    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(1, 1, 1, 1)
    renderText(hud.x, hud.y, size, text)
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
end


--------------------------------------------------------------------------------
-- Mover o HUD (cliente, só local)
--------------------------------------------------------------------------------

-- caixa à volta do texto: x, y, largura, altura
function HandThrottle.getHudBox()
    local hud = HandThrottle.hud
    local pad = HandThrottle.HUD_BOX_PADDING
    local size = HandThrottle.HUD_TEXT_SIZE
    return hud.x - hud.textWidth - pad, hud.y - pad, hud.textWidth + 2 * pad, size + 2 * pad
end


-- mantém o texto inteiro dentro do ecrã
function HandThrottle.clampHudPosition()
    local hud = HandThrottle.hud
    hud.x = math.clamp(hud.x, hud.textWidth, 1)
    hud.y = math.clamp(hud.y, 0, 1 - HandThrottle.HUD_TEXT_SIZE)
end


function HandThrottle.loadHudPosition()
    local hud = HandThrottle.hud
    if hud.isLoaded then
        return
    end
    hud.isLoaded = true

    if fileExists(HandThrottle.SETTINGS_FILE) then
        local xmlFile = loadXMLFile("handThrottleSettings", HandThrottle.SETTINGS_FILE)
        if xmlFile ~= nil and xmlFile ~= 0 then
            hud.x = getXMLFloat(xmlFile, "handThrottle.hud#x") or hud.x
            hud.y = getXMLFloat(xmlFile, "handThrottle.hud#y") or hud.y
            delete(xmlFile)
        end
    end
end


function HandThrottle.saveHudPosition()
    local hud = HandThrottle.hud
    createFolder(getUserProfileAppPath() .. "modSettings/")

    local xmlFile = createXMLFile("handThrottleSettings", HandThrottle.SETTINGS_FILE, "handThrottle")
    if xmlFile ~= nil and xmlFile ~= 0 then
        setXMLFloat(xmlFile, "handThrottle.hud#x", hud.x)
        setXMLFloat(xmlFile, "handThrottle.hud#y", hud.y)
        saveXMLFile(xmlFile)
        delete(xmlFile)
    end
end


function HandThrottle.setHudPositioning(isActive)
    local hud = HandThrottle.hud
    hud.isPositioning = isActive
    hud.isDragging = false

    g_inputBinding:setShowMouseCursor(isActive)
    if not isActive then
        HandThrottle.saveHudPosition()
    end
end


function HandThrottle:actionEventMoveHud(actionName, inputValue, callbackState, isAnalog)
    HandThrottle.loadHudPosition()
    HandThrottle.setHudPositioning(not HandThrottle.hud.isPositioning)
end


-- chamado pelo mouseEvent do mod (RegisterHandThrottle.lua)
-- arrastar com o botão esquerdo; botão direito em cima do HUD repõe a posição de origem
function HandThrottle.onMouseEvent(posX, posY, isDown, isUp, button)
    local hud = HandThrottle.hud
    if not hud.isPositioning then
        return
    end

    local bx, by, bw, bh = HandThrottle.getHudBox()
    local isMouseOver = posX >= bx and posX <= bx + bw and posY >= by and posY <= by + bh

    if isDown and button == Input.MOUSE_BUTTON_LEFT and isMouseOver then
        hud.isDragging = true
        hud.dragOffsetX = hud.x - posX
        hud.dragOffsetY = hud.y - posY
    elseif isUp and button == Input.MOUSE_BUTTON_LEFT then
        hud.isDragging = false
    elseif isDown and button == Input.MOUSE_BUTTON_RIGHT and isMouseOver then
        hud.x = HandThrottle.HUD_DEFAULT_X
        hud.y = HandThrottle.HUD_DEFAULT_Y
    end

    if hud.isDragging then
        hud.x = posX + hud.dragOffsetX
        hud.y = posY + hud.dragOffsetY
        HandThrottle.clampHudPosition()
    end
end
