--------------------------------------------------------------------------------
-- HandThrottle.lua
-- Especialização: acelerador de mão.
--
-- Modos (a tecla de modo percorre só os que servem para a caixa e estão ligados):
--   caixa manual          : OFF -> % -> RPM -> Limite -> OFF
--   CVT / caixa automática: OFF -> km/h -> Limite -> OFF
--
--   %      : fixa a posição do acelerador (pedal mínimo).
--   RPM    : fixa as RPM alvo; um controlador PI ajusta o pedal sozinho.
--   km/h   : fica na velocidade alvo (limite de velocidade + acelerador a fundo,
--            como o cruise control do jogo, mas com memória própria para a frente e para trás).
--   Limite : as RPM nunca passam do valor definido (o "corte" do motor).
--
-- Tudo o que mexe no motor corre no servidor, em Drivable:updateVehiclePhysics.
-- O pedal do jogador ganha sempre; travar (axisForward < 0) suspende a mão.
-- Configurações por jogador em modSettings/Etrigo_HandThrottle.xml.
--------------------------------------------------------------------------------

HandThrottle = {}
HandThrottle.MOD_NAME = g_currentModName
HandThrottle.SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".handThrottle"

HandThrottle.MODE_OFF = 0
HandThrottle.MODE_PERCENT = 1
HandThrottle.MODE_RPM = 2
HandThrottle.MODE_SPEED = 3
HandThrottle.MODE_RPM_LIMIT = 4
HandThrottle.MODE_BITS = 3

-- nome de cada modo no ficheiro de configurações
HandThrottle.MODE_KEYS = {
    [HandThrottle.MODE_PERCENT] = "percent",
    [HandThrottle.MODE_RPM] = "rpm",
    [HandThrottle.MODE_SPEED] = "speed",
    [HandThrottle.MODE_RPM_LIMIT] = "rpmLimit",
}

-- ordem da tecla de modo
HandThrottle.MANUAL_CYCLE = {HandThrottle.MODE_PERCENT, HandThrottle.MODE_RPM, HandThrottle.MODE_RPM_LIMIT}
HandThrottle.AUTOMATIC_CYCLE = {HandThrottle.MODE_SPEED, HandThrottle.MODE_RPM_LIMIT}

-- Controlador do modo RPM (erro normalizado pela gama de RPM do motor)
HandThrottle.RPM_KP = 1.5               -- ganho proporcional
HandThrottle.RPM_KI = 0.8               -- ganho integral (por segundo)
HandThrottle.PEDAL_RATE = 1.5           -- variação máxima do pedal da mão (por segundo)

-- Modo km/h
HandThrottle.SPEED_START = 1            -- km/h ao ligar parado (e 1.ª vez em marcha-atrás)

-- Alavanca analógica (ação de eixo, sem tecla por defeito)
HandThrottle.AXIS_STEPS_PER_SECOND = 5  -- passos por segundo com a alavanca toda empurrada
HandThrottle.AXIS_DEADZONE = 0.1

-- HUD (coordenadas normalizadas do ecrã; x = borda direita do texto, y = base do texto)
HandThrottle.HUD_DEFAULT_X = 0.985
HandThrottle.HUD_DEFAULT_Y = 0.30
HandThrottle.HUD_BOX_PADDING = 0.004
HandThrottle.SETTINGS_FILE = getUserProfileAppPath() .. "modSettings/Etrigo_HandThrottle.xml"

-- valores por defeito do ficheiro de configurações
HandThrottle.DEFAULT_CONFIG = {
    hud = { x = HandThrottle.HUD_DEFAULT_X, y = HandThrottle.HUD_DEFAULT_Y, textSize = 0.013 },
    modes = {
        percent  = { enabled = true, brakeOff = false, step = 5 },
        rpm      = { enabled = true, brakeOff = false, step = 50 },
        rpmLimit = { enabled = true, brakeOff = false, step = 50 },
        speed    = { enabled = true, brakeOff = true,  step = 1, pedalOffDifference = 5 },
    },
    general = { rememberPerVehicle = true, keyRepeatDelay = 400, keyRepeatInterval = 100 },
}

-- estado do HUD: só local (por jogador), não vai para o savegame nem para a rede
HandThrottle.hud = {
    x = HandThrottle.HUD_DEFAULT_X,
    y = HandThrottle.HUD_DEFAULT_Y,
    isPositioning = false,
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    textWidth = 0.1,
}

