--------------------------------------------------------------------------------
-- HandThrottle.lua
-- Especialização: acelerador de mão.
--
-- Modos (a tecla de modo percorre só os que servem para a caixa e estão ligados):
--   caixa manual          : desligado -> % -> RPM -> Limite -> desligado
--   CVT / caixa automática: desligado -> km/h -> Limite -> desligado
--
-- Estados (como o cruise control e o limitador de um carro, que partilham os botões):
--   desligado (mode = OFF, lastMode = OFF): sem HUD; as teclas são do cruise control
--                                          (jogo ou Vehicle Inspector).
--   pausa     (mode = OFF, lastMode = modo): HUD com "OFF"; ligar/desligar retoma.
--   ligado    (mode = modo)
--   Em pausa ou ligado o cruise control fica bloqueado: as teclas dele são desativadas
--   e, se ligar por outro caminho, é desligado logo.
--
--   %      : fixa a posição do acelerador (pedal mínimo). Numa CVT com o CVT Addon
--            não mexe no pedal: passa o valor ao acelerador de mão do CVT Addon.
--   RPM    : fixa as RPM alvo; um controlador PI ajusta o pedal sozinho.
--   km/h   : fica na velocidade alvo (limite de velocidade + acelerador a fundo,
--            como o cruise control do jogo, mas com memória própria para a frente e para trás).
--   Limite : as RPM nunca passam do valor definido (o "corte" do motor).
--
-- Arrasto ao ralenti (opção, ligada por defeito): na caixa manual com embraiagem, com mudança
-- engatada e sem acelerador, o trator anda ao ralenti como num trator real.
--
-- Tudo o que mexe no motor corre no servidor, em Drivable:updateVehiclePhysics.
-- O pedal do jogador ganha sempre; travar (axisForward < 0) suspende a mão.
-- Configurações por jogador em modSettings/HandThrottle.xml.
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
-- CVT com o CVT Addon: o modo % manda no acelerador de mão do CVT Addon
HandThrottle.CVT_ADDON_CYCLE = {HandThrottle.MODE_PERCENT, HandThrottle.MODE_SPEED, HandThrottle.MODE_RPM_LIMIT}

-- Controlador do modo RPM (erro normalizado pela gama de RPM do motor)
HandThrottle.RPM_KP = 1.5               -- ganho proporcional
HandThrottle.RPM_KI = 0.8               -- ganho integral (por segundo)
HandThrottle.PEDAL_RATE = 1.5           -- variação máxima do pedal da mão (por segundo)

-- Modo km/h
HandThrottle.SPEED_START = 1            -- km/h ao ligar parado (e 1.ª vez em marcha-atrás)

-- Subir/descer ligado a um eixo analógico (a mesma ação aceita teclas e eixos)
HandThrottle.AXIS_STEPS_PER_SECOND = 5  -- passos por segundo com o eixo todo empurrado
HandThrottle.AXIS_DEADZONE = 0.1

-- ações do cruise control desativadas enquanto o acelerador de mão estiver ligado ou em pausa
HandThrottle.CRUISE_CONTROL_ACTIONS = {"TOGGLE_CRUISE_CONTROL", "AXIS_CRUISE_CONTROL"}
HandThrottle.VEHICLE_INSPECTOR_ACTIONS = {"VI_SPEEDCONTROL_SPEED1", "VI_SPEEDCONTROL_SPEED2", "VI_SPEEDCONTROL_SPEED3", "VI_SPEEDCONTROL_AXIS_SETSPEED"}

-- HUD (coordenadas normalizadas do ecrã; x = borda direita do texto, y = base do texto)
HandThrottle.HUD_DEFAULT_X = 0.985
HandThrottle.HUD_DEFAULT_Y = 0.30
HandThrottle.HUD_BOX_PADDING = 0.004
-- nome do ficheiro fixo (sem "Etrigo_" nem "FS25_"): igual seja qual for o nome do zip
HandThrottle.SETTINGS_FILE = getUserProfileAppPath() .. "modSettings/HandThrottle.xml"
HandThrottle.SETTINGS_FILE_OLD = getUserProfileAppPath() .. "modSettings/Etrigo_HandThrottle.xml"

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
    -- arrasto ao ralenti: caixa manual com embraiagem, mudança engatada, sem acelerador
    -- clutchCurve: como a força cresce com o curso da embraiagem (1 = a direito, <1 morde mais cedo, >1 mais suave no início)
    idleCreep = { enabled = true, torque = 1.0, clutchCurve = 1.0 },
    -- log de diagnóstico no log.txt do jogo (para encontrar problemas)
    debug = { enabled = false },
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
-- Configurações (modSettings/HandThrottle.xml, por jogador)
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

    -- até à v1.7.0.1 o ficheiro chamava-se Etrigo_HandThrottle.xml: lê-o uma vez se ainda não houver o novo
    -- (o saveSettings no fim grava já no novo; o antigo fica como estava)
    local settingsFile = HandThrottle.SETTINGS_FILE
    if not fileExists(settingsFile) and fileExists(HandThrottle.SETTINGS_FILE_OLD) then
        settingsFile = HandThrottle.SETTINGS_FILE_OLD
    end

    if fileExists(settingsFile) then
        local xmlFile = loadXMLFile("handThrottleSettings", settingsFile)
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

            config.idleCreep.enabled = readBool(xmlFile, "handThrottle.idleCreep#enabled", config.idleCreep.enabled)
            config.idleCreep.torque = readFloat(xmlFile, "handThrottle.idleCreep#torque", config.idleCreep.torque, 0.1, 1)
            config.idleCreep.clutchCurve = readFloat(xmlFile, "handThrottle.idleCreep#clutchCurve", config.idleCreep.clutchCurve, 0.3, 3)

            config.debug.enabled = readBool(xmlFile, "handThrottle.debug#enabled", config.debug.enabled)

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

    setXMLBool(xmlFile, "handThrottle.idleCreep#enabled", config.idleCreep.enabled)
    setXMLFloat(xmlFile, "handThrottle.idleCreep#torque", config.idleCreep.torque)
    setXMLFloat(xmlFile, "handThrottle.idleCreep#clutchCurve", config.idleCreep.clutchCurve)

    setXMLBool(xmlFile, "handThrottle.debug#enabled", config.debug.enabled)

    saveXMLFile(xmlFile)
    delete(xmlFile)
