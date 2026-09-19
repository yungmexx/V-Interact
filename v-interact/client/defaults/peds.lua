--[[
local function onSearchPed(data)
    local player = PlayerPedId()
    CreateThread(function()
        TaskTurnPedToFaceEntity(player, data.entity, 1000)
        Wait(1000)
      --  RequestAnimDict('anim@gangops@facility@servers@bodysearch@')
      --  while not HasAnimDictLoaded('anim@gangops@facility@servers@bodysearch@') do
      --      Wait(0)
      --  end
        TaskStartScenarioInPlace(player, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
       -- TaskPlayAnim(player, 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, -8.0, -1, 1, 49, false, false, false)

     --   Wait(GetAnimDuration('anim@gangops@facility@servers@bodysearch@', 'player_search') * 1000.0)

      --  ClearPedTasks(player)
    end)
end

exports['v-interact']:AddGlobalWorldPed({
    {
        name = 'v-interact:searchPed',
        label = 'Search',
        distance = 2.5,
        canInteract = function(entity, distanceToPlayer, coords, name)
            return not IsPedAPlayer(entity) and IsPedDeadOrDying(entity, true)
        end,
        onSelect = onSearchPed,
    },
})
--]]