HandThrottle.config = nil
HandThrottle.settingsLoaded = false


local function getText(key)
    return g_i18n:getText(key, HandThrottle.MOD_NAME)
end


local function round(value, step)
    return math.floor(value / step + 0.5) * step
end


--------------------------------------------------------------------------------
-- Limite de RPM: o máximo que vai para a física sai de getRequiredMotorRpmRange
-- (WheelsUtil -> controlVehicle). O servidor põe motor.handThrottleRpmLimit em cada frame.
--------------------------------------------------------------------------------
if VehicleMotor ~= nil and VehicleMotor.getRequiredMotorRpmRange ~= nil then
    VehicleMotor.getRequiredMotorRpmRange = Utils.overwrittenFunction(VehicleMotor.getRequiredMotorRpmRange, function(motor, superFunc, ...)
        local minRpm, maxRpm = superFunc(motor, ...)
        local limit = motor.handThrottleRpmLimit
        if limit ~= nil and limit > 0 then
            maxRpm = math.min(maxRpm, limit)
            minRpm = math.min(minRpm, maxRpm)
        end
        return minRpm, maxRpm
    end)
end


--------------------------------------------------------------------------------
-- Configurações (modSettings/Etrigo_HandThrottle.xml, por jogador)
--------------------------------------------------------------------------------
local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and copyTable(value) or value
    end
    return result
end


local function readFloat(xmlFile, key, default, minValue, maxValue)
    local value = getXMLFloat(xmlFile, key)
    if value == nil or value ~= value or value < minValue or value > maxValue then
        return default
    end
    return value
end


local function readBool(xmlFile, key, default)
    local value = getXMLBool(xmlFile, key)
    if value == nil then
        return default
    end
    return value
end


-- lê o ficheiro (valores em falta ou inválidos ficam com o valor por defeito) e volta a gravá-lo completo
function HandThrottle.loadSettings()
    if HandThrottle.settingsLoaded then
        return
    end
    HandThrottle.settingsLoaded = true

    local config = copyTable(HandThrottle.DEFAULT_CONFIG)
    HandThrottle.config = config

    if fileExists(HandThrottle.SETTINGS_FILE) then
        local xmlFile = loadXMLFile("handThrottleSettings", HandThrottle.SETTINGS_FILE)
        if xmlFile ~= nil and xmlFile ~= 0 then
            config.hud.x = readFloat(xmlFile, "handThrottle.hud#x", config.hud.x, 0, 1)
            config.hud.y = readFloat(xmlFile, "handThrottle.hud#y", config.hud.y, 0, 1)
            config.hud.textSize = readFloat(xmlFile, "handThrottle.hud#textSize", config.hud.textSize, 0.005, 0.05)

            for modeKey, modeConfig in pairs(config.modes) do
                local key = "handThrottle.modes." .. modeKey
                modeConfig.enabled = readBool(xmlFile, key .. "#enabled", modeConfig.enabled)
                modeConfig.brakeOff = readBool(xmlFile, key .. "#brakeOff", modeConfig.brakeOff)
                modeConfig.step = readFloat(xmlFile, key .. "#step", modeConfig.step, 0.1, 1000)
                if modeConfig.pedalOffDifference ~= nil then
                    modeConfig.pedalOffDifference = readFloat(xmlFile, key .. "#pedalOffDifference", modeConfig.pedalOffDifference, 0.5, 100)
                end
            end

            config.general.rememberPerVehicle = readBool(xmlFile, "handThrottle.general#rememberPerVehicle", config.general.rememberPerVehicle)
            config.general.keyRepeatDelay = math.floor(readFloat(xmlFile, "handThrottle.general#keyRepeatDelay", config.general.keyRepeatDelay, 0, 5000))
            config.general.keyRepeatInterval = math.floor(readFloat(xmlFile, "handThrottle.general#keyRepeatInterval", config.general.keyRepeatInterval, 16, 5000))

            delete(xmlFile)
        end
    end

    HandThrottle.hud.x = config.hud.x
    HandThrottle.hud.y = config.hud.y

    HandThrottle.saveSettings()
end