end


function HandThrottle.getConfig()
    HandThrottle.loadSettings()
    return HandThrottle.config
end


-- força do arrasto ao ralenti nas configurações deste jogador: 0 = desligado, 10-100 = %
function HandThrottle.getIdleCreepTorqueSetting()
    local idleCreep = HandThrottle.getConfig().idleCreep
    if not idleCreep.enabled then
        return 0
    end
    return math.clamp(math.floor(idleCreep.torque * 100 + 0.5), 10, 100)
end


-- curva da embraiagem do arrasto nas configurações deste jogador, em décimas (3-30 = 0.3-3.0)
function HandThrottle.getIdleCreepClutchCurveSetting()
    return math.clamp(math.floor(HandThrottle.getConfig().idleCreep.clutchCurve * 10 + 0.5), 3, 30)
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
    SpecializationUtil.registerEventListener(vehicleType, "onVehiclePhysicsUpdate", HandThrottle)
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

    -- arrasto ao ralenti (0 = desligado, 10-100 = força em %). Vem das configurações de quem conduz,
    -- que o envia no estado; até lá vale a configuração desta máquina.
    spec.idleCreepTorque = HandThrottle.getIdleCreepTorqueSetting()
    spec.idleCreepClutchCurve = HandThrottle.getIdleCreepClutchCurveSetting()

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

    -- ações do cruise control desativadas por nós: nome da ação -> id do evento
    spec.blockedActionEvents = {}

    -- último valor (0-1) que enviámos ao acelerador de mão do CVT Addon; nil = nenhum
    spec.cvtAddonValue = nil
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
        -- o onUpdate do condutor deixa de correr: pôr já o acelerador de mão do CVT Addon a 0
        HandThrottle.updateCvtAddon(self, 0)

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
        idleCreepTorque = spec.idleCreepTorque,
        idleCreepClutchCurve = spec.idleCreepClutchCurve,
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
    streamWriteUInt8(streamId, state.idleCreepTorque)
    streamWriteUInt8(streamId, state.idleCreepClutchCurve)
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
    state.idleCreepTorque = streamReadUInt8(streamId)
    state.idleCreepClutchCurve = streamReadUInt8(streamId)
    return state
end


-- state: tabela com mode, lastMode, percent, rpm, rpmLimit, speedForward, speedBackward, idleCreepTorque, idleCreepClutchCurve
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
    -- não vem em todos os estados (ex.: esquecer): fica o que estava
    if state.idleCreepTorque ~= nil then
        spec.idleCreepTorque = math.clamp(math.floor(state.idleCreepTorque + 0.5), 0, 100)
    end
    if state.idleCreepClutchCurve ~= nil then
        spec.idleCreepClutchCurve = math.clamp(math.floor(state.idleCreepClutchCurve + 0.5), 3, 30)
    end

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


-- CVT Addon (FS25_CVT_Addon): devolve a classe se este veículo tem o acelerador de mão dele.
-- Esse acelerador de mão só atua em CVT (isVarioTM); muda-se pela função do eixo dele,
-- que grava o valor e o sincroniza em multijogador.
function HandThrottle.getCvtAddon(vehicle)
    local cvtSpec = vehicle.spec_CVTaddon
    if cvtSpec == nil or cvtSpec.isVarioTM ~= true then
        return nil
    end

    local cvtMod = FS25_CVT_Addon
    local cvtAddon = cvtMod ~= nil and cvtMod.CVTaddon or nil
    if cvtAddon == nil or cvtAddon.VarioRpmAxis == nil then
        return nil
    end
    return cvtAddon
end


