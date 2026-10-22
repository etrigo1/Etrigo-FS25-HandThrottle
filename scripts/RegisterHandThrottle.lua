--------------------------------------------------------------------------------
-- RegisterHandThrottle.lua
-- Regista a especialização HandThrottle e junta-a a todos os tipos de veículo
-- com Drivable + Motorized (exceto locomotivas), incluindo tipos de outros mods.
--
-- Atenção: dentro de um mod, addSpecialization("handThrottle") fica registado
-- como "<modName>.handThrottle" (o jogo junta o nome do mod). É esse nome
-- completo que se usa para juntar a spec aos tipos (mesmo padrão do FillLevelLimiter).
--------------------------------------------------------------------------------

local modDir = g_currentModDirectory
local modName = g_currentModName
local SPEC_FULL_NAME = modName .. ".handThrottle"

g_specializationManager:addSpecialization("handThrottle", "HandThrottle", Utils.getFilename("scripts/HandThrottle.lua", modDir), nil)

local function addToVehicleTypes(typeManager)
    if typeManager.typeName ~= "vehicle" then
        return
    end

    local specObject = g_specializationManager:getSpecializationObjectByName(SPEC_FULL_NAME)
    if specObject == nil then
        Logging.error("[HandThrottle] Especialização '%s' não encontrada, o mod não vai funcionar", SPEC_FULL_NAME)
        return
    end

    local numInserted = 0
    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        local specs = typeEntry.specializations
        if specs ~= nil
            and typeEntry.specializationsByName[SPEC_FULL_NAME] == nil
            and specObject.prerequisitesPresent(specs)
            and (Locomotive == nil or not SpecializationUtil.hasSpecialization(Locomotive, specs)) then
            typeManager:addSpecialization(typeName, SPEC_FULL_NAME)
            numInserted = numInserted + 1
        end
    end

    Logging.info("[HandThrottle] Especialização adicionada a %d tipos de veículo", numInserted)
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, addToVehicleTypes)