function HandThrottle.saveSettings()
    local config = HandThrottle.config
    if config == nil then
        return
    end

    config.hud.x = HandThrottle.hud.x
    config.hud.y = HandThrottle.hud.y

    createFolder(getUserProfileAppPath() .. "modSettings/")

    local xmlFile = createXMLFile("handThrottleSettings", HandThrottle.SETTINGS_FILE, "handThrottle")
    if xmlFile == nil or xmlFile == 0 then
        return
    end

    setXMLFloat(xmlFile, "handThrottle.hud#x", config.hud.x)
    setXMLFloat(xmlFile, "handThrottle.hud#y", config.hud.y)
    setXMLFloat(xmlFile, "handThrottle.hud#textSize", config.hud.textSize)

    for _, modeKey in ipairs({"percent", "rpm", "rpmLimit", "speed"}) do
        local modeConfig = config.modes[modeKey]
        local key = "handThrottle.modes." .. modeKey
        setXMLBool(xmlFile, key .. "#enabled", modeConfig.enabled)
        setXMLBool(xmlFile, key .. "#brakeOff", modeConfig.brakeOff)
        setXMLFloat(xmlFile, key .. "#step", modeConfig.step)
        if modeConfig.pedalOffDifference ~= nil then
            setXMLFloat(xmlFile, key .. "#pedalOffDifference", modeConfig.pedalOffDifference)
        end
    end

    setXMLBool(xmlFile, "handThrottle.general#rememberPerVehicle", config.general.rememberPerVehicle)
    setXMLInt(xmlFile, "handThrottle.general#keyRepeatDelay", config.general.keyRepeatDelay)
    setXMLInt(xmlFile, "handThrottle.general#keyRepeatInterval", config.general.keyRepeatInterval)

    saveXMLFile(xmlFile)
    delete(xmlFile)
end


function HandThrottle.getConfig()
    HandThrottle.loadSettings()
    return HandThrottle.config
end


function HandThrottle.getModeConfig(mode)
    local modeKey = HandThrottle.MODE_KEYS[mode]
    if modeKey == nil then
        return nil
    end
    return HandThrottle.getConfig().modes[modeKey]
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
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", HandThrottle)
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
    spec.rpmLimit = 0
    spec.speedForward = 0       -- km/h, memória para a frente
    spec.speedBackward = 0      -- km/h, memória para trás

    -- modo guardado em pausa (tecla ligar/desligar, sair do trator, desligar o motor)
    -- MODE_OFF = nada guardado. Só dura a sessão de jogo (não vai para o savegame).
    spec.lastMode = HandThrottle.MODE_OFF

    -- só no servidor
    spec.pedal = 0
    spec.integral = 0
    spec.resetController = true

    -- teclas
    spec.actionEvents = {}
    spec.lastInputTime = {}
    spec.nextRepeatTime = {}
    spec.axisAccumulator = 0
    spec.axisLastTime = nil
end


function HandThrottle:onReadStream(streamId, connection)
    self:setHandThrottleState(HandThrottle.readStateFromStream(streamId), true)
end


function HandThrottle:onWriteStream(streamId, connection)
    HandThrottle.writeStateToStream(streamId, HandThrottle.copyState(self.spec_handThrottle))
end


-- onLeaveVehicle e onStopMotor correm no servidor e nos clientes, por isso a pausa não precisa de evento.
-- Se o jogador desligou a memória por trator, quem conduzia esquece e envia o evento.
function HandThrottle:onLeaveVehicle(wasEntered)
    HandThrottle.pauseHandThrottle(self, true)

    if wasEntered then
        if not HandThrottle.getConfig().general.rememberPerVehicle then
            HandThrottle.forgetHandThrottle(self)
        end

        -- só o jogador que estava neste veículo sai do modo posicionar
        if HandThrottle.hud.isPositioning then
            HandThrottle.setHudPositioning(false)
        end
    end
end


function HandThrottle:onStopMotor()
    HandThrottle.pauseHandThrottle(self, true)

    local isEntered = self.getIsEntered ~= nil and self:getIsEntered()
    if isEntered and not HandThrottle.getConfig().general.rememberPerVehicle then
        HandThrottle.forgetHandThrottle(self)
    end
end


--------------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------------
function HandThrottle.copyState(spec)
    return {
        mode = spec.mode,
        lastMode = spec.lastMode,
        percent = spec.percent,
        rpm = spec.rpm,
        rpmLimit = spec.rpmLimit,
        speedForward = spec.speedForward,
        speedBackward = spec.speedBackward,
    }
end