-- envia o valor (0-1) ao acelerador de mão do CVT Addon, só quando muda.
-- O 0 só é enviado se fomos nós a pô-lo acima de 0 (não apaga a alavanca de quem a usa).
function HandThrottle.updateCvtAddon(vehicle, value)
    local spec = vehicle.spec_handThrottle
    if value <= 0 and spec.cvtAddonValue == nil then
        return
    end
    if value == spec.cvtAddonValue then
        return
    end

    local cvtAddon = HandThrottle.getCvtAddon(vehicle)
    if cvtAddon == nil then
        spec.cvtAddonValue = nil
        return
    end

    cvtAddon.VarioRpmAxis(vehicle, "SETVARIORPM_AXIS", value)
    spec.cvtAddonValue = value > 0 and value or nil
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
    if mode == HandThrottle.MODE_PERCENT and not isManual then
        return HandThrottle.getCvtAddon(vehicle) ~= nil
    end
    return isManual
end


function HandThrottle.getIsModeAvailable(vehicle, mode)
    local modeConfig = HandThrottle.getModeConfig(mode)
    return modeConfig ~= nil and modeConfig.enabled and HandThrottle.getModeFitsGearbox(vehicle, mode)
end


-- ligado ou em pausa: o acelerador de mão manda nas teclas e o cruise control fica bloqueado
function HandThrottle.getIsSystemOn(spec)
    return spec.mode ~= HandThrottle.MODE_OFF or spec.lastMode ~= HandThrottle.MODE_OFF
end


local function getIsCruiseControlOn(vehicle)
    local drivableSpec = vehicle.spec_drivable
    return drivableSpec ~= nil and drivableSpec.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_OFF
end


local function getCanApplyHandThrottle(vehicle, mode)
    if not vehicle:getIsMotorStarted() then
        return false
    end

    -- o condutor desliga o cruise control logo (onUpdate); até lá não se atua
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
                if spec.mode == HandThrottle.MODE_PERCENT and not self:getHandThrottleIsManualTransmission() then
                    -- CVT com o CVT Addon: o % vai para o acelerador de mão dele (onUpdate do condutor)
                    spec.pedal = 0
                elseif spec.mode == HandThrottle.MODE_PERCENT or spec.mode == HandThrottle.MODE_RPM then
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

        if spec.idleCreepTorque > 0 then
            -- modo RPM, ou % acima de 0: o acelerador de mão manda (o % a 0 deixa o arrasto trabalhar)
            local handActive = (spec.mode == HandThrottle.MODE_RPM or (spec.mode == HandThrottle.MODE_PERCENT and spec.percent > 0))
                and getCanApplyHandThrottle(self, spec.mode)
            axisForward = HandThrottle.applyIdleCreep(self, spec, axisForward, doHandbrake, dt, handActive)
        else
            spec.idleCreepActiveNow = false
        end
        if spec.idleCreepTorque <= 0 and HandThrottle.getConfig().debug.enabled then
            HandThrottle.debugIdleCreep(self, spec, motor, false, "arrasto desligado nas configs", axisForward, axisForward, 0, 0, dt)
        end
    end

    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
end


-- o More Realistic já faz o arrasto ao ralenti (e substitui a física das rodas): não juntar os dois
function HandThrottle.getIsMoreRealisticLoaded()
    return g_modIsLoaded ~= nil and g_modIsLoaded["MoreRealistic"] == true
end


-- Arrasto ao ralenti (como num trator real e como o More Realistic):
-- caixa manual com embraiagem, mudança engatada, embraiagem solta ou a patinar e sem acelerador.
-- Regulador de ralenti (como o do More Realistic): compara as rotações do lado da embraiagem
-- (rodas x relação da caixa) com o ralenti. Parado ou a ser travado pela carga = pedal todo (até à
-- força configurada); a chegar à velocidade do ralenti alivia até um fio de pedal.
-- Não serve olhar para as rotações do motor: a física do jogo segura o motor no ralenti
-- (a embraiagem da física patina), por isso elas nunca descem e o trator ficava sem força.
-- Com a embraiagem a patinar o jogo sobe as rotações conforme o pedal: isso é limitado em
-- onVehiclePhysicsUpdate para o motor não disparar. Ir abaixo fica com a regra do jogo.
HandThrottle.IDLE_CREEP_BAND = 100           -- RPM abaixo do ralenti para chegar à força toda
HandThrottle.IDLE_CREEP_MIN_PEDAL = 0.02     -- fio de pedal no ralenti (com pedal 0 o jogo só o baixa devagar, em 2 s)
HandThrottle.IDLE_CREEP_RATE = 6             -- quanto o pedal pode mudar por segundo
HandThrottle.IDLE_CREEP_RPM_MARGIN = 50      -- folga do teto acima do ralenti

-- Ir abaixo (motor afogado): a física do jogo segura o motor no ralenti mesmo com as rodas quase
-- paradas, e o contador do jogo (embraiagem < 20 % do motor durante 0.5 s) volta a 0 com qualquer
-- tremor das rodas. Resultado: arrancava parado em 8.ª da gama alta. Regra do arrasto: com a
-- embraiagem (quase) solta, rotações da embraiagem abaixo de metade do ralenti durante 1 s = vai abaixo.
-- O contador não volta logo a 0: desce aos poucos, para os tremores não o apagarem.
HandThrottle.IDLE_CREEP_STALL_RATIO = 0.5       -- fração do ralenti abaixo da qual o motor está a ser afogado
HandThrottle.IDLE_CREEP_STALL_TIME = 1000       -- ms afogado até ir abaixo
HandThrottle.IDLE_CREEP_STALL_ENGAGEMENT = 0.8  -- só com a embraiagem quase solta (patinar com jeito não conta)
HandThrottle.IDLE_CREEP_STALL_RECOVER = 2       -- o contador desce 2x mais depressa do que sobe

