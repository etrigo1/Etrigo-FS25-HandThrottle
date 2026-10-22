--------------------------------------------------------------------------------
-- RegisterHandThrottle.lua
-- Regista a especialização HandThrottle e junta-a a todos os tipos de veículo
-- com Drivable + Motorized (exceto locomotivas), incluindo tipos de outros mods.
--------------------------------------------------------------------------------

local modDir = g_currentModDirectory
local modName = g_currentModName
local SPEC_NAME = "handThrottle"
local SPEC_FULL_NAME = modName .. "." .. SPEC_NAME

if g_specializationManager:getSpecializationByName(SPEC_NAME) == nil then
    g_specializationManager:addSpecialization(SPEC_NAME, "HandThrottle", Utils.getFilename("scripts/HandThrottle.lua", modDir), nil)
end

local function addToVehicleTypes(typeManager)
    if typeManager.typeName ~= "vehicle" then
        return
    end

    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        local specs = typeEntry.specializations
        if specs ~= nil
            and SpecializationUtil.hasSpecialization(Drivable, specs)
            and SpecializationUtil.hasSpecialization(Motorized, specs)
            and (Locomotive == nil or not SpecializationUtil.hasSpecialization(Locomotive, specs))
            and typeEntry.specializationsByName[SPEC_NAME] == nil
            and typeEntry.specializationsByName[SPEC_FULL_NAME] == nil then
            typeManager:addSpecialization(typeName, SPEC_NAME)
        end
    end
end

-- validateTypes corre depois de todos os tipos (base + mods) estarem carregados
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, addToVehicleTypes)