function HandThrottle.writeStateToStream(streamId, state)
    streamWriteUIntN(streamId, state.mode, HandThrottle.MODE_BITS)
    streamWriteUIntN(streamId, state.lastMode, HandThrottle.MODE_BITS)
    streamWriteUInt8(streamId, state.percent)
    streamWriteUInt16(streamId, state.rpm)
    streamWriteUInt16(streamId, state.rpmLimit)
    streamWriteUInt16(streamId, math.floor(state.speedForward * 10 + 0.5))
    streamWriteUInt16(streamId, math.floor(state.speedBackward * 10 + 0.5))
end


function HandThrottle.readStateFromStream(streamId)
    local state = {}
    state.mode = streamReadUIntN(streamId, HandThrottle.MODE_BITS)
    state.lastMode = streamReadUIntN(streamId, HandThrottle.MODE_BITS)
    state.percent = streamReadUInt8(streamId)
    state.rpm = streamReadUInt16(streamId)
    state.rpmLimit = streamReadUInt16(streamId)
    state.speedForward = streamReadUInt16(streamId) / 10
    state.speedBackward = streamReadUInt16(streamId) / 10
    return state
end


-- state: tabela com mode, lastMode, percent, rpm, rpmLimit, speedForward, speedBackward
-- lastMode: modo guardado em pausa (MODE_OFF ou nil = nada guardado)
function HandThrottle:setHandThrottleState(state, noEventSend)
    local spec = self.spec_handThrottle

    if state.mode ~= spec.mode then
        spec.resetController = true
    end

    spec.mode = state.mode
    spec.lastMode = state.mode == HandThrottle.MODE_OFF and (state.lastMode or HandThrottle.MODE_OFF) or HandThrottle.MODE_OFF
    spec.percent = math.clamp(math.floor((state.percent or 0) + 0.5), 0, 100)
    spec.rpm = math.clamp(math.floor((state.rpm or 0) + 0.5), 0, 65535)
    spec.rpmLimit = math.clamp(math.floor((state.rpmLimit or 0) + 0.5), 0, 65535)
    spec.speedForward = math.clamp(round(state.speedForward or 0, 0.1), 0, 6553.5)
    spec.speedBackward = math.clamp(round(state.speedBackward or 0, 0.1), 0, 6553.5)

    if spec.mode == HandThrottle.MODE_OFF then
        spec.pedal = 0
        spec.integral = 0
    end

    if spec.mode ~= HandThrottle.MODE_RPM_LIMIT then
        local motor = self:getMotor()
        if motor ~= nil then
            motor.handThrottleRpmLimit = nil
        end
    end

    HandThrottleEvent.sendEvent(self, HandThrottle.copyState(spec), noEventSend)

    HandThrottle.updateActionEvents(self)
end


-- desliga a mão mas guarda o modo e os valores (não faz nada se já estiver em OFF)
function HandThrottle.pauseHandThrottle(vehicle, noEventSend)
    local spec = vehicle.spec_handThrottle
    if spec.mode ~= HandThrottle.MODE_OFF then
        local state = HandThrottle.copyState(spec)
        state.lastMode = spec.mode
        state.mode = HandThrottle.MODE_OFF
        vehicle:setHandThrottleState(state, noEventSend)
    end
end


-- OFF completo: esquece o modo guardado e todos os valores
function HandThrottle.forgetHandThrottle(vehicle, noEventSend)
    vehicle:setHandThrottleState({ mode = HandThrottle.MODE_OFF }, noEventSend)
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


-- o modo serve para a caixa deste veículo? (não vê se está ligado nas configurações)
function HandThrottle.getModeFitsGearbox(vehicle, mode)
    if mode == HandThrottle.MODE_RPM_LIMIT then
        return true
    end

    local isManual = vehicle:getHandThrottleIsManualTransmission()
    if mode == HandThrottle.MODE_SPEED then
        return not isManual
    end
    return isManual
end


function HandThrottle.getIsModeAvailable(vehicle, mode)
    local modeConfig = HandThrottle.getModeConfig(mode)
    return modeConfig ~= nil and modeConfig.enabled and HandThrottle.getModeFitsGearbox(vehicle, mode)
end


local function getIsCruiseControlOn(vehicle)
    local drivableSpec = vehicle.spec_drivable
    return drivableSpec ~= nil and drivableSpec.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_OFF
end