-- handActive: o acelerador de mão (% ou RPM) está a dar pedal -> ele manda, sem arrasto
function HandThrottle.applyIdleCreep(vehicle, spec, axisForward, doHandbrake, dt, handActive)
    local active, reason = HandThrottle.getIdleCreepActive(vehicle, axisForward, doHandbrake)
    if active and handActive then
        active, reason = false, "acelerador de mão"
    end

    -- ADS: quem manda na embraiagem é ele. Avaria terminal = sem tração, o arrasto não faz nada.
    local adsClutch = HandThrottle.getAdsClutchState(vehicle)
    spec.debugAdsClutch = adsClutch
    if active and adsClutch ~= nil and adsClutch.value >= 1 then
        active, reason = false, "embraiagem avariada (ADS)"
    end

    local motor = vehicle:getMotor()
    local creepRpm, target = 0, 0
    local axisIn = axisForward

    if active then
        -- o mínimo que o jogo pede: ralenti, ou as rotações da tomada de força
        creepRpm = motor:getRequiredMotorRpmRange()

        local clutchRpm = HandThrottle.getCreepClutchRpm(motor)

        -- a força cresce com o curso da embraiagem: 0 nos 0.9 (onde o jogo já engata a mudança a meio),
        -- toda com a embraiagem solta. Sem isto agarrava toda logo no início do curso.
        local engagement = HandThrottle.getClutchEngagement(motor, (spec.idleCreepClutchCurve or 10) / 10)
        local maxPedal = spec.idleCreepTorque / 100 * engagement
        local err = creepRpm - clutchRpm
        target = math.clamp(0.1 + 0.9 * err / HandThrottle.IDLE_CREEP_BAND, HandThrottle.IDLE_CREEP_MIN_PEDAL, 1) * maxPedal

        local maxStep = HandThrottle.IDLE_CREEP_RATE * (dt or 16) * 0.001
        local pedal = spec.idleCreepPedal or 0
        pedal = pedal + math.clamp(target - pedal, -maxStep, maxStep)
        pedal = math.max(pedal, HandThrottle.IDLE_CREEP_MIN_PEDAL * maxPedal)

        -- o pé, como num trator com regulador: ganha o maior. Pé acima do arrasto = manda o pé
        -- (sem teto); o pedal do arrasto continua a partir do pé quando o largares (sem saltos).
        -- Sem zona morta: o ruído de um pedal parado fica abaixo do fio de pedal do arrasto.
        if axisIn > pedal then
            spec.idleCreepPedal = axisIn
            spec.idleCreepStallTimer = 0
            active, reason = false, "acelerador"
        elseif HandThrottle.updateIdleCreepStall(vehicle, spec, motor, creepRpm, clutchRpm, dt,
            adsClutch ~= nil and adsClutch.slip > HandThrottle.ADS_SLIP_THRESHOLD) then
            spec.idleCreepPedal = 0
            active, reason = false, "foi abaixo (afogado)"
        else
            spec.idleCreepPedal = pedal
            axisForward = pedal

            motor.handThrottleRpmLimit = math.min(motor.handThrottleRpmLimit or math.huge, creepRpm + HandThrottle.IDLE_CREEP_RPM_MARGIN)

            -- com a embraiagem a patinar, as rotações que o jogo mostra seguem o pedal: teto no ralenti + folga.
            -- Nunca abaixo de 0.05: o ADS só faz patinar uma embraiagem gasta com lastAcceleratorPedal >= 0.05.
            local minRpm, maxRpm = motor:getMinRpm(), motor:getMaxRpm()
            spec.idleCreepFakePedalMax = math.clamp((creepRpm + HandThrottle.IDLE_CREEP_RPM_MARGIN - minRpm) / math.max(maxRpm - minRpm, 1),
                HandThrottle.IDLE_CREEP_FAKE_PEDAL_MIN, 1)
        end
    else
        spec.idleCreepPedal = 0
        spec.idleCreepStallTimer = 0
    end
    spec.idleCreepActiveNow = active

    if HandThrottle.getConfig().debug.enabled then
        HandThrottle.debugIdleCreep(vehicle, spec, motor, active, reason, axisIn, axisForward, target, creepRpm, dt)
    end

    return axisForward
end


-- embraiagem: 0 carregada (0.9 ou mais = ponto morto no jogo) ... 1 solta.
-- curve (clutchCurve): 1 = a direito; abaixo de 1 morde mais cedo; acima de 1 mais suave no início
HandThrottle.CLUTCH_NEUTRAL = 0.9

function HandThrottle.getClutchEngagement(motor, curve)
    local engagement = math.clamp((HandThrottle.CLUTCH_NEUTRAL - (motor.manualClutchValue or 0)) / HandThrottle.CLUTCH_NEUTRAL, 0, 1)
    return engagement ^ (curve or 1)
end


