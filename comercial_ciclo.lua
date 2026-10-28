obs = obslua

local film_scene_name = "Filme"
local ad_scene_name = "Comercial"
local film_minutes = 2

local film_started_at = nil
local in_ad_phase = false
local ad_finished = false
local connected_sources = {}
local warned_scene = false

local function clean_name(value)
    if value == nil then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function get_source(name)
    if name == nil or name == "" then return nil end
    return obs.obs_get_source_by_name(name)
end

local function current_scene_name()
    local source = obs.obs_frontend_get_current_scene()
    if source == nil then return nil end
    local name = obs.obs_source_get_name(source)
    obs.obs_source_release(source)
    return name
end

local function switch_to_scene(name)
    local source = get_source(name)
    if source == nil then
        obs.script_log(obs.LOG_WARNING, "Comercial cíclico: cena não encontrada: " .. tostring(name))
        return false
    end
    obs.obs_frontend_set_current_scene(source)
    obs.obs_source_release(source)
    return true
end

local function on_media_ended(calldata)
    if not in_ad_phase or current_scene_name() ~= clean_name(ad_scene_name) then return end
    local ended_source = obs.calldata_source(calldata, "source")
    if ended_source == nil then
        ad_finished = true
        return
    end
    local ended_name = obs.obs_source_get_name(ended_source)
    for _, media_name in ipairs(connected_sources) do
        if ended_name == media_name then
            ad_finished = true
            obs.script_log(obs.LOG_INFO, "Comercial cíclico: o vídeo do comercial terminou.")
            return
        end
    end
end

local function disconnect_media_signals()
    for _, source in ipairs(connected_sources) do
        local ref = get_source(source)
        if ref ~= nil then
            local handler = obs.obs_source_get_signal_handler(ref)
            if handler ~= nil then
                obs.signal_handler_disconnect(handler, "media_ended", on_media_ended)
            end
            obs.obs_source_release(ref)
        end
    end
    connected_sources = {}
end

local function connect_media_signals()
    disconnect_media_signals()
    warned_scene = false
    local scene_source = get_source(clean_name(ad_scene_name))
    if scene_source == nil then return false end
    local scene = obs.obs_scene_from_source(scene_source)
    if scene == nil then
        obs.obs_source_release(scene_source)
        return false
    end
    local items = obs.obs_scene_enum_items(scene)
    if items ~= nil then
        for _, item in ipairs(items) do
            local media_source = obs.obs_sceneitem_get_source(item)
            if media_source ~= nil then
                local media_name = obs.obs_source_get_name(media_source)
                local handler = obs.obs_source_get_signal_handler(media_source)
                if handler ~= nil then
                    obs.signal_handler_connect(handler, "media_ended", on_media_ended)
                    table.insert(connected_sources, media_name)
                end
            end
        end
        obs.sceneitem_list_release(items)
    end
    obs.obs_source_release(scene_source)
    return #connected_sources > 0
end

local function restart_commercial_media()
    for _, media_name in ipairs(connected_sources) do
        local source = get_source(media_name)
        if source ~= nil then
            if obs.obs_source_media_restart ~= nil then
                obs.obs_source_media_restart(source)
            end
            obs.obs_source_release(source)
        end
    end
end

local function start_commercial()
    local ad_name = clean_name(ad_scene_name)
    if #connected_sources == 0 then
        if not warned_scene then
            obs.script_log(obs.LOG_WARNING, "Comercial cíclico: não encontrei fontes na cena do comercial. Coloque o vídeo como fonte dentro da cena e recarregue o script.")
            warned_scene = true
        end
        return false
    end
    if not switch_to_scene(ad_name) then return false end
    in_ad_phase = true
    ad_finished = false
    film_started_at = nil
    restart_commercial_media()
    obs.script_log(obs.LOG_INFO, "Comercial cíclico: comercial iniciado; aguardando o fim do vídeo.")
    return true
end

local function tick()
    local now = os.time()
    local current = current_scene_name()
    local film_name = clean_name(film_scene_name)
    local ad_name = clean_name(ad_scene_name)

    if current == ad_name then
        if not in_ad_phase then
            in_ad_phase = true
            ad_finished = false
            film_started_at = nil
        end
        if ad_finished then
            if switch_to_scene(film_name) then
                in_ad_phase = false
                ad_finished = false
                film_started_at = os.time()
                obs.script_log(obs.LOG_INFO, "Comercial cíclico: voltando ao filme.")
            end
        end
        return
    end

    if in_ad_phase then
        in_ad_phase = false
        ad_finished = false
        film_started_at = nil
    end

    if current ~= film_name then
        film_started_at = nil
        return
    end

    if film_started_at == nil then
        film_started_at = now
        return
    end

    local minutes = math.max(1, tonumber(film_minutes) or 2)
    if now - film_started_at >= minutes * 60 then
        start_commercial()
    end
end

function script_description()
    return "Alterna entre filme e comercial: após X minutos no filme, mostra o vídeo até terminar e volta ao filme. Detecta automaticamente as fontes da cena do comercial."
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "film_scene", "Filme")
    obs.obs_data_set_default_string(settings, "ad_scene", "Comercial")
    obs.obs_data_set_default_int(settings, "film_minutes", 2)
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "film_scene", "Nome exato da cena do filme", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "ad_scene", "Nome exato da cena do comercial", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "film_minutes", "Minutos do filme antes do comercial", 1, 1440, 1)
    return props
end

function script_update(settings)
    film_scene_name = obs.obs_data_get_string(settings, "film_scene")
    ad_scene_name = obs.obs_data_get_string(settings, "ad_scene")
    film_minutes = obs.obs_data_get_int(settings, "film_minutes")
    connect_media_signals()
    film_started_at = nil
    in_ad_phase = false
    ad_finished = false
end

function script_load(settings)
    script_update(settings)
    obs.timer_add(tick, 500)
end

function script_unload()
    obs.timer_remove(tick)
    disconnect_media_signals()
end