local function getCanApplyHandThrottle(vehicle, mode)
    if not vehicle:getIsMotorStarted() then
        return false
    end

    if mode == HandThrottle.MODE_RPM_LIMIT then
        return true
    end

    if getIsCruiseControlOn(vehicle) then
        return false
    end

    return HandThrottle.getModeFitsGearbox(vehicle, mode)
end


-- 1 = para a frente, -1 = para trás (só com o inversor manual: sem ele o modo km/h é só para a frente)
function HandThrottle.getSpeedDirection(vehicle)
    local motor = vehicle:getMotor()
    if motor ~= nil and vehicle.getIsManualDirectionChangeActive ~= nil and vehicle:getIsManualDirectionChangeActive()
        and motor.currentDirection ~= nil and motor.currentDirection < 0 then
        return -1
    end
    return 1
end


function HandThrottle.getSpeedTarget(vehicle, spec)
    if HandThrottle.getSpeedDirection(vehicle) < 0 then
        return spec.speedBackward
    end
    return spec.speedForward
end


function HandThrottle.getMaxSpeed(vehicle, direction)
    local motor = vehicle:getMotor()
    local maxSpeed = direction < 0 and motor:getMaximumBackwardSpeed() or motor:getMaximumForwardSpeed()
    return (maxSpeed or 0) * 3.6
end


--------------------------------------------------------------------------------
-- Física (servidor)
--------------------------------------------------------------------------------
function HandThrottle:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
    local spec = self.spec_handThrottle

    if spec ~= nil and self.isServer then
        local motor = self:getMotor()
        if motor ~= nil then
            motor.handThrottleRpmLimit = nil
        end

        if spec.mode ~= HandThrottle.MODE_OFF then
            if getCanApplyHandThrottle(self, spec.mode) then
                if spec.mode == HandThrottle.MODE_PERCENT or spec.mode == HandThrottle.MODE_RPM then
                    local playerOverrides = axisForward < 0 or axisForward > spec.pedal
                    HandThrottle.updatePedal(self, spec, playerOverrides, dt)

                    if axisForward >= 0 then
                        axisForward = math.max(axisForward, spec.pedal)
                    end
                elseif spec.mode == HandThrottle.MODE_SPEED then
                    axisForward = HandThrottle.applySpeedMode(self, spec, axisForward)
                elseif spec.mode == HandThrottle.MODE_RPM_LIMIT then
                    axisForward = HandThrottle.applyRpmLimit(self, spec, axisForward)
                end
            else
                spec.pedal = 0
                spec.integral = 0
                spec.resetController = true
            end
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


-- como o cruise control do jogo: limite de velocidade + acelerador a fundo.
-- O pé (ou o travão) ganha: com o pedal carregado não se mexe em nada.
function HandThrottle.applySpeedMode(vehicle, spec, axisForward)
    if axisForward ~= 0 then
        return axisForward
    end

    local target = HandThrottle.getSpeedTarget(vehicle, spec)
    if target <= 0 then
        return 0
    end

    local motor = vehicle:getMotor()
    motor:setSpeedLimit(math.min(motor:getSpeedLimit(), target))
    return 1
end


function HandThrottle.applyRpmLimit(vehicle, spec, axisForward)
    local motor = vehicle:getMotor()
    motor.handThrottleRpmLimit = spec.rpmLimit

    -- em ponto morto (caixa com mudanças) as RPM vêm do pedal: limitar também o pedal
    if axisForward > 0 and (motor.forwardGears ~= nil or motor.backwardGears ~= nil) then
        local isNeutral = (motor.minGearRatio == 0 and motor.maxGearRatio == 0) or (motor.manualClutchValue or 0) > 0.1
        if isNeutral then
            local minRpm = motor:getMinRpm()
            local range = math.max(motor:getMaxRpm() - minRpm, 1)
            axisForward = math.min(axisForward, math.clamp((spec.rpmLimit - minRpm) / range, 0, 1))
        end
    end

    return axisForward
end