-- rotações do lado da embraiagem (rodas x relação). Com sinal: a descair para trás = negativo = mais força.
-- Em marcha-atrás a relação e as rodas são negativas, o produto fica positivo.
function HandThrottle.getCreepClutchRpm(motor)
    if motor.getClutchRpm ~= nil then
        return motor:getClutchRpm()
    end
    return HandThrottle.getRealMotorRpm(motor)
end


-- rotações reais (a getLastMotorRpm nunca desce abaixo do ralenti)
function HandThrottle.getRealMotorRpm(motor)
    if motor.getNonClampedMotorRpm ~= nil then
        return motor:getNonClampedMotorRpm()
    end
    return motor:getLastMotorRpm()
end


-- motor afogado pelo arrasto: devolve true se foi abaixo (e desliga-o).
-- adsSlipping: a embraiagem está a patinar por avaria do ADS -> o motor não está preso às rodas, não conta.
function HandThrottle.updateIdleCreepStall(vehicle, spec, motor, creepRpm, clutchRpm, dt, adsSlipping)
    local timer = spec.idleCreepStallTimer or 0
    dt = dt or 16

    local engagement = HandThrottle.getClutchEngagement(motor, 1)
    local lugging = not adsSlipping
        and engagement >= HandThrottle.IDLE_CREEP_STALL_ENGAGEMENT
        and clutchRpm < creepRpm * HandThrottle.IDLE_CREEP_STALL_RATIO

    if lugging then
        timer = timer + dt
    else
        timer = math.max(timer - dt * HandThrottle.IDLE_CREEP_STALL_RECOVER, 0)
    end

    if timer >= HandThrottle.IDLE_CREEP_STALL_TIME and vehicle.stopMotor ~= nil then
        spec.idleCreepStallTimer = 0
        vehicle:stopMotor()
        return true
    end

    spec.idleCreepStallTimer = timer
    return false
end


--------------------------------------------------------------------------------
-- ADS (Advanced Damage System): só leitura. Sem o ADS carregado, devolve nil e nada muda.
-- Avaria DRY_CLUTCH_PACK_FAILURE -> efeito CLUTCH_SLIP_EFFECT:
--   value 0.2-1 (1 = avaria terminal, caixa praticamente desligada)
--   slipFactor = patinagem atual (o ADS aumenta a relação da caixa até x2)
-- O mod nunca escreve no ADS nem envia eventos dele.
--------------------------------------------------------------------------------
HandThrottle.ADS_MOD_NAME = "FS25_AdvancedDamageSystem"
HandThrottle.ADS_SLIP_THRESHOLD = 0.01
HandThrottle.IDLE_CREEP_FAKE_PEDAL_MIN = 0.05

function HandThrottle.getAdsModule()
    local env = _G[HandThrottle.ADS_MOD_NAME]
    if type(env) == "table" and type(env.ADS_VehiclePerformance) == "table" then
        return env.ADS_VehiclePerformance
    end
    -- se o ADS alguma vez ficar no ambiente global
    if type(_G.ADS_VehiclePerformance) == "table" then
        return _G.ADS_VehiclePerformance
    end
    return nil
end


-- devolve nil sem o ADS no veículo; senão { value = 0..1, slip = >=0 }
function HandThrottle.getAdsClutchState(vehicle)
    local specAds = vehicle.spec_AdvancedDamageSystem
    if specAds == nil then
        return nil
    end

    local state = { value = 0, slip = 0 }

    local ads = HandThrottle.getAdsModule()
    if ads ~= nil and type(ads.resolveEffect) == "function" then
        local ok, effect = pcall(ads.resolveEffect, vehicle, "CLUTCH_SLIP_EFFECT")
        if ok and type(effect) == "table" then
            state.value = math.clamp(tonumber(effect.value) or 0, 0, 1)
        end
    end

    local runtime = type(specAds.effectRuntime) == "table" and specAds.effectRuntime.CLUTCH_SLIP_EFFECT or nil
    if type(runtime) == "table" then
        state.slip = math.max(tonumber(runtime.slipFactor) or 0, 0)
    end

    return state
end


-- devolve se o arrasto atua e, se não, porquê (para o log)
function HandThrottle.getIdleCreepActive(vehicle, axisForward, doHandbrake)
    if not vehicle:getIsMotorStarted() then
        return false, "motor desligado"
    end
    if doHandbrake then
        return false, "travão de mão"
    end
    if axisForward < 0 then
        return false, "travão"
    end

    local motor = vehicle:getMotor()
    local manualClutchMode = VehicleMotor.SHIFT_MODE_MANUAL_CLUTCH
    if motor == nil or manualClutchMode == nil or motor.gearShiftMode ~= manualClutchMode then
        return false, "não é manual com embraiagem"
    end
    if motor.forwardGears == nil and motor.backwardGears == nil then
        return false, "sem mudanças"
    end

    -- ponto morto, embraiagem carregada ou a meter a mudança: não faz nada
    if motor.gear == 0 or (motor.minGearRatio == 0 and motor.maxGearRatio == 0) then
        return false, "ponto morto"
    end
    if (motor.manualClutchValue or 0) > HandThrottle.CLUTCH_NEUTRAL then
        return false, "embraiagem carregada"
    end
    if motor.gearChangeTimer ~= nil and motor.gearChangeTimer >= 0 then
        return false, "a mudar"
    end

    -- só com alguém a conduzir: sem IA, sem cruise control, e um trator deixado engatado não foge
    if vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() then
        return false, "IA"
    end
    if getIsCruiseControlOn(vehicle) then
        return false, "cruise control"
    end
    if vehicle.getIsControlled ~= nil and not vehicle:getIsControlled() then
        return false, "sem condutor"
    end

    if HandThrottle.getIsMoreRealisticLoaded() then
        return false, "More Realistic"
    end

    return true, "ATIVO"
