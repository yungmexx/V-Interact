local function openATM(data)
    TriggerEvent('qb-banking:client:useCard')
end

exports['v-interact']:AddGlobalObject({
    {
        name = 'ATM_1',
        label = 'Use ATM',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_atm_01` end,
        onSelect = openATM,
    },
    {
        name = 'ATM_2',
        label = 'Use ATM',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_atm_02` end,
        onSelect = openATM,
    },
    {
        name = 'ATM_3',
        label = 'Use ATM',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_atm_03` end,
        onSelect = openATM,
    },
    {
        name = 'ATM_4',
        label = 'Use ATM',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_fleeca_atm` end,
        onSelect = openATM,
    },
})