--------------------------------------------------------------------------------
-- Vigia do condutor (cliente): travar e pé a passar o alvo, conforme as configurações
--------------------------------------------------------------------------------
function HandThrottle:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_handThrottle
    if not self.isClient or spec.mode == HandThrottle.MODE_OFF or not isActiveForInputIgnoreSelection then
        return
    end

    local drivableSpec = self.spec_drivable
    if drivableSpec == nil then
        return
    end

    local axisForward = drivableSpec.axisForward or 0
    local modeConfig = HandThrottle.getModeConfig(spec.mode)

    if modeConfig.brakeOff and axisForward < -0.1 then
        HandThrottle.pauseHandThrottle(self)
        return
    end

    if spec.mode == HandThrottle.MODE_SPEED and axisForward > 0.05 then
        if self:getLastSpeed() >= HandThrottle.getSpeedTarget(self, spec) + modeConfig.pedalOffDifference then
            HandThrottle.pauseHandThrottle(self)
        end
    end
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

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_TOGGLE_ON, self, HandThrottle.actionEventToggleOn, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_VALUE_UP, self, HandThrottle.actionEventChangeValue, false, true, true, true, 1)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_VALUE_DOWN, self, HandThrottle.actionEventChangeValue, false, true, true, true, -1)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.HT_AXIS, self, HandThrottle.actionEventAxis, false, false, true, true, nil)
        g_inputBinding:setActionEventTextVisibility(actionEventId, false)

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
        g_inputBinding:setActionEventText(toggleEvent.actionEventId, string.format("%s: %s", getText("ht_label"), HandThrottle.getModeValueText(vehicle, spec)))
    end

    local isOn = spec.mode ~= HandThrottle.MODE_OFF
    for _, actionName in ipairs({InputAction.HT_VALUE_UP, InputAction.HT_VALUE_DOWN}) do
        local actionEvent = spec.actionEvents[actionName]
        if actionEvent ~= nil then
            g_inputBinding:setActionEventActive(actionEvent.actionEventId, isOn)
        end
    end
end


-- velocidade inicial do modo km/h: a atual, arredondada ao passo; parado -> SPEED_START
function HandThrottle.getStartSpeed(vehicle, direction)
    local step = HandThrottle.getModeConfig(HandThrottle.MODE_SPEED).step
    local speed = round(vehicle:getLastSpeed(), step)
    if speed < HandThrottle.SPEED_START then
        speed = HandThrottle.SPEED_START
    end
    return math.min(speed, HandThrottle.getMaxSpeed(vehicle, direction))
end


-- liga o modo km/h na velocidade atual (no sentido de marcha atual); o outro sentido mantém a memória
function HandThrottle.prepareSpeedState(vehicle, state)
    local direction = HandThrottle.getSpeedDirection(vehicle)
    local startSpeed = HandThrottle.getStartSpeed(vehicle, direction)

    if direction < 0 then
        state.speedBackward = startSpeed
        if state.speedForward <= 0 then
            state.speedForward = HandThrottle.SPEED_START
        end
    else
        state.speedForward = startSpeed
        if state.speedBackward <= 0 then
            state.speedBackward = HandThrottle.SPEED_START
        end
    end

    -- o cruise control do jogo e o modo km/h não trabalham ao mesmo tempo
    if getIsCruiseControlOn(vehicle) then
        vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
    end
end


-- liga um modo pela tecla de modo (começa sempre do zero: esquece o que estava em pausa)
function HandThrottle.activateMode(vehicle, mode)
    local spec = vehicle.spec_handThrottle
    local state = HandThrottle.copyState(spec)
    state.mode = mode
    state.lastMode = HandThrottle.MODE_OFF

    if mode == HandThrottle.MODE_OFF then
        HandThrottle.forgetHandThrottle(vehicle)
        return
    elseif mode == HandThrottle.MODE_PERCENT then
        -- começa sempre a 0 % para o trator não arrancar sozinho
        state.percent = 0
    elseif mode == HandThrottle.MODE_RPM then
        -- começa nas RPM atuais, arredondadas ao passo
        state.rpm = HandThrottle.getClampedRpm(vehicle, vehicle:getMotor():getLastMotorRpm())
    elseif mode == HandThrottle.MODE_RPM_LIMIT then
        -- começa nas RPM máximas: ainda não corta nada
        state.rpmLimit = vehicle:getMotor():getMaxRpm()
    elseif mode == HandThrottle.MODE_SPEED then
        HandThrottle.prepareSpeedState(vehicle, state)
    end

    vehicle:setHandThrottleState(state)
end


