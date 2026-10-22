--------------------------------------------------------------------------------
-- RegisterHandThrottle.lua
-- Regista a especialização HandThrottle e junta-a a todos os tipos de veículo
-- com Drivable + Motorized (exceto locomotivas), incluindo tipos de outros mods.
--
-- Tem de ser feito dentro de TypeManager.validateTypes: o SpecializationManager
-- limpa a lista no loadMapData, que corre DEPOIS dos extraSourceFiles dos mods.
--------------------------------------------------------------------------------

local modDir = g_currentModDirectory
local modName = g_currentModName
local SPEC_NAME = modName .. ".handThrottle"
local didRegister = false

local function addToVehicleTypes(typeManager)
    if typeManager.typeName ~= "vehicle" or didRegister then
        return
    end
    didRegister = true

    if g_specializationManager:getSpecializationObjectByName(SPEC_NAME) == nil then
        g_specializationManager:addSpecialization(SPEC_NAME, "HandThrottle", Utils.getFilename("scripts/HandThrottle.lua", modDir), nil)
    end

    if HandThrottle == nil then
        Logging.error("[HandThrottle] Não foi possível carregar scripts/HandThrottle.lua")
        return
    end
    HandThrottle.MOD_NAME = modName

    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        local specs = typeEntry.specializations
        if specs ~= nil
            and SpecializationUtil.hasSpecialization(Drivable, specs)
            and SpecializationUtil.hasSpecialization(Motorized, specs)
            and (Locomotive == nil or not SpecializationUtil.hasSpecialization(Locomotive, specs))
            and typeEntry.specializationsByName[SPEC_NAME] == nil then
            typeManager:addSpecialization(typeName, SPEC_NAME)
        end
    end
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, addToVehicleTypes)
