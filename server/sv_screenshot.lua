lib.addCommand('takeshots', {
    help = 'Capture screenshots of furniture models and tints for catalog UI',
    params = {
        {
            name = 'model',
            type = 'string',
            help = 'Specific model name or tint key (e.g. model_tint_0) to screenshot (optional, defaults to all)',
            optional = true,
        },
    },
}, function(source, args, raw)
    debugPrint('info', 'Command /takeshots executed', {source = source, model = args.model})
    if not CheckPermission(source, 'admin') then
        Bridge.Server.Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    TriggerClientEvent('LNS_Housing:client:startScreenshots', source, args.model)
end)

RegisterNetEvent('LNS_Housing:server:setScreenshotBucket', function(bucket)
    local src = source
    if not CheckPermission(src, 'admin') then return end
    SetPlayerRoutingBucket(src, bucket or 999)
end)

RegisterNetEvent('LNS_Housing:server:resetScreenshotBucket', function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)
