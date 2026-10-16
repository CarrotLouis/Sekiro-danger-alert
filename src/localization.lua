-- MOM refreshes function-valued texts when its native menu opens.
-- Its shared plain-data language registry avoids another memory reader or poll.
local M={}
local codes={us='en',gb='en',bp='pt-BR',de='de',es='es',fr='fr',it='it',jp='ja',ko='ko',
    ms='es-419',pl='pl',pt='pt',ru='ru',cn='zh-Hans',tc='zh-Hant'}
local aliases={['en-GB']='en',['en-US']='en',br='pt-BR',mx='es-419',tw='zh-Hant',kr='ko',
    ['zh-CN']='zh-Hans',['zh-TW']='zh-Hant'}
function M.new(locales)
    local current='en'
    local function language()
        local registry=rawget(_G,'BingusTranslations')
        if type(registry)=='table' then
            local code=registry.game_code or registry.game_language or registry.steam_language
            local selected=codes[code] or aliases[code] or code
            if locales[selected] then current=selected end
        end
        return current
    end
    local self={language=language}
    function self:text(key)
        local pack=assert(locales[language()],'language unavailable')
        return assert(pack[key],'missing text: '..key)
    end
    function self:source(key)
        return function()return self:text(key)end
    end
    return self
end
return M
