lib.addCommand('takeshots', {
    help = 'Capture screenshots of furniture models for catalog UI',
    params = {
        {
            name = 'model',
            type = 'string',
            help = 'Specific model name to screenshot (optional, defaults to all)',
            optional = true,
        },
    },
}, function(source, args, raw)
    if not CheckPermission(source, 'admin') then
        Bridge.Server.Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    TriggerClientEvent('LNS_Housing:client:startScreenshots', source, args.model)
end)