end


--------------------------------------------------------------------------------
-- Log de diagnóstico (handThrottle.debug#enabled): uma linha a cada 100 ms,
-- e logo quando o estado muda ou o motor vai abaixo. Só com caixa manual com embraiagem.
--------------------------------------------------------------------------------
HandThrottle.DEBUG_INTERVAL = 100

-- comando de consola: ethtDebug [on|off] -> liga/desliga o log sem reiniciar o jogo
-- (sem argumento troca). Também grava no ficheiro de configurações.
function HandThrottle.consoleCommandDebug(arg)
    local config = HandThrottle.getConfig()
    local value
    arg = string.lower(tostring(arg or ""))

    if arg == "" then
        value = not config.debug.enabled
    elseif arg == "on" or arg == "true" or arg == "1" then
        value = true
    elseif arg == "off" or arg == "false" or arg == "0" then
        value = false
    else
        return "Usage: ethtDebug [on|off]"
    end

    config.debug.enabled = value
    HandThrottle.saveSettings()

    return string.format("[HandThrottle] Debug log %s (log.txt, lines '[HandThrottle DEBUG]')", value and "ON" or "OFF")
end

-- o jogo (e o More Realistic) envia aqui o pedal e o travão que vão para a física, logo depois de
-- os guardar no motor (VehicleMotor:updateGear) e antes de o motor os usar (VehicleMotor:update).
function HandThrottle:onVehiclePhysicsUpdate(acceleratorPedal, brakePedal, automaticBrake, currentSpeed)
    local spec = self.spec_handThrottle
    if spec == nil then
        return
    end

    -- arrasto com a embraiagem a patinar (> 0.1): o jogo sobe as rotações do motor conforme o pedal
    -- (lastAcceleratorPedal), como em ponto morto. Limitar só esse valor ao ralenti + folga; a força
    -- que vai para as rodas (o pedal da física) não muda. Na caixa manual com embraiagem o
    -- lastAcceleratorPedal só serve para isso e para a carga do motor.
    if self.isServer and spec.idleCreepActiveNow and spec.idleCreepFakePedalMax ~= nil then
        local motor = self:getMotor()
        if motor ~= nil and motor.lastAcceleratorPedal ~= nil and (motor.manualClutchValue or 0) > 0.1 then
            motor.lastAcceleratorPedal = math.min(motor.lastAcceleratorPedal, spec.idleCreepFakePedalMax)
        end
    end

    -- só para o log: comparar o que o mod pede com o que é aplicado
    if HandThrottle.config ~= nil and HandThrottle.config.debug.enabled then
        spec.debugPhysicsAcc = acceleratorPedal
        spec.debugPhysicsBrake = brakePedal
        spec.debugPhysicsAutoBrake = automaticBrake
    end
end

function HandThrottle.debugIdleCreep(vehicle, spec, motor, active, reason, axisIn, axisOut, target, creepRpm, dt)
    if motor == nil or motor.gearShiftMode ~= VehicleMotor.SHIFT_MODE_MANUAL_CLUTCH then
        return
    end

    local motorOn = vehicle:getIsMotorStarted()
    local event = nil
    if spec.debugLastReason ~= reason then
        event = "estado: " .. tostring(spec.debugLastReason) .. " -> " .. reason
    end
    if spec.debugMotorOn == true and not motorOn then
        event = "MOTOR FOI ABAIXO / DESLIGOU"
    end
    spec.debugLastReason = reason
    spec.debugMotorOn = motorOn

    spec.debugTimer = (spec.debugTimer or 0) + (dt or 16)
    if event == nil and spec.debugTimer < HandThrottle.DEBUG_INTERVAL then
        return
    end
    spec.debugTimer = 0

    local function num(value)
        return tonumber(value) or 0
    end

    local clutchRpm = motor.getClutchRpm ~= nil and num(motor:getClutchRpm()) or 0
    local minRange, maxRange = 0, 0
    if motor.getRequiredMotorRpmRange ~= nil then
        minRange, maxRange = motor:getRequiredMotorRpmRange()
    end
    local speed = vehicle.getLastSpeed ~= nil and num(vehicle:getLastSpeed()) or 0

    -- valores do More Realistic, se estiver carregado (rad/s -> RPM)
    local mrText = ""
    if motor.mrLastMotorObjectRotSpeed ~= nil then
        mrText = string.format(" | MR: rpmMotor=%.0f ralentiMR=%.0f relaçãoMR=%.1f",
            num(motor.mrLastMotorObjectRotSpeed) * 30 / math.pi, num(motor.mrMinRot) * 30 / math.pi,
            num(vehicle.spec_motorized ~= nil and vehicle.spec_motorized.mrLastMinGearRatioSet))
    end
    -- embraiagem do ADS, se estiver carregado (avaria 0-1 e patinagem atual)
    if spec.debugAdsClutch ~= nil then
        mrText = mrText .. string.format(" | ADS: embraiagem=%.2f patinagem=%.2f", num(spec.debugAdsClutch.value), num(spec.debugAdsClutch.slip))
    end

    print(string.format("[HandThrottle DEBUG] %s%s | mud=%s emb=%.2f | pedalEntra=%.2f pedalSai=%.2f alvo=%.2f suavizado=%.2f"
        .. " | física: pedal=%.2f travão=%.2f auto=%s pedalMotor=%.2f"
        .. " | rpmReal=%.0f rpmJogo=%.0f rpmEmb=%.0f ralenti=%.0f gama=%.0f-%.0f | %.1f km/h | relação=%.1f/%.1f atual=%.1f"
        .. " | binário=%.0f/%.0f | stall=%.0f afogado=%.0f patinar=%.0f%s",
        event ~= nil and ("*** " .. event .. " *** ") or "", reason,
        tostring(motor.gear), num(motor.manualClutchValue),
        num(axisIn), num(axisOut), num(target), num(vehicle.wheelsUtilSmoothedAcceleratorPedal),
        num(spec.debugPhysicsAcc), num(spec.debugPhysicsBrake), tostring(spec.debugPhysicsAutoBrake), num(motor.lastAcceleratorPedal),
        num(HandThrottle.getRealMotorRpm(motor)), num(motor:getLastMotorRpm()), clutchRpm, num(creepRpm), num(minRange), num(maxRange), speed,
        num(motor.minGearRatio), num(motor.maxGearRatio), num(motor.gearRatio),
        num(motor.motorAppliedTorque) * 1000, num(motor.motorAvailableTorque) * 1000,
        num(motor.stallTimer), num(spec.idleCreepStallTimer), num(motor.clutchSlippingTimer), mrText))
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
-- Vigia do condutor (cliente): bloqueio do cruise control, travar e pé a passar o alvo
--------------------------------------------------------------------------------
function HandThrottle:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_handThrottle
    if not self.isClient or not isActiveForInputIgnoreSelection then
        return
    end

    local drivableSpec = self.spec_drivable
    if drivableSpec == nil then
        return
    end

    -- arrasto ao ralenti: vale a configuração de quem conduz (o servidor recebe-a no estado)
    local idleCreepTorque = HandThrottle.getIdleCreepTorqueSetting()
    local idleCreepClutchCurve = HandThrottle.getIdleCreepClutchCurveSetting()
    if spec.idleCreepTorque ~= idleCreepTorque or spec.idleCreepClutchCurve ~= idleCreepClutchCurve then
        local state = HandThrottle.copyState(spec)
        state.idleCreepTorque = idleCreepTorque
        state.idleCreepClutchCurve = idleCreepClutchCurve
        self:setHandThrottleState(state)
    end

    local isSystemOn = HandThrottle.getIsSystemOn(spec)
    HandThrottle.updateCruiseControlActions(self, isSystemOn)

    -- rede de segurança: o Vehicle Inspector (ou outro mod) pode ligar o cruise control
    -- escrevendo o estado diretamente, sem passar pelas teclas
    if isSystemOn and getIsCruiseControlOn(self) then
        self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
    end

    -- CVT Addon: o modo % numa CVT manda no acelerador de mão dele; fora disso volta a 0.
    -- O +0.5 evita que o arredondamento para baixo dele (2 casas) tire 1 % por erro de vírgula.
    local cvtAddonValue = 0
    if spec.mode == HandThrottle.MODE_PERCENT and not self:getHandThrottleIsManualTransmission()
        and getCanApplyHandThrottle(self, spec.mode) and spec.percent > 0 then
        cvtAddonValue = (spec.percent + 0.5) / 100
    end
    HandThrottle.updateCvtAddon(self, cvtAddonValue)

    if spec.mode == HandThrottle.MODE_OFF then
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
        local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.ETHT_TOGGLE_MODE, self, HandThrottle.actionEventToggleMode, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.ETHT_TOGGLE_ON, self, HandThrottle.actionEventToggleOn, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

        -- subir/descer: uma só ação de eixo, para teclas, botões e eixos analógicos
        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.ETHT_VALUE, self, HandThrottle.actionEventValue, false, false, true, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)

        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.ETHT_MOVE_HUD, self, HandThrottle.actionEventMoveHud, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW or GS_PRIO_LOW)

        HandThrottle.updateActionEvents(self)
    end
