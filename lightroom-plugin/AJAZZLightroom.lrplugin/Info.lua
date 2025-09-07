-- Lightroom plugin manifest
return {
    LrSdkVersion = 12.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.ajazz.streamdock.lightroom',
    LrPluginName = 'AJAZZ StreamDock Controller',
    LrInitPlugin = 'modules/Start.lua',
    LrShutdownPlugin = 'modules/Stop.lua',

    LrLibraryMenuItems = {
        {
            title = 'Start StreamDock Server',
            file = 'modules/Start.lua',
        },
        {
            title = 'Stop StreamDock Server',
            file = 'modules/Stop.lua',
        },
    },

    LrPluginInfoProvider = 'support/PluginInfoProvider.lua',
}