function HandThrottle:actionEventToggleMode(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_handThrottle

    local cycle = self:getHandThrottleIsManualTransmission() and HandThrottle.MANUAL_CYCLE or HandThrottle.AUTOMATIC_CYCLE
    local available = {}
    for _, mode in ipairs(cycle) do
        if HandThrottle.getModeConfig(mode).enabled then
            table.insert(available, mode)
        end
    end

    if #available == 0 then
        if spec.mode ~= HandThrottle.MODE_OFF or spec.lastMode ~= HandThrottle.MODE_OFF then
            HandThrottle.forgetHandThrottle(self)
        end
        g_currentMission:showBlinkingWarning(getText("ht_warning_noModes"), 2000)
        return
    end

    local nextMode = available[1]
    if spec.mode ~= HandThrottle.MODE_OFF then
        local index = nil
        for i, mode in ipairs(available) do
            if mode == spec.mode then
                index = i
            end
        end

        if index == #available then
            nextMode = HandThrottle.MODE_OFF
        elseif index ~= nil then
            nextMode = available[index + 1]
        end
    end

    HandThrottle.activateMode(self, nextMode)
end


-- liga/desliga a mão sem perder o modo e os valores (ex.: nas cabeceiras)
function HandThrottle:actionEventToggleOn(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_handThrottle

    if spec.mode ~= HandThrottle.MODE_OFF then
        HandThrottle.pauseHandThrottle(self)
        return
    end

    if spec.lastMode == HandThrottle.MODE_OFF then
        -- nada guardado: igual à tecla de modo
        HandThrottle.actionEventToggleMode(self, actionName, inputValue, callbackState, isAnalog)
        return
    end

    if not HandThrottle.getIsModeAvailable(self, spec.lastMode) then
        g_currentMission:showBlinkingWarning(getText("ht_warning_modeUnavailable"), 2000)
        return
    end

    local state = HandThrottle.copyState(spec)
    state.mode = spec.lastMode

    -- o modo km/h retoma na velocidade atual, não na antiga
    if state.mode == HandThrottle.MODE_SPEED then
        HandThrottle.prepareSpeedState(self, state)
    end

    self:setHandThrottleState(state)
end


-- muda o valor do modo ativo um passo para cima (1) ou para baixo (-1)
function HandThrottle.changeValue(vehicle, direction)
    local spec = vehicle.spec_handThrottle
    local modeConfig = HandThrottle.getModeConfig(spec.mode)
    if modeConfig == nil then
        return
    end

    local step = modeConfig.step
    local state = HandThrottle.copyState(spec)

    if spec.mode == HandThrottle.MODE_PERCENT then
        state.percent = math.clamp(spec.percent + direction * step, 0, 100)
    elseif spec.mode == HandThrottle.MODE_RPM then
        state.rpm = HandThrottle.getClampedRpm(vehicle, spec.rpm + direction * step)
    elseif spec.mode == HandThrottle.MODE_RPM_LIMIT then
        state.rpmLimit = HandThrottle.getClampedRpm(vehicle, spec.rpmLimit + direction * step, HandThrottle.MODE_RPM_LIMIT)
    elseif spec.mode == HandThrottle.MODE_SPEED then
        local speedDirection = HandThrottle.getSpeedDirection(vehicle)
        local maxSpeed = HandThrottle.getMaxSpeed(vehicle, speedDirection)
        if speedDirection < 0 then
            state.speedBackward = math.clamp(round(spec.speedBackward + direction * step, step), 0, maxSpeed)
        else
            state.speedForward = math.clamp(round(spec.speedForward + direction * step, step), 0, maxSpeed)
        end
    end

    vehicle:setHandThrottleState(state)
end


function HandThrottle:actionEventChangeValue(actionName, inputValue, direction, isAnalog)
    local spec = self.spec_handThrottle
    if spec.mode == HandThrottle.MODE_OFF or inputValue <= 0 then
        return
    end

    -- primeiro toque muda logo; com a tecla carregada repete depois do tempo configurado
    local general = HandThrottle.getConfig().general
    local lastTime = spec.lastInputTime[actionName]
    spec.lastInputTime[actionName] = g_time

    if lastTime == nil or g_time - lastTime > 150 then
        spec.nextRepeatTime[actionName] = g_time + general.keyRepeatDelay
    elseif g_time >= spec.nextRepeatTime[actionName] then
        spec.nextRepeatTime[actionName] = g_time + general.keyRepeatInterval
    else
        return
    end

    HandThrottle.changeValue(self, direction)
end


-- alavanca analógica: quanto mais empurrada, mais depressa muda; no centro mantém.
-- Junta as frações e só muda (e só envia evento) a cada passo inteiro.
function HandThrottle:actionEventAxis(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_handThrottle
    local lastTime = spec.axisLastTime
    spec.axisLastTime = g_time

    if spec.mode == HandThrottle.MODE_OFF or math.abs(inputValue) < HandThrottle.AXIS_DEADZONE then
        spec.axisAccumulator = 0
        return
    end

    local elapsed = lastTime ~= nil and math.min(g_time - lastTime, 100) or 0
    spec.axisAccumulator = spec.axisAccumulator + inputValue * HandThrottle.AXIS_STEPS_PER_SECOND * elapsed * 0.001

    while spec.axisAccumulator >= 1 do
        spec.axisAccumulator = spec.axisAccumulator - 1
        HandThrottle.changeValue(self, 1)
    end
    while spec.axisAccumulator <= -1 do
        spec.axisAccumulator = spec.axisAccumulator + 1
        HandThrottle.changeValue(self, -1)
    end
end


-- arredonda ao passo do modo (RPM ou Limite) e prende entre o ralenti e as RPM máximas
function HandThrottle.getClampedRpm(vehicle, rpm, mode)
    local motor = vehicle:getMotor()
    local step = HandThrottle.getModeConfig(mode or HandThrottle.MODE_RPM).step
    rpm = round(rpm, step)
    return math.clamp(rpm, motor:getMinRpm(), motor:getMaxRpm())
end


--------------------------------------------------------------------------------
-- HUD (cliente)
--------------------------------------------------------------------------------
function HandThrottle.formatSpeed(kmh)
    local value = string.format("%.1f", g_i18n:getSpeed(kmh))
    value = (value:gsub("%.0$", ""))
    return value .. " " .. g_i18n:getSpeedMeasuringUnit()
end


function HandThrottle.getModeValueText(vehicle, spec)
    if spec.mode == HandThrottle.MODE_PERCENT then
        return string.format("%d %%", spec.percent)
    elseif spec.mode == HandThrottle.MODE_RPM then
        return string.format("%d RPM", spec.rpm)
    elseif spec.mode == HandThrottle.MODE_RPM_LIMIT then
        return string.format("%s %d RPM", getText("ht_limit_prefix"), spec.rpmLimit)
    elseif spec.mode == HandThrottle.MODE_SPEED then
        local text = HandThrottle.formatSpeed(HandThrottle.getSpeedTarget(vehicle, spec))
        if HandThrottle.getSpeedDirection(vehicle) < 0 then
            text = text .. " " .. getText("ht_reverse")
        end
        return text
    end
    return getText("ht_mode_off")
end


function HandThrottle:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_handThrottle
    local hud = HandThrottle.hud

    -- em OFF só aparece se estiver em pausa (modo guardado) ou a posicionar
    if spec.mode == HandThrottle.MODE_OFF and spec.lastMode == HandThrottle.MODE_OFF and not hud.isPositioning then
        return
    end

    local config = HandThrottle.getConfig()

    local text = string.format("%s: %s", getText("ht_label"), HandThrottle.getModeValueText(self, spec))
    if spec.mode ~= HandThrottle.MODE_OFF and not getCanApplyHandThrottle(self, spec.mode) then
        text = text .. " " .. getText("ht_mode_off")
    end

    local size = config.hud.textSize
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
    local size = HandThrottle.getConfig().hud.textSize
    return hud.x - hud.textWidth - pad, hud.y - pad, hud.textWidth + 2 * pad, size + 2 * pad
end


-- mantém o texto inteiro dentro do ecrã
function HandThrottle.clampHudPosition()
    local hud = HandThrottle.hud
    hud.x = math.clamp(hud.x, hud.textWidth, 1)
    hud.y = math.clamp(hud.y, 0, 1 - HandThrottle.getConfig().hud.textSize)
end


function HandThrottle.setHudPositioning(isActive)
    local hud = HandThrottle.hud
    hud.isPositioning = isActive
    hud.isDragging = false

    g_inputBinding:setShowMouseCursor(isActive)
    if not isActive then
        HandThrottle.saveSettings()
    end
end


function HandThrottle:actionEventMoveHud(actionName, inputValue, callbackState, isAnalog)
    HandThrottle.loadSettings()
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