end


function HandThrottle.updateActionEvents(vehicle)
    local spec = vehicle.spec_handThrottle
    if spec == nil or not vehicle.isClient then
        return
    end

    local toggleEvent = spec.actionEvents[InputAction.ETHT_TOGGLE_MODE]
    if toggleEvent ~= nil then
        g_inputBinding:setActionEventText(toggleEvent.actionEventId, string.format("%s: %s", getText("ht_label"), HandThrottle.getModeValueText(vehicle, spec)))
    end

    -- com o sistema desligado só a tecla de modo (e mover HUD) fica ativa:
    -- as teclas partilhadas com o cruise control são dele
    local activeStates = {
        [InputAction.ETHT_TOGGLE_ON] = HandThrottle.getIsSystemOn(spec),
        [InputAction.ETHT_VALUE] = spec.mode ~= HandThrottle.MODE_OFF,
    }
    for actionName, isActive in pairs(activeStates) do
        local actionEvent = spec.actionEvents[actionName]
        if actionEvent ~= nil then
            g_inputBinding:setActionEventActive(actionEvent.actionEventId, isActive)
        end
    end
end


-- desativa (ou volta a ativar) as ações de uma tabela de eventos de outra especialização.
-- Só se volta a ativar o que fomos nós a desativar, e só se chama o jogo quando o estado muda.
local function setForeignActionsActive(spec, actionEvents, actionNames, isActive)
    if actionEvents == nil then
        return
    end

    for _, actionName in ipairs(actionNames) do
        local actionEvent = actionEvents[actionName]
        local actionEventId = actionEvent ~= nil and actionEvent.actionEventId or nil
        local blockedId = spec.blockedActionEvents[actionName]

        if actionEventId == nil then
            spec.blockedActionEvents[actionName] = nil
        elseif not isActive and blockedId ~= actionEventId then
            g_inputBinding:setActionEventActive(actionEventId, false)
            spec.blockedActionEvents[actionName] = actionEventId
        elseif isActive and blockedId == actionEventId then
            g_inputBinding:setActionEventActive(actionEventId, true)
            spec.blockedActionEvents[actionName] = nil
        end
    end
