--- PN Base: expose les réglages essentiels de cette ressource à pn-lib (panel web + /configpn en jeu).
--- Sans effet si pn-lib n'est pas installé. Les valeurs sont lues à l'usage : les changements sont appliqués en direct.
local FIELDS = {
    { source = 'config.server', key = 'timeOut', label = 'Délai avant réinitialisation (ms)', valueType = 'number', min = 0, max = 86400000 },
    { source = 'config.server', key = 'minimumPolice', label = 'Policiers minimum', valueType = 'number', min = 0, max = 50 },
    { source = 'config.server', key = 'notEnoughPoliceNotify', label = 'Notifier si pas assez de policiers', valueType = 'boolean' },
    { source = 'config.server', key = 'rewardMinAmount', path = 'reward.minAmount', label = 'Nombre min. d\'objets volés', description = 'Doit rester inférieur ou égal au maximum', valueType = 'number', min = 1, max = 20 },
    { source = 'config.server', key = 'rewardMaxAmount', path = 'reward.maxAmount', label = 'Nombre max. d\'objets volés', valueType = 'number', min = 1, max = 20 },
    { source = 'config.server', key = 'rewardItems', path = 'reward.items', label = 'Objets pouvant être volés', description = 'Liste JSON : name, min, max', valueType = 'json' },
    { source = 'config.shared', key = 'loseItemOnUse', path = 'doorlock.loseItemOnUse', label = 'Consommer l\'objet de piratage', valueType = 'boolean' },
}

local function resolve(root, path)
    local holder, last = root, path
    for part in path:gmatch('([^%.]+)%.') do
        holder = holder[part]
        if type(holder) ~= 'table' then return nil end
    end
    return holder, path:match('([^%.]+)$') or last
end

CreateThread(function()
    if GetResourceState('pn-lib') == 'missing' then return end
    local waited = 0
    while GetResourceState('pn-lib') ~= 'started' do
        Wait(500)
        waited = waited + 500
        if waited >= 120000 then return end
    end

    local ns = GetCurrentResourceName()
    local ok, err = pcall(function()
        local schema, targets = {}, {}
        for i = 1, #FIELDS do
            local f = FIELDS[i]
            local holder, last = resolve(require(f.source), f.path or f.key)
            if holder and holder[last] ~= nil then
                targets[f.key] = { holder = holder, last = last }
                schema[#schema + 1] = {
                    key = f.key, label = f.label, description = f.description,
                    valueType = f.valueType, min = f.min, max = f.max,
                    default = holder[last],
                }
            else
                print(('[%s] réglage pn-lib ignoré (introuvable): %s.%s'):format(ns, f.source, f.key))
            end
        end

        exports['pn-lib']:RegisterConfig(ns, schema)

        for i = 1, #schema do
            local key = schema[i].key
            local t = targets[key]
            local current = exports['pn-lib']:GetConfig(ns, key)
            if current ~= nil then t.holder[t.last] = current end
            exports['pn-lib']:OnConfigChange(ns, key, function(value)
                if value ~= nil then t.holder[t.last] = value end
            end)
        end
    end)
    if not ok then
        print(('[%s] configuration pn-lib indisponible: %s'):format(ns, tostring(err)))
    end
end)