end


-- teclas do cruise control do jogo e do Vehicle Inspector (se estiver instalado).
-- Corre em cada frame do condutor porque o jogo volta a registar as ações em várias situações
-- (o id muda e a ação nova vem ativa).
function HandThrottle.updateCruiseControlActions(vehicle, isBlocked)
    local spec = vehicle.spec_handThrottle

    if vehicle.spec_drivable ~= nil then
        setForeignActionsActive(spec, vehicle.spec_drivable.actionEvents, HandThrottle.CRUISE_CONTROL_ACTIONS, not isBlocked)
    end

    if vehicle.speedControl ~= nil then
        setForeignActionsActive(spec, vehicle.speedControl.actionEvents, HandThrottle.VEHICLE_INSPECTOR_ACTIONS, not isBlocked)
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

    -- o acelerador de mão e o cruise control nunca ficam ligados ao mesmo tempo
    if getIsCruiseControlOn(vehicle) then
        vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
    end

    vehicle:setHandThrottleState(state)
end


function HandThrottle:actionEventToggleMode(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_handThrottle

    local cycle = HandThrottle.AUTOMATIC_CYCLE
    if self:getHandThrottleIsManualTransmission() then
        cycle = HandThrottle.MANUAL_CYCLE
    elseif HandThrottle.getCvtAddon(self) ~= nil then
        cycle = HandThrottle.CVT_ADDON_CYCLE
    end
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

    -- em pausa continua o ciclo a partir do modo guardado (o último leva ao sistema desligado)
    local currentMode = spec.mode ~= HandThrottle.MODE_OFF and spec.mode or spec.lastMode
    local nextMode = available[1]
    if currentMode ~= HandThrottle.MODE_OFF then
        local index = nil
        for i, mode in ipairs(available) do
            if mode == currentMode then
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
        -- sistema desligado: a tecla é do cruise control (a ação já está inativa, isto é só proteção)
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


-- subir/descer: teclas e botões vão passo a passo, os eixos analógicos mudam de forma contínua
function HandThrottle:actionEventValue(actionName, inputValue, callbackState, isAnalog)
    if isAnalog then
        HandThrottle.updateValueAxis(self, inputValue)
    else
        HandThrottle.updateValueButton(self, inputValue)
    end
end


-- tecla ou botão: o primeiro toque muda logo; carregada, repete depois do tempo configurado
function HandThrottle.updateValueButton(vehicle, inputValue)
    local spec = vehicle.spec_handThrottle
    local direction = inputValue > 0 and 1 or (inputValue < 0 and -1 or 0)
    if spec.mode == HandThrottle.MODE_OFF or direction == 0 then
        return
    end

    -- uma falha de mais de 150 ms entre chamadas = tecla largada e carregada de novo
    local general = HandThrottle.getConfig().general
    local lastTime = spec.lastInputTime[direction]
    spec.lastInputTime[direction] = g_time

    if lastTime == nil or g_time - lastTime > 150 then
        spec.nextRepeatTime[direction] = g_time + general.keyRepeatDelay
    elseif g_time >= spec.nextRepeatTime[direction] then
        spec.nextRepeatTime[direction] = g_time + general.keyRepeatInterval
    else
        return
    end

    HandThrottle.changeValue(vehicle, direction)
end


-- eixo analógico: quanto mais empurrado, mais depressa muda; no centro mantém.
-- Junta as frações e só muda (e só envia evento) a cada passo inteiro.
function HandThrottle.updateValueAxis(vehicle, inputValue)
    local spec = vehicle.spec_handThrottle
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
        HandThrottle.changeValue(vehicle, 1)
    end
    while spec.axisAccumulator <= -1 do
        spec.axisAccumulator = spec.axisAccumulator + 1
        HandThrottle.changeValue(vehicle, -1)
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
