local m = {}

local VERSION = "0.1.5"
local DEBUG_TRACE = false
local RESOLVED_TEXT_RVA = 0x1496a3c
local SLIDER_INIT_RVA = 0xe59f80
local SLIDER_SET_RVA = 0xe5a190
local UI_TEXT_SET_RVA = 0xe48bf0
local LIST_ITEM_RENDER_RVA = 0xc97408
local TEAM_ITEM_TEXT_A_RVA = 0xc97c32
local TEAM_ITEM_TEXT_B_RVA = 0xc97ca8
local GAME_TEXT_LANGUAGE_SET_RVA = 0xb22a50
local COMMENTARY_LANGUAGE_SET_RVA = 0xb229f0
local GAME_TEXT_LANGUAGE_NAV_RVA = 0xb22871
local a11y = {
    previous_option_key = 0x36, -- 6
    next_option_key = 0x37, -- 7
    restore_key = 0x38, -- 8
    previous_value_key = 0x39, -- 9
    next_value_key = 0x30, -- 0
    read_tooltips = true,
    diagnostic_mode = false,
    selected_option = 1,
    option_count = 2,
    diagnostic_sequence = 0,
    diagnostic_candidate_key = nil,
    diagnostic_candidate_since = 0,
    diagnostic_last_key = nil,
    diagnostic_slider_values = {},
    diagnostic_class_ids = {},
    diagnostic_class_count = 0,
    diagnostic_last_snapshot_frame = -10000,
    diagnostic_input_sequence = 0,
    diagnostic_last_input_action = nil,
    diagnostic_last_input_source = nil,
    diagnostic_last_input_frame = -10000,
    diagnostic_keyboard_state = {},
    diagnostic_gamepad_state = {},
    diagnostic_left_stick_direction = nil,
    diagnostic_selected_heading = nil,
    diagnostic_selected_heading_frame = -10000,
    diagnostic_selected_heading_widget = nil,
    diagnostic_selection_sequence = 0,
    diagnostic_player_visits = {},
    ui_string_object_by_widget = {},
    prism_library = nil,
    prism_context = nil,
    prism_backend = nil,
    prism_backend_name = nil,
    prism_functions = nil,
    prism_screen_readers = {},
    prism_sapi_id = nil,
    prism_uia_id = nil,
    prism_next_reader_probe_ms = 0,
    prism_failed = false,
    native_speech_queue = {},
    native_speech_first = 1,
    native_speech_last = 0,
    sider_dir = nil,
    ui_text_caller_by_widget = {},
    dialog_button_queued_for_message = false,
    ui_language = "en",
    ui_language_locked = false,
    sider_overlay_text_by_module = {},
    pre_match_active = false,
    game_plan_active = false,
    game_plan_main_surface = false,
    game_plan_context = nil,
    game_plan_announced_context = nil,
    game_plan_last_focus_text = nil,
    game_plan_last_menu_focus = nil,
    game_plan_attribute_due_ms = nil,
    game_plan_attribute_hold_until_ms = 0,
    game_plan_attribute_last_marker_frame = -10000,
    game_plan_attribute_panel_until_ms = 0,
    game_plan_attribute_index = 1,
    game_plan_attribute_items = {},
    game_plan_attribute_text_events = {},
    game_plan_player_record = nil,
    game_plan_player_name = nil,
    game_plan_player_attributes = {},
    game_plan_player_cache = {},
    game_plan_attribute_locked_name = nil,
    game_plan_attribute_opened_ms = 0,
    game_plan_last_focus_widget = nil,
    game_plan_last_focus_frame = -10000,
    game_plan_selected_heading = nil,
    game_plan_selected_heading_widget = nil,
    game_plan_selected_heading_frame = -10000,
    game_plan_selected_heading_due_frame = nil,
    game_plan_last_announced_heading = nil,
    game_plan_last_player_section = nil,
    game_plan_basic_prompt_active = false,
    game_plan_active_tactical_label = nil,
    game_plan_active_tactical_value = nil,
    game_plan_active_tactical_widget = nil,
    game_plan_active_tactical_frame = -10000,
    game_plan_formation_active = false,
    game_plan_tactical_navigation_frame = -10000,
    navigation_frame = -10000,
    navigation_action = nil,
    game_plan_pending_title = nil,
    game_plan_title_widgets = {},
    game_plan_basic_menu_heading_widget = nil,
    game_plan_basic_menu_heading_text = nil,
    game_plan_basic_menu_heading_due_frame = nil,
    game_plan_lineup_due_ms = nil,
    game_plan_lineup_input = nil,
    game_plan_lineup_generation_frame = -10000,
    game_plan_observed_lineup = {},
    lineup_keyboard_o_down = false,
    lineup_right_stick_x = 0,
    pre_match_entry_pending = false,
    pre_match_entry_guard_until_frame = 0,
    pre_match_last_action = nil,
    stadium_active = false,
    stadium_started_frame = -10000,
    stadium_last_marker_frame = -10000,
    stadium_value_index_by_widget = {},
    stadium_rows = {},
    confirmation_dialog_until_frame = 0,
    pre_match_notice_text = nil,
    pre_match_actions = {
        ["Início"] = true,
        ["Plano de jogo"] = true,
        ["Configurações gerais"] = true,
        ["Configurações de câmera"] = true,
        ["Configurações do sistema"] = true,
        ["Estádio"] = true,
        ["Uniforme"] = true,
        ["Kick Off"] = true,
        ["Game Plan"] = true,
        ["General Settings"] = true,
        ["Camera Settings"] = true,
        ["System Settings"] = true,
        ["Stadium"] = true,
        ["Uniform"] = true,
    },
}
local ORIGINAL_PROLOGUE =
    "\x48\x8b\xd0" ..
    "\x48\x8b\xcb" ..
    "\x48\x8b\x5c\x24\x30" ..
    "\x48\x83\xc4\x20"
local SLIDER_INIT_PROLOGUE =
    "\x48\x89\x5c\x24\x18" ..
    "\x48\x89\x74\x24\x20" ..
    "\x41\x56" ..
    "\x48\x83\xec\x20"
local SLIDER_SET_PROLOGUE =
    "\x48\x89\x5c\x24\x10" ..
    "\x48\x89\x6c\x24\x18" ..
    "\x57" ..
    "\x48\x83\xec\x20"
local LANGUAGE_SET_PROLOGUE =
    "\x48\x89\x5c\x24\x08" ..
    "\x57" ..
    "\x48\x83\xec\x30" ..
    "\x8b\xda" ..
    "\x48\x8b\xf9"
local LANGUAGE_NAV_PROLOGUE =
    "\x48\x8b\x93\xa8\x00\x00\x00" ..
    "\x48\x8b\xcb" ..
    "\x8b\xf0" ..
    "\x8b\x3c\xb2"
local UI_TEXT_SET_PROLOGUE =
    "\x48\x8b\xc4" ..
    "\x55" ..
    "\x56" ..
    "\x57" ..
    "\x41\x56" ..
    "\x41\x57" ..
    "\x48\x8d\x68\xa1" ..
    "\x48\x81\xec\x00\x01\x00\x00"
local LIST_ITEM_RENDER_PROLOGUE =
    "\x45\x8b\x07" ..
    "\x4d\x8d\x4f\x40" ..
    "\x48\x8b\x4c\x24\x78" ..
    "\x48\x8b\xd0"
local TEAM_ITEM_TEXT_PROLOGUE =
    "\x90" ..
    "\x45\x33\xc9" ..
    "\x45\x33\xc0" ..
    "\x48\x8d\x55\xe7" ..
    "\x48\x8b\xcf"

local process_base
local process_base_u64
local readable
local read_u64
local seen = {}
local unique_count = 0
local widgets = {}
local widget_count = 0
local slider_rows = {}
local slider_values = {}
local unmapped_sliders = {}
local ui_text_by_widget = {}
local ui_text_seen = {}
local ui_text_unique_count = 0
local ui_focus_widgets = {}
local ui_focus_widget_count = 0
local ui_focus_state = {}
local ui_focus_activated = {}
local last_ui_text_ms = 0
local ui_focus_candidate_key
local ui_focus_candidate_since = 0
local last_ui_focus_announcement
local ui_focus_preferred_offset_index
local last_selected_ui_entry
local dialog_options = {}
local dialog_signature
local dialog_preferred_offset
local dialog_focus_candidate
local dialog_focus_candidate_since = 0
local last_dialog_announcement
local recent_message_text
local recent_message_widget_key
local recent_message_frame = -10000
local pending_message_text
local pending_message_key
local pending_message_due_ms
local last_announced_message_key
local modal_focus_hold_until_ms = 0
local last_modal_button_frame = -10000
local modal_message_spoken_frame = -10000
local instruction_message_locked = false
local recent_heading_text
local recent_heading_frame = -10000
local standard_text_by_widget = {}
local dynamic_text_candidate
local dynamic_text_due_ms
local main_menu_title_widget_key
local current_main_menu_title
local main_menu_tooltip
local main_menu_tooltip_due_ms
local main_menu_focus_guard_until = 0
local last_screen_title_key
local last_native_list_text
local last_native_list_frame = -10000
local football_life_tooltip_title
local football_life_tooltip_description
local controller_rows = {}
local control_rows_by_label_widget = {}
local control_row_by_value_widget = {}
local pending_control_row
local active_control_row
local active_control_focused_ms = 0
local pending_controller_label
local active_controller_label
local last_controller_announcement
local last_announced_control_row
local last_announced_selector_label
local pending_controller_tooltip
local pending_controller_tooltip_label
local controller_tooltip_due_ms
local last_spoken_controller_tooltip_key
local focused_control_hint
local focused_control_hint_ms = 0
local latest_generic_tooltip
local latest_generic_tooltip_widget
local latest_generic_tooltip_ms = 0
local last_audio_id
local speech_sequence = 0
local last_spoken_text
local last_spoken_ms = 0
local last_focused_id
local focus_candidate_id
local focus_candidate_since = 0
local last_announced_focus_key
local last_widget_frame = -10000
local prism_started = false
local frame = 0
local startup_complete = false
local startup_completed_frame = -10000
local side_position
local side_screen_active = false
local side_widget_positions = {}
local side_widget_count = 0
local game_was_foreground = true
local foreground_resume_frame = 0
local overlay_visible = false
local sider_overlay_visible = false
local startup_speech = {
    queue = {},
    first = 1,
    last = 0,
    next_ms = 0,
    seen = {},
    version = nil,
    version_due_ms = nil,
    version_queued = false,
}
local audio_ids = {
    [393228] = true,
    [393230] = true,
    [393260] = true,
    [393261] = true,
    [393262] = true,
    [393263] = true,
    [393264] = true,
}
a11y.fast_focus_items = {
    ["Configurações de áudio"] = true,
    ["Música"] = true,
    ["Comentário"] = true,
    ["Configurações de volume"] = true,
    ["Audio Settings"] = true,
    ["Music"] = true,
    ["Commentary"] = true,
    ["Volume Settings"] = true,
}
local controller_labels = {
    ["Nome dos ajustes"] = true,
    ["Configuração de comandos"] = true,
    ["Alterar cursor"] = true,
    ["Indicador de próximo jogador"] = true,
    ["Tipo de cursor"] = true,
    ["Nível de auxílio de passe"] = true,
    ["Tipo de lançamento"] = true,
    ["Tipo de chute"] = true,
    ["Guia de direção"] = true,
    ["Guia de precisão"] = true,
    ["Guia de posicionamento"] = true,
    ["Drible automático"] = true,
    ["Carrinho Autom."] = true,
    ["Controles de Companheiros"] = true,
    ["Nível da partida"] = true,
    ["Duração da partida"] = true,
    ["Prorrogação"] = true,
    ["PN"] = true,
    ["Nº de substituições"] = true,
    ["Condição: Em casa"] = true,
    ["Condição: Fora"] = true,
    ["Lesões"] = true,
    ["Tipo de bola"] = true,
    ["Estádio"] = true,
    ["Período"] = true,
    ["Estação do ano/Clima"] = true,
    ["Condições do campo"] = true,
    ["Altura da grama"] = true,
    ["Stadium"] = true,
    ["Time"] = true,
    ["Season/Weather"] = true,
    ["Pitch Conditions"] = true,
    ["Grass Length"] = true,
}
a11y.game_plan_roster_contexts = {
    ["Menu de configuração básica"] = true,
    ["Configurações táticas básicas"] = true,
    ["Plano de jogo normal"] = true,
    ["Escalação/Editar posição"] = true,
    ["Basic Tactical Settings"] = true,
    ["Basic Settings Menu"] = true,
    ["Normal Game Plan"] = true,
    ["Team Sheet/Edit Position"] = true,
}
a11y.game_plan_edit_contexts = {
    ["Escalação/Editar posição"] = true,
    ["Team Sheet/Edit Position"] = true,
}
a11y.game_plan_menu_items = {
    ["Configurações táticas básicas"] = true,
    ["Escalação/Editar posição"] = true,
    ["Táticas predefinidas"] = true,
    ["Alterar formação"] = true,
    ["Instruções ofensivas"] = true,
    ["Instruções defensivas"] = true,
    ["Instruções avançadas"] = true,
    ["Configurações do jogador"] = true,
    ["Seleção automática da escalação"] = true,
    ["Configurações de ajuda"] = true,
    ["Acessar configuração básica"] = true,
    ["Salvar/Carregar"] = true,
    ["Gestão de dados"] = true,
    ["Ajuda"] = true,
    ["Preset Tactics"] = true,
    ["Change Formation"] = true,
    ["Offensive Instructions"] = true,
    ["Defensive Instructions"] = true,
    ["Advanced Instructions"] = true,
    ["Player Settings"] = true,
    ["Automatic Lineup Selection"] = true,
    ["Support Settings"] = true,
    ["Use Basic Settings"] = true,
    ["Save/Load"] = true,
    ["Data Management"] = true,
    ["Help"] = true,
    ["Basic Tactical Settings"] = true,
    ["Team Sheet/Edit Position"] = true,
}
a11y.game_plan_basic_prompt_items = {
    ["Usar"] = true,
    ["Não usar"] = true,
    ["Use"] = true,
    ["Do not use"] = true,
}
a11y.game_plan_tactical_labels = {
    ["Estilo ofensivo"] = true,
    ["Construção"] = true,
    ["Construção de jogo"] = true,
    ["Área de ataque"] = true,
    ["Posicionamento"] = true,
    ["Alcance do suporte"] = true,
    ["Estilo defensivo"] = true,
    ["Área de contenção"] = true,
    ["Pressão"] = true,
    ["Linha defensiva"] = true,
    ["Compactação"] = true,
    ["Attacking Style"] = true,
    ["Build Up"] = true,
    ["Attacking Area"] = true,
    ["Positioning"] = true,
    ["Support Range"] = true,
    ["Defensive Style"] = true,
    ["Containment Area"] = true,
    ["Pressuring"] = true,
    ["Defensive Line"] = true,
    ["Compactness"] = true,
}
a11y.game_plan_basic_configuration_items = {
    ["Estilo ofensivo"] = true,
    ["Passe longo"] = true,
    ["Área de ataque"] = true,
    ["Posicionamento"] = true,
    ["Estilo defensivo"] = true,
    ["Pressão na frente"] = true,
    ["Área de contenção"] = true,
    ["Pressão"] = true,
    ["Manter formação"] = true,
    ["Contra-ataque"] = true,
    ["Provocador"] = true,
    ["Attacking Style"] = true,
    ["Build Up"] = true,
    ["Attacking Area"] = true,
    ["Positioning"] = true,
    ["Defensive Style"] = true,
    ["Pressuring"] = true,
    ["Containment Area"] = true,
    ["Defensive Line"] = true,
    ["Maintain Formation"] = true,
    ["Counter Target"] = true,
    ["Gegenpress"] = true,
}
a11y.game_plan_screen_titles = {
    ["Menu de configuração básica"] = true,
    ["Configurações táticas básicas"] = true,
    ["Plano de jogo normal"] = true,
    ["Escalação/Editar posição"] = true,
    ["Trocar ícone de jog."] = true,
    ["Táticas predefinidas"] = true,
    ["Alterar formação"] = true,
    ["Instruções ofensivas"] = true,
    ["Instruções defensivas"] = true,
    ["Instruções avançadas"] = true,
    ["Configurações do jogador"] = true,
    ["Gestão de dados"] = true,
    ["Basic Settings Menu"] = true,
    ["Basic Tactical Settings"] = true,
    ["Normal Game Plan"] = true,
    ["Team Sheet/Edit Position"] = true,
    ["Change Player Icon"] = true,
    ["Preset Tactics"] = true,
    ["Change Formation"] = true,
    ["Offensive Instructions"] = true,
    ["Defensive Instructions"] = true,
    ["Advanced Instructions"] = true,
    ["Player Settings"] = true,
    ["Data Management"] = true,
}
a11y.game_plan_attribute_names = {
    pt = {
        {"FOR", "Força"},
        {"DRI", "Drible"},
        {"PAS", "Passe"},
        {"VEL", "Velocidade"},
        {"DEF", "Defesa"},
        {"CHU", "Chute"},
        {"Altura (cm)", "Altura"},
        {"Peso (kg)", "Peso"},
        {"Idade", "Idade"},
        {"Melhor pé", "Melhor pé"},
        {"Função no time", "Função no time"},
    },
    en = {
        {"STR", "Strength"},
        {"DRI", "Dribbling"},
        {"PAS", "Passing"},
        {"SPD", "Speed"},
        {"DEF", "Defending"},
        {"SHO", "Shooting"},
        {"Height (cm)", "Height"},
        {"Weight (kg)", "Weight"},
        {"Age", "Age"},
        {"Preferred foot", "Preferred foot"},
        {"Team Role", "Team role"},
    },
}

-- PES 2021/Football Life stores these values as packed, little-endian
-- bitfields at the beginning of the player record. The offsets match both
-- player-copy paths used by FL_2026.exe; every captured record is validated
-- before it is used for speech.
a11y.player_attribute_specs = {
    {"Consciência ofensiva", "Offensive awareness", 0x03, 0},
    {"Controle de bola", "Ball control", 0x06, 5},
    {"Drible", "Dribbling", 0x05, 6},
    {"Condução precisa", "Tight possession", 0x08, 0},
    {"Passe rasteiro", "Low pass", 0x09, 6},
    {"Passe alto", "Lofted pass", 0x0a, 5},
    {"Finalização", "Finishing", 0x08, 7},
    {"Cabeceio", "Heading", 0x0c, 0},
    {"Bola parada", "Place kicking", 0x0e, 5},
    {"Curva", "Curl", 0x10, 0},
    {"Velocidade", "Speed", 0x14, 7},
    {"Aceleração", "Acceleration", 0x18, 7},
    {"Força do chute", "Kicking power", 0x18, 0},
    {"Impulsão", "Jump", 0x19, 6},
    {"Contato físico", "Physical contact", 0x15, 6},
    {"Equilíbrio", "Balance", 0x16, 5},
    {"Resistência", "Stamina", 0x1a, 5},
    {"Consciência defensiva", "Defensive awareness", 0x04, 0},
    {"Desarme", "Ball winning", 0x0c, 7},
    {"Agressividade", "Aggression", 0x0d, 6},
    {"Consciência do goleiro", "Goalkeeper awareness", 0x04, 7},
    {"Firmeza do goleiro", "Goalkeeper catching", 0x10, 7},
    {"Rebatida do goleiro", "Goalkeeper clearing", 0x11, 6},
    {"Reflexos do goleiro", "Goalkeeper reflexes", 0x12, 5},
    {"Alcance do goleiro", "Goalkeeper reach", 0x14, 0},
}
a11y.player_position_names = {
    pt = {
        [0] = "Goleiro", "Zagueiro central", "Lateral esquerdo",
        "Lateral direito", "Volante", "Meio-campista central",
        "Meia esquerdo", "Meia direito", "Meia ofensivo",
        "Ponta esquerda", "Ponta direita", "Segundo atacante", "Centroavante",
    },
    en = {
        [0] = "Goalkeeper", "Centre back", "Left back", "Right back",
        "Defensive midfielder", "Central midfielder", "Left midfielder",
        "Right midfielder", "Attacking midfielder", "Left winger",
        "Right winger", "Second striker", "Centre forward",
    },
}

function a11y.normalized_player_name(text)
    if not text then return nil end
    local normalized = text:gsub("^%s*%d+%s+", "")
        :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return normalized ~= "" and normalized or nil
end

function a11y.player_for_text(text)
    local normalized = a11y.normalized_player_name(text)
    if not normalized then return nil end
    if a11y.game_plan_player_cache[normalized] then
        return a11y.game_plan_player_cache[normalized]
    end
    for stored_name, player in pairs(a11y.game_plan_player_cache) do
        -- The live PES record has a 15-byte name field, while the UI can show
        -- the complete localized name. Match that validated record prefix.
        if normalized:sub(1, #stored_name) == stored_name then
            return player
        end
    end
    return nil
end

function a11y.record_game_plan_input(action, source)
    if overlay_visible or sider_overlay_visible then return end
    a11y.diagnostic_last_input_action = action
    a11y.diagnostic_last_input_source = source
    a11y.diagnostic_last_input_frame = frame
    if action == "up" or action == "down"
            or action == "left" or action == "right" then
        a11y.navigation_frame = frame
        a11y.navigation_action = action
    end
    if not a11y.game_plan_active then return end
    if action == "A" and a11y.game_plan_last_menu_focus then
        -- Several Game Plan sub-screens do not reuse the Basic Settings title
        -- widget. The command confirmed by the user is therefore the most
        -- reliable context transition signal.
        a11y.game_plan_context = a11y.game_plan_last_menu_focus
        a11y.game_plan_main_surface = false
        a11y.game_plan_formation_active = false
        a11y.game_plan_announced_context = nil
        a11y.game_plan_last_focus_text = nil
        reset_focus_reuse_state()
    elseif (action == "B" or action == "escape")
            and (a11y.game_plan_context == "Alterar formação"
                or a11y.game_plan_context == "Change Formation") then
        a11y.game_plan_context = a11y.ui_language == "pt"
            and "Menu de configuração básica" or "Basic Settings Menu"
        a11y.game_plan_formation_active = false
        a11y.game_plan_announced_context = nil
        a11y.game_plan_last_focus_text = nil
        a11y.game_plan_last_menu_focus = nil
        reset_focus_reuse_state()
    end
    if a11y.game_plan_context == "Configurações táticas básicas"
            or a11y.game_plan_context == "Basic Tactical Settings" then
        if action == "down" or action == "up" then
            a11y.game_plan_tactical_navigation_frame = frame
            a11y.clear_pending_tooltips()
            last_controller_announcement = nil
            last_announced_control_row = nil
            last_announced_selector_label = nil
        elseif action == "left" or action == "right" then
            a11y.game_plan_tactical_navigation_frame = frame
            a11y.clear_pending_tooltips()
        elseif action == "escape" or action == "B" then
            a11y.game_plan_context = a11y.ui_language == "pt"
                and "Plano de jogo normal" or "Normal Game Plan"
            a11y.game_plan_active_tactical_label = nil
            a11y.game_plan_active_tactical_value = nil
            a11y.game_plan_active_tactical_widget = nil
            a11y.game_plan_active_tactical_frame = -10000
            active_control_row = nil
            active_controller_label = nil
            reset_focus_reuse_state()
            a11y.game_plan_last_focus_text = nil
            a11y.game_plan_announced_context = nil
        end
    end
    if not a11y.diagnostic_mode then return end
    a11y.diagnostic_input_sequence = a11y.diagnostic_input_sequence + 1
    local heading = a11y.game_plan_selected_heading
        or a11y.diagnostic_selected_heading
        or a11y.game_plan_last_focus_text
    local player = a11y.player_for_text(heading)
    a11y.diagnostic_sequence = a11y.diagnostic_sequence + 1
    a11y.diagnostic_write({
        string.format(
            "EVENT %d frame=%d kind=game-plan-input input=%d source=%s action=%s",
            a11y.diagnostic_sequence, frame,
            a11y.diagnostic_input_sequence, tostring(source), tostring(action)),
        string.format(
            "before heading=%q context=%q heading_age=%d",
            a11y.diagnostic_text(heading),
            a11y.diagnostic_text(a11y.game_plan_context),
            frame - a11y.diagnostic_selected_heading_frame),
        string.format(
            "player pointer=%s player_id=%s team_id=%s registered_position=%q attribute_panel=%s",
            a11y.diagnostic_hex(player and player.pointer),
            tostring(player and player.player_id or "unknown"),
            tostring(player and player.team_id or "unknown"),
            a11y.diagnostic_text(player and player.position),
            tonumber(ffi.C.GetTickCount64()) <=
                a11y.game_plan_attribute_panel_until_ms and "open" or "closed"),
        "",
    })
end

function a11y.record_game_plan_heading(text, widget_key)
    if not a11y.game_plan_active then
        return
    end
    local changed = text ~= a11y.game_plan_selected_heading
    if changed
            and tonumber(ffi.C.GetTickCount64()) <=
                a11y.game_plan_attribute_panel_until_ms
            and frame - a11y.game_plan_attribute_last_marker_frame > 12 then
        -- The attribute panel has closed, but its 30-second safety timer was
        -- still suppressing the newly selected player.
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
        a11y.game_plan_attribute_due_ms = nil
        a11y.game_plan_attribute_hold_until_ms = 0
    end
    a11y.game_plan_selected_heading = text
    a11y.game_plan_selected_heading_frame = frame
    a11y.game_plan_selected_heading_widget = widget_key
    if changed then
        -- This heading mutates in place and uniquely represents the selected
        -- player. Give its pitch/bench parent layout a few frames to finish
        -- rebinding before classifying the section.
        a11y.game_plan_selected_heading_due_frame = frame + 6
    end
    if not a11y.diagnostic_mode
            or text == a11y.diagnostic_selected_heading then return end
    local previous = a11y.diagnostic_selected_heading
    a11y.diagnostic_selected_heading = text
    a11y.diagnostic_selected_heading_frame = frame
    a11y.diagnostic_selected_heading_widget = widget_key
    a11y.diagnostic_selection_sequence =
        a11y.diagnostic_selection_sequence + 1
    a11y.diagnostic_player_visits[text] =
        (a11y.diagnostic_player_visits[text] or 0) + 1
    local player = a11y.player_for_text(text)
    a11y.diagnostic_sequence = a11y.diagnostic_sequence + 1
    a11y.diagnostic_write({
        string.format(
            "EVENT %d frame=%d kind=game-plan-selection selection=%d widget=%s",
            a11y.diagnostic_sequence, frame,
            a11y.diagnostic_selection_sequence, tostring(widget_key)),
        string.format(
            "transition previous=%q current=%q visit=%d",
            a11y.diagnostic_text(previous), a11y.diagnostic_text(text),
            a11y.diagnostic_player_visits[text]),
        string.format(
            "after_input action=%s source=%s delta_frames=%d",
            tostring(a11y.diagnostic_last_input_action or "none"),
            tostring(a11y.diagnostic_last_input_source or "none"),
            frame - a11y.diagnostic_last_input_frame),
        string.format(
            "player pointer=%s player_id=%s team_id=%s registered_position=%q",
            a11y.diagnostic_hex(player and player.pointer),
            tostring(player and player.player_id or "unknown"),
            tostring(player and player.team_id or "unknown"),
            a11y.diagnostic_text(player and player.position)),
        "",
    })
    -- Capture the UI object that displays the same player on the pitch/bench.
    -- Its parent chain is the missing structural signal for classifying the
    -- selected slot without player-name tables or assumptions about Option Files.
    local normalized = a11y.normalized_player_name(text)
    if not normalized then return end
    local matches = {}
    for candidate_key, candidate in pairs(ui_focus_widgets) do
        local candidate_name = a11y.normalized_player_name(candidate.text)
        if candidate_key ~= widget_key and candidate_name
                and (candidate_name:find(normalized, 1, true)
                    or normalized:find(candidate_name, 1, true)) then
            matches[#matches + 1] = {
                key = candidate_key,
                entry = candidate,
            }
        end
    end
    table.sort(matches, function(left, right)
        return left.key < right.key
    end)
    local lines = {
        string.format(
            "PLAYER-UI selection=%d heading_widget=%s name=%q matches=%d",
            a11y.diagnostic_selection_sequence,
            tostring(widget_key),
            a11y.diagnostic_text(normalized),
            #matches),
    }
    for _, match in ipairs(matches) do
        local address = match.entry.address
        local fields = {}
        if address and readable(address, 0x180) then
            for offset = 0, 0x178, 8 do
                fields[#fields + 1] = string.format(
                    "+0x%03x=%s", offset,
                    a11y.diagnostic_hex(read_u64(
                        memory.read(address + offset, 8))))
            end
        end
        lines[#lines + 1] = string.format(
            "card widget=%s text=%q age=%d qwords={%s}",
            match.key,
            a11y.diagnostic_text(match.entry.text),
            frame - (match.entry.last_seen or frame),
            table.concat(fields, ","))
        if address and readable(address + 0x38, 8) then
            local parent = read_u64(memory.read(address + 0x38, 8))
            local parent_fields = {}
            if parent and parent >= 0x10000 and readable(parent, 0x100) then
                for offset = 0, 0xf8, 8 do
                    parent_fields[#parent_fields + 1] = string.format(
                        "+0x%02x=%s", offset,
                        a11y.diagnostic_hex(read_u64(
                            memory.read(parent + offset, 8))))
                end
            end
            lines[#lines + 1] = string.format(
                "card_parent pointer=%s qwords={%s}",
                a11y.diagnostic_hex(parent),
                table.concat(parent_fields, ","))
        end
    end
    lines[#lines + 1] = ""
    a11y.diagnostic_write(lines)
end

function a11y.player_record_bits(bytes, offset, start_bit, bit_length)
    local first = bytes:byte(offset + 1) or 0
    local second = bytes:byte(offset + 2) or 0
    local third = bytes:byte(offset + 3) or 0
    local packed = first + second * 0x100 + third * 0x10000
    return math.floor(packed / (2 ^ start_bit)) % (2 ^ bit_length)
end

function a11y.capture_player_record(pointer, source)
    if not a11y.game_plan_active or pointer == nil or pointer == 0 then
        return false
    end
    local address = tonumber(pointer)
    if not address or address < 0x10000 then
        return false
    end
    local mbi = ffi.new("MEMORY_BASIC_INFORMATION[1]")
    if ffi.C.VirtualQuery(
            ffi.cast("void*", pointer), mbi, ffi.sizeof(mbi[0])) == 0 then
        return false
    end
    local protect = tonumber(mbi[0].Protect)
    local region_end = tonumber(ffi.cast("uint64_t", mbi[0].BaseAddress))
        + tonumber(mbi[0].RegionSize)
    if tonumber(mbi[0].State) ~= 0x1000
            or protect % 0x100 == 1
            or math.floor(protect / 0x100) % 2 == 1
            or address + 0x17c > region_end then
        return false
    end
    local bytes = memory.read(pointer, 0x17c)
    if type(bytes) ~= "string" or #bytes < 0x5c then
        return false
    end
    local name = bytes:sub(0x39, 0x47)
    local terminator = name:find("\0", 1, true)
    if terminator then
        name = name:sub(1, terminator - 1)
    end
    if not name or #name < 2 or name:find("%c") then
        return false
    end
    name = name:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if not name or #name < 2 then
        return false
    end
    local decoded = {}
    local plausible = 0
    for _, definition in ipairs(a11y.player_attribute_specs) do
        local value = a11y.player_record_bits(
            bytes, definition[3], definition[4], 7)
        if value >= 40 and value <= 99 then
            plausible = plausible + 1
        end
        decoded[#decoded + 1] = {
            label = a11y.ui_language == "pt" and definition[1] or definition[2],
            value = tostring(value),
            source = "player-record",
        }
    end
    if plausible < 20 then
        return false
    end
    local position_id = a11y.player_record_bits(bytes, 0x07, 4, 4)
    local positions = a11y.player_position_names[a11y.ui_language]
        or a11y.player_position_names.en
    local cached = {
        pointer = pointer,
        name = name,
        position = positions[position_id],
        attributes = decoded,
        player_id = memory.unpack("u32", bytes:sub(0x31, 0x34)),
        team_id = a11y.player_record_bits(bytes, 0x12c, 0, 16),
    }
    a11y.game_plan_player_cache[name] = cached
    local focused_name = a11y.normalized_player_name(
        a11y.game_plan_attribute_locked_name or a11y.game_plan_last_focus_text)
    if focused_name and focused_name ~= name
            and focused_name:sub(1, #name) ~= name then
        return true
    end
    local changed = a11y.game_plan_player_record ~= pointer
        or a11y.game_plan_player_name ~= (focused_name or name)
    a11y.game_plan_player_record = pointer
    a11y.game_plan_player_name = focused_name or name
    a11y.game_plan_player_attributes = decoded
    if tonumber(ffi.C.GetTickCount64()) <= a11y.game_plan_attribute_panel_until_ms then
        a11y.game_plan_attribute_items = decoded
        a11y.game_plan_attribute_index = 0
    end
    if changed and a11y.diagnostic_mode then
        a11y.diagnostic_sequence = a11y.diagnostic_sequence + 1
        local values = {}
        for _, item in ipairs(decoded) do
            values[#values + 1] = item.label .. "=" .. item.value
        end
        a11y.diagnostic_write({
            string.format(
                "EVENT %d frame=%d kind=player-record source=%s pointer=%s name=%q player_id=%s team_id=%s selected_heading=%q",
                a11y.diagnostic_sequence,
                a11y.current_frame or -1,
                tostring(source),
                memory.hex(pointer),
                a11y.diagnostic_text(name),
                tostring(cached.player_id),
                tostring(cached.team_id),
                a11y.diagnostic_text(a11y.diagnostic_selected_heading)),
            "attributes={" .. table.concat(values, "; ") .. "}",
            "",
        })
    end
    return true
end
local stadium_labels = {
    pt = {
        "Estádio",
        "Período",
        "Estação do ano/Clima",
        "Altura da grama",
        "Condições do campo",
    },
    en = {
        "Stadium",
        "Time",
        "Season/Weather",
        "Grass Length",
        "Pitch Conditions",
    },
}
local controller_tooltip_labels = {
    [18415703] = "Nome dos ajustes",
    [18415704] = "Configuração de comandos",
    [13500490] = "Alterar cursor",
    [13500498] = "Alterar cursor",
    [13500488] = "Alterar cursor",
    [18415713] = "Indicador de próximo jogador",
    [13500486] = "Tipo de cursor",
    [18415709] = "Nível de auxílio de passe",
    [18415710] = "Nível de auxílio de passe",
    [18415711] = "Nível de auxílio de passe",
    [18415712] = "Nível de auxílio de passe",
    [18415680] = "Tipo de lançamento",
    [18415681] = "Tipo de lançamento",
    [18415683] = "Tipo de chute",
    [18415684] = "Tipo de chute",
    [18415685] = "Guia de direção",
    [18415692] = "Guia de precisão",
    [18415687] = "Guia de posicionamento",
    [18415690] = "Drible automático",
    [18415650] = "Carrinho Autom.",
    [13238444] = "Nível da partida",
    [33489002] = "Duração da partida",
    [33489008] = "Prorrogação",
    [33489009] = "PN",
    [33489010] = "Nº de substituições",
}
local controller_tooltip_values = {
    [13500490] = "Com assistência",
    [13500498] = "Semiassist.",
    [13500488] = "Sem assistência",
    [18415709] = "Não",
    [18415710] = "Nível 1",
    [18415711] = "Nível 2",
    [18415712] = "Nível 3",
    [18415680] = "Básico",
    [18415681] = "Avançado",
    [18415683] = "Básico",
    [18415684] = "Avançado",
    [18415685] = "Sim",
    [18415692] = "Não",
    [18415687] = "Sim",
    [18415690] = "Sim",
    [18415650] = "Com assistência",
}

local function reset_message_state()
    recent_message_text = nil
    recent_message_widget_key = nil
    recent_message_frame = -10000
    pending_message_text = nil
    pending_message_key = nil
    pending_message_due_ms = nil
    last_announced_message_key = nil
    modal_focus_hold_until_ms = 0
    last_modal_button_frame = -10000
    modal_message_spoken_frame = -10000
    instruction_message_locked = false
    recent_heading_text = nil
    recent_heading_frame = -10000
    focused_control_hint = nil
    focused_control_hint_ms = 0
    a11y.ui_text_caller_by_widget = {}
    a11y.diagnostic_candidate_key = nil
    a11y.diagnostic_candidate_since = frame
    a11y.diagnostic_last_key = nil
end

local function reset_side_state()
    side_position = nil
    side_screen_active = false
    side_widget_positions = {}
    side_widget_count = 0
end

local function reset_focus_reuse_state()
    ui_focus_candidate_key = nil
    ui_focus_candidate_since = 0
    last_ui_focus_announcement = nil
    ui_focus_preferred_offset_index = nil
    focus_candidate_id = nil
    last_announced_focus_key = nil
    a11y.diagnostic_candidate_key = nil
    a11y.diagnostic_candidate_since = frame
end

local function reset_navigation_generation()
    ui_focus_widgets = {}
    ui_focus_widget_count = 0
    ui_focus_state = {}
    ui_focus_activated = {}
    reset_focus_reuse_state()
    last_selected_ui_entry = nil
    active_control_row = nil
    active_controller_label = nil
    pending_control_row = nil
    pending_controller_label = nil
    pending_controller_tooltip = nil
    pending_controller_tooltip_label = nil
    controller_tooltip_due_ms = nil
    last_spoken_controller_tooltip_key = nil
    dynamic_text_candidate = nil
    dynamic_text_due_ms = nil
    main_menu_tooltip = nil
    main_menu_tooltip_due_ms = nil
    main_menu_focus_guard_until = 0
    last_screen_title_key = nil
    last_controller_announcement = nil
    last_announced_control_row = nil
    last_announced_selector_label = nil
    control_rows_by_label_widget = {}
    control_row_by_value_widget = {}
    controller_rows = {}
    a11y.ui_text_caller_by_widget = {}
    slider_rows = {}
    slider_values = {}
    unmapped_sliders = {}
    dialog_options = {}
    dialog_signature = nil
    dialog_preferred_offset = nil
    dialog_focus_candidate = nil
    last_dialog_announcement = nil
    last_native_list_text = nil
    last_native_list_frame = -10000
    reset_message_state()
    reset_side_state()
end
local featured_initial_ids = {
    [60948637] = true,
}
local language_options = {}
local language_control_by_controller = {}
local non_control_labels = {
    ["OK"] = true,
    ["Confirmar"] = true,
    ["Voltar"] = true,
    ["Início"] = true,
}
local ui_focus_offsets = {
    -- 0x114/0x110 are used by the virtualized league and club lists.
    -- Check them before the less reliable auxiliary-state offsets.
    0x104, 0x114, 0x110, 0x108, 0x100, 0x10c,
    0xf0, 0xf4, 0xf8, 0xfc,
    0x118, 0x11c,
}
local dialog_focus_offsets = {
    0x104, 0x100, 0x108, 0x10c, 0x110, 0x114, 0x118, 0x11c,
    0x120, 0x124, 0x128, 0x12c, 0x130, 0x134, 0x138, 0x13c,
    0x140, 0x144, 0x148, 0x14c, 0x150, 0x154, 0x158, 0x15c,
    0x160, 0x164, 0x168, 0x16c, 0x170, 0x174, 0x178, 0x17c,
    0xfc, 0xf8, 0xf4, 0xf0, 0xec, 0xe8, 0xe4, 0xe0,
}

local function trace_log(message)
    if DEBUG_TRACE then
        log(message)
    end
end

ffi.cdef[[
    void *LoadLibraryW(const uint16_t *file_name);
    void *GetProcAddress(void *module, const char *procedure_name);
    int FreeLibrary(void *module);
    int MultiByteToWideChar(
        unsigned int code_page,
        unsigned long flags,
        const char *source,
        int source_length,
        uint16_t *destination,
        int destination_length);
    unsigned long GetCurrentProcessId(void);
    unsigned long long GetTickCount64(void);
    void *GetForegroundWindow(void);
    unsigned long GetWindowThreadProcessId(
        void *window,
        unsigned long *process_id);
    short GetAsyncKeyState(int virtual_key);
    int GetSystemMetrics(int index);
    typedef void *(__cdecl *FLACCESS_PRISM_INIT)(void *config);
    typedef void (__cdecl *FLACCESS_PRISM_SHUTDOWN)(void *context);
    typedef size_t (__cdecl *FLACCESS_PRISM_REGISTRY_COUNT)(void *context);
    typedef uint64_t (__cdecl *FLACCESS_PRISM_REGISTRY_ID_AT)(
        void *context, size_t index);
    typedef const char *(__cdecl *FLACCESS_PRISM_REGISTRY_NAME)(
        void *context, uint64_t backend_id);
    typedef int (__cdecl *FLACCESS_PRISM_REGISTRY_PRIORITY)(
        void *context, uint64_t backend_id);
    typedef void *(__cdecl *FLACCESS_PRISM_REGISTRY_CREATE)(
        void *context, uint64_t backend_id);
    typedef void (__cdecl *FLACCESS_PRISM_BACKEND_FREE)(void *backend);
    typedef const char *(__cdecl *FLACCESS_PRISM_BACKEND_NAME)(void *backend);
    typedef uint64_t (__cdecl *FLACCESS_PRISM_BACKEND_FEATURES)(void *backend);
    typedef int (__cdecl *FLACCESS_PRISM_BACKEND_INITIALIZE)(void *backend);
    typedef int (__cdecl *FLACCESS_PRISM_BACKEND_SPEAK)(
        void *backend, const char *text, bool interrupt);
    typedef struct {
        unsigned short wButtons;
        unsigned char bLeftTrigger;
        unsigned char bRightTrigger;
        short sThumbLX;
        short sThumbLY;
        short sThumbRX;
        short sThumbRY;
    } FLACCESS_XINPUT_GAMEPAD;
    typedef struct {
        unsigned long dwPacketNumber;
        FLACCESS_XINPUT_GAMEPAD Gamepad;
    } FLACCESS_XINPUT_STATE;
    unsigned long XInputGetState(
        unsigned long user_index,
        FLACCESS_XINPUT_STATE *state);
]]

local foreground_process_id = ffi.new("unsigned long[1]")
local user32 = ffi.load("user32")

function a11y.to_c_string(text)
    local buffer = ffi.new("char[?]", #text + 1)
    ffi.copy(buffer, text, #text)
    return buffer
end

local function to_wide(text)
    local source = a11y.to_c_string(text)
    local length = ffi.C.MultiByteToWideChar(
        65001, 0, source, #text, nil, 0)
    if length <= 0 then
        return nil
    end
    local wide = ffi.new("uint16_t[?]", length + 1)
    ffi.C.MultiByteToWideChar(65001, 0, source, #text, wide, length)
    return wide
end

function a11y.prism_proc(name, ctype)
    local address = ffi.C.GetProcAddress(
        a11y.prism_library, a11y.to_c_string(name))
    if address == nil then return nil end
    return ffi.cast(ctype, address)
end

function a11y.create_prism_backend(backend_id)
    if not backend_id or not a11y.prism_functions then return nil end
    local prism = a11y.prism_functions
    local backend = prism.registry_create(a11y.prism_context, backend_id)
    if backend == nil then return nil end
    if tonumber(prism.backend_features(backend)) % 2 ~= 1
            or prism.backend_initialize(backend) ~= 0 then
        prism.backend_free(backend)
        return nil
    end
    return backend
end

function a11y.replace_prism_backend(backend)
    if not backend then return false end
    local prism = a11y.prism_functions
    if a11y.prism_backend then
        prism.backend_free(a11y.prism_backend)
    end
    a11y.prism_backend = backend
    local name = prism.backend_name(backend)
    a11y.prism_backend_name = name ~= nil and ffi.string(name) or "unknown"
    log(string.format(
        "[FLAccess] native-prism-backend=%q",
        a11y.prism_backend_name))
    return true
end

function a11y.select_prism_backend(excluded_name)
    for _, reader in ipairs(a11y.prism_screen_readers) do
        if reader.name ~= excluded_name then
            local backend = a11y.create_prism_backend(reader.id)
            if backend then return a11y.replace_prism_backend(backend) end
        end
    end
    -- UIA is useful for Narrator and other readers which expose the Windows
    -- screen-reader flag. Without that flag it would initialize successfully
    -- but silently beat SAPI at the same Prism priority.
    if a11y.prism_uia_id and excluded_name ~= "UIA"
            and user32.GetSystemMetrics(70) ~= 0 then
        local backend = a11y.create_prism_backend(a11y.prism_uia_id)
        if backend then return a11y.replace_prism_backend(backend) end
    end
    local sapi = a11y.create_prism_backend(a11y.prism_sapi_id)
    return sapi and a11y.replace_prism_backend(sapi) or false
end

function a11y.initialize_native_prism()
    if a11y.prism_context then return true end
    if a11y.prism_failed or not a11y.sider_dir then return false end
    local dll_path = a11y.sider_dir .. "\\modules\\FLAccess-Prism\\prism.dll"
    local wide_path = to_wide(dll_path)
    a11y.prism_library = wide_path and ffi.C.LoadLibraryW(wide_path) or nil
    if a11y.prism_library == nil then
        a11y.prism_failed = true
        log(string.format("[FLAccess] native-prism-load-failed path=%q", dll_path))
        return false
    end
    local specifications = {
        {"init", "prism_init", "FLACCESS_PRISM_INIT"},
        {"shutdown", "prism_shutdown", "FLACCESS_PRISM_SHUTDOWN"},
        {"registry_count", "prism_registry_count", "FLACCESS_PRISM_REGISTRY_COUNT"},
        {"registry_id_at", "prism_registry_id_at", "FLACCESS_PRISM_REGISTRY_ID_AT"},
        {"registry_name", "prism_registry_name", "FLACCESS_PRISM_REGISTRY_NAME"},
        {"registry_priority", "prism_registry_priority", "FLACCESS_PRISM_REGISTRY_PRIORITY"},
        {"registry_create", "prism_registry_create", "FLACCESS_PRISM_REGISTRY_CREATE"},
        {"backend_free", "prism_backend_free", "FLACCESS_PRISM_BACKEND_FREE"},
        {"backend_name", "prism_backend_name", "FLACCESS_PRISM_BACKEND_NAME"},
        {"backend_features", "prism_backend_get_features", "FLACCESS_PRISM_BACKEND_FEATURES"},
        {"backend_initialize", "prism_backend_initialize", "FLACCESS_PRISM_BACKEND_INITIALIZE"},
        {"backend_speak", "prism_backend_speak", "FLACCESS_PRISM_BACKEND_SPEAK"},
    }
    a11y.prism_functions = {}
    for _, specification in ipairs(specifications) do
        local fn = a11y.prism_proc(specification[2], specification[3])
        if not fn then
            a11y.prism_failed = true
            log("[FLAccess] native-prism-export-missing " .. specification[2])
            return false
        end
        a11y.prism_functions[specification[1]] = fn
    end
    local prism = a11y.prism_functions
    a11y.prism_context = prism.init(nil)
    if a11y.prism_context == nil then
        a11y.prism_failed = true
        log("[FLAccess] native-prism-init-failed")
        return false
    end
    local supported_readers = {
        VoiceOver=true, NVDA=true, JAWS=true, Orca=true,
        ["Android Screen Reader"]=true, ZDSR=true, ZoomText=true,
        BoyPCReader=true, PCTalker=true, SenseReader=true,
        SystemAccess=true, WindowEyes=true, Spiel=true,
    }
    a11y.prism_screen_readers = {}
    local count = tonumber(prism.registry_count(a11y.prism_context))
    for index = 0, count - 1 do
        local id = prism.registry_id_at(a11y.prism_context, index)
        local name_pointer = prism.registry_name(a11y.prism_context, id)
        local name = name_pointer ~= nil and ffi.string(name_pointer) or ""
        if name == "SAPI" then
            a11y.prism_sapi_id = id
        elseif name == "UIA" then
            a11y.prism_uia_id = id
        elseif supported_readers[name] then
            a11y.prism_screen_readers[#a11y.prism_screen_readers + 1] = {
                id=id,
                name=name,
                priority=prism.registry_priority(a11y.prism_context, id),
            }
        end
    end
    table.sort(a11y.prism_screen_readers, function(left, right)
        return left.priority > right.priority
    end)
    if not a11y.select_prism_backend() then
        a11y.prism_failed = true
        log("[FLAccess] native-prism-no-backend")
        return false
    end
    log(string.format("[FLAccess] native-prism-ready path=%q", dll_path))
    return true
end

function a11y.refresh_native_prism(now_ms)
    if not a11y.prism_backend then return a11y.select_prism_backend() end
    local prism = a11y.prism_functions
    if a11y.prism_backend_name ~= "SAPI" then
        if tonumber(prism.backend_features(a11y.prism_backend)) % 2 ~= 1 then
            local failed_name = a11y.prism_backend_name
            return a11y.select_prism_backend(failed_name)
        end
        return true
    end
    if now_ms < a11y.prism_next_reader_probe_ms then return true end
    a11y.prism_next_reader_probe_ms = now_ms + 750
    for _, reader in ipairs(a11y.prism_screen_readers) do
        local backend = a11y.create_prism_backend(reader.id)
        if backend then return a11y.replace_prism_backend(backend) end
    end
    if a11y.prism_uia_id and user32.GetSystemMetrics(70) ~= 0 then
        local backend = a11y.create_prism_backend(a11y.prism_uia_id)
        if backend then return a11y.replace_prism_backend(backend) end
    end
    return true
end

local function start_native_prism(ctx)
    a11y.sider_dir = ctx.sider_dir
    a11y.initialize_native_prism()
end

read_u64 = function(bytes)
    return memory.unpack("u64", bytes)
end

readable = function(address, size)
    local mbi = ffi.new("MEMORY_BASIC_INFORMATION[1]")
    if ffi.C.VirtualQuery(ffi.cast("void*", address), mbi, ffi.sizeof(mbi[0])) == 0 then
        return false
    end
    local protect = tonumber(mbi[0].Protect)
    return tonumber(mbi[0].State) == 0x1000
        and protect % 0x100 ~= 1
        and math.floor(protect / 0x100) % 2 ~= 1
        and tonumber(ffi.cast("uint64_t", address)) + size
            <= tonumber(ffi.cast("uint64_t", mbi[0].BaseAddress))
                + tonumber(mbi[0].RegionSize)
end

local function game_is_foreground()
    local window = user32.GetForegroundWindow()
    if window == nil then
        return false
    end
    foreground_process_id[0] = 0
    user32.GetWindowThreadProcessId(window, foreground_process_id)
    return tonumber(foreground_process_id[0]) ==
        tonumber(ffi.C.GetCurrentProcessId())
end

local function clean_text(text)
    -- PES formatting markers use control byte 0x11 plus two command bytes.
    -- Keep the controls used by Game Plan tutorials. Stripping every marker
    -- made sentences such as "hold A" become only "hold".
    if a11y.ui_language == "pt" then
        text = text:gsub("\17ka", "botão A")
        text = text:gsub("\17jm", "analógico esquerdo")
        text = text:gsub("\238\130\146", "direcional")
    else
        text = text:gsub("\17ka", "A button")
        text = text:gsub("\17jm", "left stick")
        text = text:gsub("\238\130\146", "D-pad")
    end
    text = text:gsub("\17..", "")
    text = text:gsub("[\r\n\t]+", " ")
    text = text:gsub("[%z\1-\31]", "")
    -- Form arrows and condition icons are Unicode Private Use Area glyphs.
    -- They have no useful spoken name and can stop some speech backends.
    text = text:gsub("\238[\128-\191][\128-\191]", "")
    text = text:match("^%s*(.-)%s*$") or ""
    return text
end

a11y.ui_strings = {
    pt = {
        title = "FLAccess %s",
        menu_reading = "Leitura de menus: ativa",
        speech_output = "Saída de fala: Prism; leitor de telas quando disponível; SAPI como fallback",
        tooltip_option = "Ler tooltips: %s",
        diagnostic_option = "Modo de diagnóstico: %s",
        yes = "Sim",
        no = "Não",
        navigate_options = "6 e 7: navegar pelas opções",
        change_option = "9 e 0: alterar a opção selecionada",
        restore_defaults = "8: restaurar o padrão",
        close_sider = "Espaço: fechar o Sider",
        next_module = "1: próximo módulo do Sider",
        previous_module = "Crase: módulo anterior do Sider",
        opened = "Sider. FLAccess versão %s. Leitura de menus ativa. Duas opções. %s. 6 e 7 navegam; 9 e 0 alteram; 8 restaura o padrão.",
        closed = "Sider fechado",
        tooltip_changed = "Ler tooltips, %s",
        diagnostic_changed = "Modo de diagnóstico, %s",
        diagnostic_file = "O diagnóstico será salvo em FLAccess-diagnostic.log",
        diagnostic_failed = "Não foi possível criar FLAccess-diagnostic.log",
        sider = "Sider",
        module = "módulo",
    },
    en = {
        title = "FLAccess %s",
        menu_reading = "Menu reading: enabled",
        speech_output = "Speech output: Prism; screen reader when available; SAPI as fallback",
        tooltip_option = "Read tooltips: %s",
        diagnostic_option = "Diagnostic mode: %s",
        yes = "Yes",
        no = "No",
        navigate_options = "6 and 7: navigate options",
        change_option = "9 and 0: change the selected option",
        restore_defaults = "8: restore the default",
        close_sider = "Space: close Sider",
        next_module = "1: next Sider module",
        previous_module = "Grave accent: previous Sider module",
        opened = "Sider. FLAccess version %s. Menu reading enabled. Two options. %s. 6 and 7 navigate; 9 and 0 change; 8 restores the default.",
        closed = "Sider closed",
        tooltip_changed = "Read tooltips, %s",
        diagnostic_changed = "Diagnostic mode, %s",
        diagnostic_file = "Diagnostics will be saved to FLAccess-diagnostic.log",
        diagnostic_failed = "Could not create FLAccess-diagnostic.log",
        sider = "Sider",
        module = "module",
    },
}

function a11y.strings()
    return a11y.ui_strings[a11y.ui_language] or a11y.ui_strings.en
end

function a11y.set_ui_language_from_name(name)
    local lower = tostring(name or ""):lower()
    if lower:find("portugu", 1, true) then
        a11y.ui_language = "pt"
    elseif lower ~= "" then
        a11y.ui_language = "en"
    end
    if lower ~= "" then
        a11y.ui_language_locked = true
    end
end

a11y.portuguese_ui_anchors = {
    ["Carregando..."] = true,
    ["Dados editados"] = true,
    ["Configurações"] = true,
    ["Comentário"] = true,
    ["Voltar"] = true,
}

function a11y.detect_ui_language(text)
    if not a11y.ui_language_locked and a11y.portuguese_ui_anchors[text] then
        a11y.ui_language = "pt"
    end
end

function a11y.load_config()
    local file = a11y.config_path and io.open(a11y.config_path, "rt") or nil
    if not file then
        return false
    end
    for line in file:lines() do
        local name, value = line:match("^%s*([%w_]+)%s*=%s*([%w_%-]+)")
        if name == "read_tooltips" then
            value = value:lower()
            a11y.read_tooltips = value ~= "false" and value ~= "no" and value ~= "0"
        end
    end
    file:close()
    return true
end

function a11y.save_config()
    if not a11y.config_path then
        return
    end
    local file = io.open(a11y.config_path, "wt")
    if not file then
        log(string.format(
            "[FLAccess] config-write-failed path=%q",
            a11y.config_path))
        return
    end
    file:write("# FLAccess settings\n")
    file:write("read_tooltips = ", a11y.read_tooltips and "true" or "false", "\n")
    file:close()
end

function a11y.diagnostic_text(text)
    return tostring(text or "")
        :gsub("[\r\n\t]+", " ")
        :gsub("[%z\1-\31]", "")
end

function a11y.diagnostic_hex(value)
    if value == nil then
        return "nil"
    end
    return memory.hex(value)
end

function a11y.diagnostic_write(lines)
    if not a11y.diagnostic_mode or not a11y.diagnostic_path then
        return false
    end
    local file = io.open(a11y.diagnostic_path, "at")
    if not file then
        log(string.format(
            "[FLAccess] diagnostic-write-failed path=%q",
            a11y.diagnostic_path))
        return false
    end
    if type(lines) == "table" then
        file:write(table.concat(lines, "\n"), "\n")
    else
        file:write(tostring(lines), "\n")
    end
    file:close()
    return true
end

function a11y.start_diagnostic(reason)
    if not a11y.diagnostic_path then
        return false
    end
    local file = io.open(a11y.diagnostic_path, "wt")
    if not file then
        log(string.format(
            "[FLAccess] diagnostic-start-failed path=%q",
            a11y.diagnostic_path))
        return false
    end
    a11y.diagnostic_sequence = 0
    a11y.diagnostic_candidate_key = nil
    a11y.diagnostic_candidate_since = 0
    a11y.diagnostic_last_key = nil
    a11y.diagnostic_slider_values = {}
    a11y.diagnostic_class_ids = {}
    a11y.diagnostic_class_count = 0
    a11y.diagnostic_last_snapshot_frame = -10000
    a11y.diagnostic_input_sequence = 0
    a11y.diagnostic_last_input_action = nil
    a11y.diagnostic_last_input_source = nil
    a11y.diagnostic_last_input_frame = -10000
    a11y.diagnostic_keyboard_state = {}
    a11y.diagnostic_gamepad_state = {}
    a11y.diagnostic_left_stick_direction = nil
    a11y.diagnostic_selected_heading = nil
    a11y.diagnostic_selected_heading_frame = -10000
    a11y.diagnostic_selected_heading_widget = nil
    a11y.diagnostic_selection_sequence = 0
    a11y.diagnostic_player_visits = {}
    file:write("FLAccess diagnostic\n")
    file:write("version=", VERSION, "\n")
    file:write("started=", os.date("!%Y-%m-%dT%H:%M:%SZ"), "\n")
    file:write("reason=", a11y.diagnostic_text(reason), "\n")
    file:write("policy=stable focus changes, bounded snapshots, and correlated Game Plan input/selection events; no continuous memory dump\n\n")
    file:close()
    return true
end

function a11y.set_diagnostic(enabled, reason)
    if enabled then
        a11y.diagnostic_mode = true
        if not a11y.start_diagnostic(reason or "enabled from Sider") then
            a11y.diagnostic_mode = false
            return false
        end
    else
        if a11y.diagnostic_mode then
            a11y.diagnostic_write({
                "END frame=" .. tostring(frame),
                "ended=" .. os.date("!%Y-%m-%dT%H:%M:%SZ"),
            })
        end
        a11y.diagnostic_mode = false
        a11y.diagnostic_candidate_key = nil
        a11y.diagnostic_last_key = nil
    end
    return true
end

function a11y.record_slider(kind, key, value, row, minimum, maximum)
    if not a11y.diagnostic_mode then
        return
    end
    local value_key = tostring(key) .. ":" .. tostring(value)
    if kind == "set" and a11y.diagnostic_slider_values[key] == value_key then
        return
    end
    a11y.diagnostic_slider_values[key] = value_key
    a11y.diagnostic_sequence = a11y.diagnostic_sequence + 1
    a11y.diagnostic_write({
        string.format(
            "EVENT %d frame=%d kind=slider-%s object=%s value=%s min=%s max=%s",
            a11y.diagnostic_sequence,
            frame,
            tostring(kind),
            tostring(key),
            tostring(value),
            tostring(minimum or (row and row.minimum) or "unknown"),
            tostring(maximum or (row and row.maximum) or "unknown")),
        string.format(
            "control label=%q type=%q mapped=%s",
            a11y.diagnostic_text(row and row.label or ""),
            a11y.diagnostic_text(row and row.role or "slider"),
            row and "true" or "false"),
        "",
    })
end

function a11y.clear_pending_tooltips()
    pending_controller_tooltip = nil
    pending_controller_tooltip_label = nil
    controller_tooltip_due_ms = nil
    main_menu_tooltip = nil
    main_menu_tooltip_due_ms = nil
    latest_generic_tooltip = nil
    latest_generic_tooltip_widget = nil
    latest_generic_tooltip_ms = 0
end

local function is_plain_text(text)
    return text:match("^Carregando") ~= nil
        or text:match("^Salvando") ~= nil
        or text:match("^Aguarde") ~= nil
end

local function is_splash_text(text)
    local lower = text:lower()
    return lower:find("smokepatch", 1, true) ~= nil
        or lower:find("smoke patch", 1, true) ~= nil
        or lower:find("edit file", 1, true) ~= nil
end

local function is_noninteractive_text(text)
    local lower = text:lower()
    return lower:find("conectar ao servidor", 1, true) ~= nil
        or lower:find("conecte ao servidor", 1, true) ~= nil
        or lower:find("connect to the server", 1, true) ~= nil
        or text:find("Dados de atualiz.", 1, true) ~= nil
        or text:find("Pont. unif.", 1, true) ~= nil
        or text == "Pontos da temporada"
        or text == "Progresso"
        or text == "Dados do sistema"
        or text == "Carregando a bola"
        or text == "FOR" or text == "STR"
        or text == "DRI" or text == "PAS"
        or text == "VEL" or text == "SPD"
        or text == "DEF" or text == "CHU" or text == "SHO"
        or (#text == 2 and text:match("^%u%u$") ~= nil
            and text ~= "OK" and text ~= "PN")
end

local function control_label_from_tooltip(text)
    if text:find("volume de uma variedade de efeitos sonoros", 1, true) then
        return "Efeitos sonoros do menu"
    elseif text:find("volume da música de fundo", 1, true) then
        return "Volume da música de fundo"
    elseif text:find("número de usuários participantes", 1, true) then
        return "Número de usuários"
    elseif text:find("nível de dificuldade das partidas", 1, true) then
        return "Nível da partida"
    elseif text:find("duração da partida", 1, true) then
        return "Duração da partida"
    elseif text:find("jogadores sofrem lesões", 1, true) then
        return "Lesões"
    end
    return nil
end

local function looks_like_message(text)
    return not is_noninteractive_text(text) and not is_splash_text(text)
        and (#text >= 55
        or (#text >= 28 and text:match("[%.%!%?]$") ~= nil)
    )
end

function a11y.is_instruction_message(text)
    local lower = text:lower()
    return lower:find("enquanto segura", 1, true) ~= nil
        or lower:find("mantendo pressionado", 1, true) ~= nil
        or lower:find("use escalação/editar posição", 1, true) ~= nil
        or lower:find("while holding", 1, true) ~= nil
        or lower:find("hold the", 1, true) ~= nil
        or lower:find("use team sheet/edit position", 1, true) ~= nil
end

local function is_modal_button(text)
    return text == "Sim" or text == "Não" or text == "OK"
end

local function is_data_notice(text)
    local lower = text:lower()
    return lower:find("dados edit", 1, true) ~= nil
        or lower:find("dados de edi", 1, true) ~= nil
end

local function register_dialog_option(text, widget, widget_key)
    if text ~= "Sim" and text ~= "Não" then
        return
    end
    local previous_option = dialog_options[text]
    if previous_option and frame - previous_option.last_seen > 30 then
        dialog_signature = nil
        dialog_preferred_offset = nil
        dialog_focus_candidate = nil
        dialog_focus_candidate_since = 0
        last_dialog_announcement = nil
    end
    dialog_options[text] = {
        address = widget,
        key = widget_key,
        last_seen = frame,
    }
    local yes = dialog_options["Sim"]
    local no = dialog_options["Não"]
    if yes and no and yes.key ~= no.key
            and math.abs(yes.last_seen - no.last_seen) <= 3 then
        local signature = no.key .. ":" .. yes.key
        if signature ~= dialog_signature then
            dialog_signature = signature
            dialog_preferred_offset = nil
            dialog_focus_candidate = nil
            dialog_focus_candidate_since = 0
            last_dialog_announcement = nil
            a11y.dialog_button_queued_for_message = false
        end
    end
end

local queue_recent_message

local function add_recent_heading_to_message()
    if recent_heading_text and frame - recent_heading_frame <= 12
            and not recent_message_text:find(recent_heading_text, 1, true) then
        recent_message_text = recent_heading_text .. ". " .. recent_message_text
    end
end

local function remember_message_text(text, widget_key)
    if is_modal_button(text) or is_noninteractive_text(text) then
        return
    end
    local lower = text:lower()
    if lower:find("quer usar a configuração básica", 1, true)
            or lower:find("use basic settings", 1, true) then
        -- The prompt's Usar/Não usar widgets remain allocated after the
        -- dialog closes and can later regain a stale focus bit. Track the
        -- real prompt lifetime so those recycled controls cannot interrupt
        -- player names in Edit Position.
        a11y.game_plan_basic_prompt_active = true
    end
    if text:find("A partida começará quando os dois times", 1, true)
            or lower:find("match will begin when both teams", 1, true) then
        if not a11y.pre_match_active then
            a11y.pre_match_entry_pending = true
            a11y.pre_match_entry_guard_until_frame = frame + 120
            a11y.pre_match_last_action = nil
        end
        a11y.pre_match_active = true
        a11y.game_plan_active = false
        a11y.game_plan_main_surface = false
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
        a11y.game_plan_context = nil
        a11y.game_plan_announced_context = nil
        a11y.game_plan_last_focus_text = nil
        a11y.game_plan_last_menu_focus = nil
        a11y.game_plan_attribute_due_ms = nil
        a11y.game_plan_attribute_hold_until_ms = 0
        a11y.game_plan_basic_prompt_active = false
        a11y.stadium_active = false
        a11y.pre_match_notice_text = text
    elseif text:find("Se você voltar à tela anterior", 1, true)
            or lower:find("if you return to the previous screen", 1, true) then
        -- Only enable the specialized dialog reader for this real, current
        -- confirmation. The former always-on reader retained stale Sim/Não
        -- widgets after dialogs closed.
        a11y.confirmation_dialog_until_frame = frame + 900
    end
    if recent_message_text
            and a11y.is_instruction_message(recent_message_text)
            and recent_message_text ~= text then
        queue_recent_message()
        -- A paged tutorial can replace the same text buffer without closing
        -- the dialog. Finish the previous page, then allow the new page to
        -- become the current candidate instead of discarding it.
        recent_message_text = nil
        recent_message_widget_key = nil
        recent_message_frame = -10000
    end
    -- Main-menu help is reconstructed from localization IDs below. The
    -- rendered copy contains control bytes and must not interrupt the title.
    if current_main_menu_title and frame < main_menu_focus_guard_until then
        return
    end
    if recent_message_text
            and frame - recent_message_frame <= 4
            and not is_data_notice(recent_message_text)
            and not recent_message_text:match("[%.%!%?]$")
            and recent_message_text ~= text
            and not recent_message_text:find(text, 1, true)
            and #text <= 120 then
        recent_message_text = recent_message_text .. " " .. text
        recent_message_frame = frame
        log(string.format(
            "[FLAccess] message-append text=%q",
            recent_message_text))
        if is_data_notice(recent_message_text)
                or frame - last_modal_button_frame <= 120 then
            queue_recent_message()
        elseif a11y.is_instruction_message(recent_message_text) then
            instruction_message_locked = true
            add_recent_heading_to_message()
            queue_recent_message()
        elseif #recent_message_text >= 100
                and not instruction_message_locked then
            instruction_message_locked = true
            add_recent_heading_to_message()
            queue_recent_message()
        end
        return
    end
    if looks_like_message(text) or is_data_notice(text) then
        recent_message_text = text
        recent_message_widget_key = widget_key
        recent_message_frame = frame
        log(string.format(
            "[FLAccess] message-candidate text=%q",
            recent_message_text))
        if text:find("A partida começará quando os dois times", 1, true)
                or is_data_notice(recent_message_text)
                or frame - last_modal_button_frame <= 120 then
            queue_recent_message()
        elseif a11y.is_instruction_message(recent_message_text) then
            instruction_message_locked = true
            add_recent_heading_to_message()
            queue_recent_message()
        elseif #recent_message_text >= 100
                and not instruction_message_locked then
            instruction_message_locked = true
            add_recent_heading_to_message()
            queue_recent_message()
        end
    end
end

function a11y.poll_direct_message_update()
    if not recent_message_widget_key
            or not recent_message_text
            or not a11y.is_instruction_message(recent_message_text)
            or frame - recent_message_frame > 3600 then return end
    local string_object =
        a11y.ui_string_object_by_widget[recent_message_widget_key]
    if not string_object then return end
    local text = a11y.read_msvc_string(string_object)
    if not text or text == ""
            or text == ui_text_by_widget[recent_message_widget_key] then return end
    ui_text_by_widget[recent_message_widget_key] = text
    log(string.format(
        "[FLAccess] direct-message-update widget=%s text=%q",
        recent_message_widget_key, text))
    remember_message_text(text, recent_message_widget_key)
end

queue_recent_message = function()
    if not recent_message_text
            or frame - recent_message_frame > 120 then
        return
    end
    local key = (recent_message_widget_key or "") .. "\0" ..
        recent_message_text
    if key == last_announced_message_key then
        return
    end
    pending_message_text = recent_message_text
    pending_message_key = key
    pending_message_due_ms = tonumber(ffi.C.GetTickCount64()) + 40
    pending_controller_tooltip = nil
    pending_controller_tooltip_label = nil
    controller_tooltip_due_ms = nil
    dynamic_text_candidate = nil
    dynamic_text_due_ms = nil
    main_menu_tooltip = nil
    main_menu_tooltip_due_ms = nil
end

local function speak(text, interrupt)
    if not text or text == "" then
        return
    end
    if a11y.game_plan_active then
        local inside = text:match("%((.-)%)")
        local effective = inside and inside:gsub("%s+", "") or nil
        if effective and effective:match("^%d[%d%-]+$") then
            local default_suffix = (text:find("Padrão", 1, true)
                    or text:find("Default", 1, true))
                and (a11y.ui_language == "pt" and ", padrão" or ", default")
                or ""
            text = (a11y.ui_language == "pt" and "Formação " or "Formation ")
                .. effective .. default_suffix .. (a11y.ui_language == "pt"
                    and ", selecionada" or ", selected")
        end
    end
    if not game_is_foreground() then
        return
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if text == last_spoken_text and now_ms - last_spoken_ms < 800 then
        return
    end
    speech_sequence = speech_sequence + 1
    local mode = interrupt == false and "queue" or "interrupt"
    last_spoken_text = text
    last_spoken_ms = now_ms
    a11y.native_speech_last = a11y.native_speech_last + 1
    a11y.native_speech_queue[a11y.native_speech_last] = {
        sequence=speech_sequence,
        text=text,
        interrupt=interrupt ~= false,
        mode=mode,
    }
end

function a11y.flush_native_speech(now_ms)
    if a11y.native_speech_first > a11y.native_speech_last then return end
    if not a11y.initialize_native_prism()
            or not a11y.refresh_native_prism(now_ms) then
        if a11y.prism_failed then
            a11y.native_speech_queue = {}
            a11y.native_speech_first = 1
            a11y.native_speech_last = 0
        end
        return
    end
    while a11y.native_speech_first <= a11y.native_speech_last do
        local entry = a11y.native_speech_queue[a11y.native_speech_first]
        local native_text = a11y.to_c_string(entry.text)
        local error_code = a11y.prism_functions.backend_speak(
            a11y.prism_backend, native_text, entry.interrupt)
        if error_code ~= 0 then
            local failed_name = a11y.prism_backend_name
            if a11y.select_prism_backend(failed_name) then
                error_code = a11y.prism_functions.backend_speak(
                    a11y.prism_backend, native_text, entry.interrupt)
            end
        end
        if error_code ~= 0 then
            log(string.format(
                "[FLAccess] native-prism-speak-failed backend=%q error=%d text=%q",
                a11y.prism_backend_name or "none",
                error_code,
                entry.text))
        else
            log(string.format(
                "[FLAccess] speech sequence=%d backend=%q mode=%s text=%q",
                entry.sequence,
                a11y.prism_backend_name,
                entry.mode,
                entry.text))
        end
        a11y.native_speech_queue[a11y.native_speech_first] = nil
        a11y.native_speech_first = a11y.native_speech_first + 1
    end
    a11y.native_speech_queue = {}
    a11y.native_speech_first = 1
    a11y.native_speech_last = 0
end

local function is_screen_title(text)
    return text == "Escolha seu time"
        or text == "Escolher seu time"
        or text == "Escolha o seu time"
end

local function announce_screen_title(text, widget_key)
    if not is_screen_title(text) then
        return
    end
    local key = (widget_key or "") .. "\0" .. text
    if key ~= last_screen_title_key then
        last_screen_title_key = key
        speak(text)
    end
end

local function enqueue_startup_speech(text, duration_ms)
    if not text or text == "" or startup_speech.seen[text] then
        return
    end
    startup_speech.seen[text] = true
    startup_speech.last = startup_speech.last + 1
    startup_speech.queue[startup_speech.last] = {
        text = text,
        duration_ms = duration_ms or 1000,
    }
end

local function queue_startup_text(text, now_ms)
    local lower = text:lower()
    if lower:find("edit file", 1, true) then
        startup_speech.version = text
        startup_speech.version_due_ms = now_ms + 5000
        return true
    end
    if lower:find("smokepatch", 1, true)
            or lower:find("smoke patch", 1, true) then
        if startup_speech.version and not startup_speech.version_queued then
            enqueue_startup_speech(startup_speech.version, 1500)
            startup_speech.version_queued = true
        end
        return true
    end
    if is_plain_text(text) and not startup_complete then
        if startup_speech.version and not startup_speech.version_queued then
            enqueue_startup_speech(startup_speech.version, 1500)
            startup_speech.version_queued = true
        end
        enqueue_startup_speech(text, 900)
        return true
    end
    return false
end

local function process_startup_speech(now_ms)
    if startup_speech.version and not startup_speech.version_queued
            and startup_speech.version_due_ms
            and now_ms >= startup_speech.version_due_ms then
        enqueue_startup_speech(startup_speech.version, 1500)
        startup_speech.version_queued = true
    end
    if now_ms < startup_speech.next_ms then
        return true
    end
    local item = startup_speech.queue[startup_speech.first]
    if item then
        startup_speech.queue[startup_speech.first] = nil
        startup_speech.first = startup_speech.first + 1
        speak(item.text)
        startup_speech.next_ms = now_ms + item.duration_ms
        return true
    end
    return false
end

local function selector_role(label)
    if label == "Nome dos ajustes" then
        return "campo de texto"
    end
    return "seletor"
end

local function control_speech(row)
    local spoken = row.label .. ", " .. (row.role or selector_role(row.label))
    if row.value and row.value ~= "" then
        spoken = spoken .. ", " .. row.value
    end
    return spoken
end

local function announce_control(row)
    if not row or not row.label then
        return
    end
    local spoken = control_speech(row)
    if spoken ~= last_controller_announcement
            or last_announced_control_row ~= row then
        if active_control_row ~= row then
            last_spoken_controller_tooltip_key = nil
            pending_controller_tooltip = nil
            pending_controller_tooltip_label = nil
            controller_tooltip_due_ms = nil
        end
        last_controller_announcement = spoken
        last_announced_control_row = row
        last_announced_selector_label = row.label_widget_key or row.label
        active_control_row = row
        active_controller_label = row.label
        active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
        if a11y.read_tooltips and latest_generic_tooltip
                and latest_generic_tooltip_widget ~= row.label_widget
                and active_control_focused_ms - latest_generic_tooltip_ms <= 1000 then
            pending_controller_tooltip = latest_generic_tooltip
            pending_controller_tooltip_label = row.label
            controller_tooltip_due_ms = active_control_focused_ms + 2000
        end
        speak(spoken)
    end
end

local function announce_control_value(row, value)
    if not row or not value or value == "" then
        return
    end
    row.value = value
    local full = control_speech(row)
    if full == last_controller_announcement
            and last_announced_control_row == row then
        return
    end
    last_controller_announcement = full
    last_announced_control_row = row
    local row_key = row.label_widget_key or row.label
    if active_control_row == row and last_announced_selector_label == row_key then
        speak(value)
    else
        active_control_row = row
        last_announced_selector_label = row_key
        speak(full)
    end
end

local function reset_stadium_screen()
    a11y.stadium_value_index_by_widget = {}
    a11y.stadium_rows = {}
    a11y.stadium_started_frame = frame
end

local function stadium_value_category(text)
    if text == "Dia" or text == "Noite"
            or text == "Day" or text == "Night" then
        return 2
    end
    if text == "Verão" or text == "Inverno" or text == "Primavera"
            or text == "Outono" or text == "Ensolarado"
            or text == "Chuva" or text == "Neve"
            or text == "Summer" or text == "Winter" or text == "Spring"
            or text == "Autumn" or text == "Fine" or text == "Rain"
            or text == "Snow" then
        return 3
    end
    if text == "Curta" or text == "Longa"
            or text == "Short" or text == "Long" then
        return 4
    end
    if text == "Seco" or text == "Molhado" or text == "Encharcado"
            or text == "Dry" or text == "Wet" or text == "Waterlogged" then
        return 5
    end
    return nil
end

local function stadium_control_for_entry(widget_key, entry)
    if not a11y.stadium_active or not widget_key or not entry then
        return nil
    end
    local index = a11y.stadium_value_index_by_widget[widget_key]
    if not index then
        index = stadium_value_category(entry.text)
        if index and a11y.stadium_rows[index]
                and a11y.stadium_rows[index].value_widget_key ~= widget_key then
            index = nil
        end
    end
    if not index and not a11y.stadium_rows[1] then
        -- The first focused value after opening this screen is the stadium.
        -- Unlike the remaining values, its text is an arbitrary stadium name.
        index = 1
    end
    if not index then
        -- "Aleatório" and "Normal" are shared by several rows. Assign a new
        -- value widget by the screen's verified top-to-bottom order and keep
        -- that ownership while its text changes laterally.
        for candidate = 2, 5 do
            if not a11y.stadium_rows[candidate] then
                index = candidate
                break
            end
        end
    end
    if not index then
        return nil
    end
    a11y.stadium_value_index_by_widget[widget_key] = index
    local labels = stadium_labels[a11y.ui_language] or stadium_labels.en
    local row = a11y.stadium_rows[index]
    if not row then
        row = {
            label = labels[index],
            role = "seletor",
            label_widget_key = "stadium:" .. tostring(index),
            value_widget_key = widget_key,
            is_control = true,
        }
        a11y.stadium_rows[index] = row
    end
    row.value_widget_key = widget_key
    row.value = entry.text
    return row
end

local function announce_controller_row(label, value)
    if not label then
        return
    end
    local row = controller_rows[label]
    if not row then
        row = {label = label, role = selector_role(label)}
        controller_rows[label] = row
    end
    if value and value ~= "" then
        row.value = value
    end
    row.is_control = true
    announce_control(row)
end

function a11y.read_msvc_string(object)
    if not object or object < 0x10000 or not readable(object, 0x20) then
        return nil
    end
    local length = tonumber(read_u64(memory.read(object + 0x10, 8)))
    local capacity = tonumber(read_u64(memory.read(object + 0x18, 8)))
    if not length or not capacity or length < 1 or length > 512 then
        return nil
    end
    local source = object
    if capacity >= 16 then
        source = read_u64(memory.read(object, 8))
    end
    if not source or source < 0x10000 or not readable(source, length) then
        return nil
    end
    return clean_text(memory.read(source, length))
end

local function current_row_label()
    if last_focused_id and widgets[last_focused_id] then
        return widgets[last_focused_id].text
    end
    return nil
end

local function spoken_row(text_id)
    local entry = widgets[text_id]
    if not entry then
        return nil
    end
    local value = slider_values[text_id]
    if value ~= nil then
        return string.format(
            "%s, controle deslizante, %d de 15", entry.text, value)
    end
    if is_noninteractive_text(entry.text) then
        return nil
    end
    if entry.text == "Em casa" or entry.text == "Fora"
            or entry.text == "Neutro" then
        return entry.text .. ", opção selecionada"
    end
    if is_plain_text(entry.text) or is_splash_text(entry.text)
            or looks_like_message(entry.text) then
        return entry.text
    end
    return entry.text .. ", item"
end

local function is_controller_widget(widget)
    local key = memory.hex(widget)
    local label_row = control_rows_by_label_widget[key]
    local value_row = control_row_by_value_widget[key]
    return (label_row and label_row.is_control)
        or (value_row and value_row.is_control)
end

local function is_selector_label(text)
    return controller_labels[text] or false
end

local function ui_focus_speech(text)
    if is_plain_text(text) or is_splash_text(text)
            or looks_like_message(text) then
        return text
    end
    if language_options[text] then
        return text .. ", opção selecionada"
    end
    if text == "Em casa" or text == "Fora" or text == "Neutro" then
        return text .. ", opção selecionada"
    end
    if text == "Sim" or text == "Não"
            or a11y.game_plan_basic_prompt_items[text] then
        return text .. ", botão selecionado"
    end
    local parenthesized_formation = text:match("%((.-)%)")
    local effective_formation = parenthesized_formation
        and parenthesized_formation:gsub("%s+", "") or nil
    if effective_formation and not effective_formation:match("^%d[%d%-]+$") then
        effective_formation = nil
    end
    if effective_formation then
        local default_suffix = (text:find("Padrão", 1, true)
                or text:find("Default", 1, true))
            and (a11y.ui_language == "pt" and ", padrão" or ", default")
            or ""
        if a11y.ui_language == "pt" then
            return "Formação " .. effective_formation .. default_suffix ..
                ", selecionada"
        end
        return "Formation " .. effective_formation .. default_suffix ..
            ", selected"
    elseif text:match("^%d[%d%-]+$") then
        if a11y.ui_language == "pt" then
            return "Formação " .. text .. ", selecionada"
        end
        return "Formation " .. text .. ", selected"
    end
    return text .. ", item selecionado"
end

function a11y.game_plan_player_section(text, heading_widget_key)
    local target = a11y.normalized_player_name(text)
    if not target then return nil end
    local best_section
    local best_score
    local best_age
    for candidate_key, candidate in pairs(ui_focus_widgets) do
        local candidate_name = a11y.normalized_player_name(candidate.text)
        if candidate_key ~= heading_widget_key and candidate.address
                and candidate_name then
            local score
            if candidate_name == target then
                score = 0
            elseif candidate_name:find(target, 1, true)
                    or target:find(candidate_name, 1, true) then
                score = 1
            end
            if score and readable(candidate.address + 0x18, 24) then
                local marker = memory.read(candidate.address + 0x18, 24)
                local parent_marker
                if readable(candidate.address + 0x38, 8) then
                    local parent = read_u64(memory.read(
                        candidate.address + 0x38, 8))
                    if parent and parent >= 0x10000
                            and readable(parent, 0x180) then
                        parent_marker = memory.read(parent, 0x180)
                    end
                end
                -- pitchPlayerName labels are also attached to hidden roster
                -- cards. Only the parent layout proves that the visible card
                -- belongs to the pitch; subPlayerName proves the bench.
                local section = (marker:find("subPlayerName", 1, true)
                        or (parent_marker and parent_marker:find(
                            "subPlayerName", 1, true)))
                        and "reserve"
                    or (parent_marker
                        and (parent_marker:find(
                            "gmlanPlayerNameStrPitch", 1, true)
                            or parent_marker:find(
                                "gmlanPlayerPosition", 1, true))
                        and "starter" or nil)
                local age = frame - (candidate.last_seen or frame)
                if section and (not best_score or score < best_score
                        or (score == best_score and age < best_age)) then
                    best_section = section
                    best_score = score
                    best_age = age
                end
            end
        end
    end
    return best_section
end

function a11y.game_plan_lineup_screen_visible()
    if not a11y.game_plan_active then return false end
    local context = a11y.game_plan_context
    return context == "Escalação/Editar posição"
        or context == "Team Sheet/Edit Position"
        or context == "Plano de jogo normal"
        or context == "Normal Game Plan"
end

function a11y.read_visible_game_plan_lineup()
    if not a11y.game_plan_lineup_screen_visible() then return false end
    local generation_frame = a11y.game_plan_lineup_generation_frame
    local players = {}
    local observed_starters = 0
    for _, observed in pairs(a11y.game_plan_observed_lineup) do
        if observed.section == "starter" then
            observed_starters = observed_starters + 1
        end
    end
    if observed_starters == 11 then
        for name, observed in pairs(a11y.game_plan_observed_lineup) do
            players[name] = {
                name = name,
                section = observed.section,
                number = observed.number or 999,
                widget = observed.widget,
            }
        end
    else
        for widget_key, entry in pairs(ui_focus_widgets) do
            local name = a11y.normalized_player_name(entry.text)
            if name and entry.address and not players[name] then
                local section = a11y.game_plan_player_section(entry.text, nil)
                if section then
                    players[name] = {
                        name = name,
                        section = section,
                        number = tonumber(entry.text:match("^%s*(%d+)%s+")) or 999,
                        widget = widget_key,
                    }
                end
            end
        end
    end
    local starters, reserves = {}, {}
    for _, player in pairs(players) do
        local target = player.section == "starter" and starters or reserves
        target[#target + 1] = player
    end
    local function order(left, right)
        if left.number ~= right.number then return left.number < right.number end
        return left.name < right.name
    end
    table.sort(starters, order)
    table.sort(reserves, order)
    log(string.format(
        "[FLAccess] lineup-read generation=%d starters=%d reserves=%d",
        generation_frame, #starters, #reserves))
    -- A football starting eleven must contain exactly eleven authoritative
    -- pitch containers. Never turn an incomplete/ambiguous scan into speech.
    if #starters ~= 11 then
        speak(a11y.ui_language == "pt"
            and "A escalação ainda não foi identificada com segurança."
            or "The lineup has not been identified safely yet.")
        return false
    end
    local function names(items)
        local result = {}
        for _, item in ipairs(items) do result[#result + 1] = item.name end
        return table.concat(result, ", ")
    end
    local spoken
    if a11y.ui_language == "pt" then
        spoken = "Escalação. Titulares: " .. names(starters)
            .. ". Reservas: " .. names(reserves)
    else
        spoken = "Lineup. Starters: " .. names(starters)
            .. ". Reserves: " .. names(reserves)
    end
    speak(spoken)
    local now_ms = tonumber(ffi.C.GetTickCount64())
    a11y.game_plan_attribute_hold_until_ms = now_ms
        + math.min(12000, math.max(3500, #spoken * 55 + 500))
    return true
end

function a11y.game_plan_focus_speech(text, widget_key)
    local context = a11y.game_plan_context
    if a11y.game_plan_basic_prompt_items[text]
            and not a11y.game_plan_basic_prompt_active then
        return nil
    end
    if a11y.game_plan_active
            and text == a11y.game_plan_last_focus_text
            and context == a11y.game_plan_announced_context then
        return nil
    end
    local tactical_label, tactical_value =
        text:match("^(.+)%s+:%s+(.+)$")
    local announcement
    if tactical_label and tactical_value
            and a11y.game_plan_tactical_labels[tactical_label] then
        announcement = tactical_label .. (a11y.ui_language == "pt"
            and ", seletor, " or ", selector, ") .. tactical_value
    else
        announcement = ui_focus_speech(text)
    end
    local player = a11y.player_for_text(text)
    local player_focus = (player or text:match("^%d+%s+%S"))
        and (a11y.game_plan_edit_contexts[context]
            or text:match("^%d+%s+%S"))
    if player_focus then
        if player and player.position then
            announcement = text .. (a11y.ui_language == "pt"
                and ", posição principal " or ", primary position ") ..
                player.position .. (a11y.ui_language == "pt"
                    and ", selecionado" or ", selected")
        end
        local section = a11y.game_plan_player_section(text, widget_key)
        if section then
            a11y.game_plan_last_player_section = section
            local normalized_name = a11y.normalized_player_name(text)
            if normalized_name then
                a11y.game_plan_observed_lineup[normalized_name] = {
                    section = section,
                    number = tonumber(text:match("^%s*(%d+)%s+")) or 999,
                    widget = widget_key,
                }
            end
            local section_speech
            if a11y.ui_language == "pt" then
                section_speech = section == "starter"
                    and "Titular. " or "Reserva. "
            else
                section_speech = section == "starter"
                    and "Starter. " or "Substitute. "
            end
            announcement = section_speech .. announcement
        else
            -- Never let an unclassified player inherit the preceding section.
            -- This was why Salah sounded like a reserve despite no match.
            a11y.game_plan_last_player_section = nil
        end
    elseif not a11y.game_plan_edit_contexts[context] then
        a11y.game_plan_last_player_section = nil
    end
    if a11y.game_plan_active then
        a11y.game_plan_last_focus_text = text
        a11y.game_plan_last_focus_widget = widget_key
        a11y.game_plan_last_focus_frame = frame
        if context and context ~= a11y.game_plan_announced_context then
            a11y.game_plan_announced_context = context
            announcement = context .. ". " .. announcement
            a11y.game_plan_pending_title = nil
        end
    end
    return announcement
end

function a11y.process_game_plan_selected_heading(modal_focus_blocked)
    local due = a11y.game_plan_selected_heading_due_frame
    if not due or frame < due or modal_focus_blocked
            or tonumber(ffi.C.GetTickCount64()) <=
                a11y.game_plan_attribute_panel_until_ms then return false end
    a11y.game_plan_selected_heading_due_frame = nil
    local text = a11y.game_plan_selected_heading
    if not text or text == a11y.game_plan_last_announced_heading then
        return false
    end
    a11y.game_plan_last_announced_heading = text
    local announcement = a11y.game_plan_focus_speech(
        text, a11y.game_plan_selected_heading_widget)
    if announcement then
        speak(announcement)
        return true
    end
    return false
end

function a11y.process_game_plan_basic_menu_heading(modal_focus_blocked)
    local due = a11y.game_plan_basic_menu_heading_due_frame
    if not due or frame < due or modal_focus_blocked
            or (a11y.game_plan_context ~= "Menu de configuração básica"
                and a11y.game_plan_context ~= "Basic Settings Menu") then
        return false
    end
    a11y.game_plan_basic_menu_heading_due_frame = nil
    local text = a11y.game_plan_basic_menu_heading_text
    if not text then return false end
    local announcement = a11y.game_plan_focus_speech(
        text, a11y.game_plan_basic_menu_heading_widget)
    if announcement then
        speak(announcement)
        return true
    end
    return false
end

function a11y.game_plan_attribute_summary()
    local player = a11y.game_plan_player_name or a11y.game_plan_last_focus_text
    a11y.game_plan_attribute_items = {}
    a11y.game_plan_attribute_index = 0
    local configured = a11y.game_plan_attribute_names[a11y.ui_language]
        or a11y.game_plan_attribute_names.en
    if #a11y.game_plan_player_attributes > 0 then
        for _, item in ipairs(a11y.game_plan_player_attributes) do
            a11y.game_plan_attribute_items[#a11y.game_plan_attribute_items + 1] = item
        end
    else
        for definition_index = 1, 6 do
            local definition = configured[definition_index]
            local visible = false
            for _, event in ipairs(a11y.game_plan_attribute_text_events) do
                if event.text == definition[1]
                        and math.abs(event.frame
                            - a11y.game_plan_attribute_last_marker_frame) <= 180 then
                    visible = true
                    break
                end
            end
            if visible then
                a11y.game_plan_attribute_items[#a11y.game_plan_attribute_items + 1] = {
                    label = definition[2],
                    source = definition[1],
                }
            end
        end
        if #a11y.game_plan_attribute_items == 0 then
            for index = 1, 6 do
                a11y.game_plan_attribute_items[index] = {
                    label = configured[index][2],
                    source = configured[index][1],
                }
            end
        end
    end
    local overall
    for index = #a11y.game_plan_attribute_text_events, 1, -1 do
        local event = a11y.game_plan_attribute_text_events[index]
        local number = tonumber(event.text)
        if math.abs(event.frame - a11y.game_plan_attribute_last_marker_frame) <= 180
                and number and number >= 40 and number <= 99 then
            overall = number
            break
        end
    end
    if overall then
        table.insert(a11y.game_plan_attribute_items, 1, {
            label = a11y.ui_language == "pt"
                and "Avaliação geral" or "Overall rating",
            value = tostring(overall),
            source = "overall",
        })
    end
    if a11y.diagnostic_mode then
        local captured = {}
        for _, event in ipairs(a11y.game_plan_attribute_text_events) do
            if math.abs(event.frame
                    - a11y.game_plan_attribute_last_marker_frame) <= 180 then
                captured[#captured + 1] = string.format(
                    "%d:%s:%q",
                    event.frame,
                    event.widget,
                    a11y.diagnostic_text(event.text))
            end
        end
        while #captured > 120 do
            table.remove(captured, 1)
        end
        a11y.diagnostic_sequence = a11y.diagnostic_sequence + 1
        a11y.diagnostic_write({
            string.format(
                "EVENT %d frame=%d kind=game-plan-attributes player=%q",
                a11y.diagnostic_sequence,
                frame,
                a11y.diagnostic_text(player or "")),
            "attribute_text_events={" .. table.concat(captured, "; ") .. "}",
            "",
        })
    end
    if a11y.ui_language == "pt" then
        local prefix = player and ("Atributos de " .. player .. ". ")
            or "Painel de atributos. "
        local detail = #a11y.game_plan_player_attributes > 0
            and "Valores individuais disponíveis. "
            or "Força, drible, passe, velocidade, defesa e chute. "
        return prefix .. detail ..
            "Use I e K ou o analógico direito para cima e para baixo para ler cada item."
    end
    local prefix = player and (player .. " attributes. ")
        or "Attributes panel. "
    local detail = #a11y.game_plan_player_attributes > 0
        and "Individual values are available. "
        or "Strength, dribbling, passing, speed, defending and shooting. "
    return prefix .. detail ..
        "Use I and K or move the right stick up and down to read each item."
end

function a11y.read_game_plan_attribute(direction)
    if tonumber(ffi.C.GetTickCount64()) > a11y.game_plan_attribute_panel_until_ms
            or #a11y.game_plan_attribute_items == 0 then
        return false
    end
    if a11y.game_plan_attribute_index == 0 then
        a11y.game_plan_attribute_index = 1
    else
        a11y.game_plan_attribute_index =
            a11y.game_plan_attribute_index + direction
    end
    if a11y.game_plan_attribute_index < 1 then
        a11y.game_plan_attribute_index = #a11y.game_plan_attribute_items
    elseif a11y.game_plan_attribute_index > #a11y.game_plan_attribute_items then
        a11y.game_plan_attribute_index = 1
    end
    local item = a11y.game_plan_attribute_items[a11y.game_plan_attribute_index]
    local spoken = item.label
    if item.value and item.value ~= "" then
        spoken = spoken .. ", " .. item.value
    elseif item.source ~= "overall" then
        spoken = spoken .. (a11y.ui_language == "pt"
            and ", exibido graficamente pelo jogo"
            or ", displayed graphically by the game")
    end
    speak(spoken)
    a11y.game_plan_attribute_hold_until_ms =
        tonumber(ffi.C.GetTickCount64()) + 900
    return true
end

function a11y.poll_diagnostic_keyboard()
    local inputs = {
        {0x26, "up"}, {0x28, "down"},
        {0x25, "left"}, {0x27, "right"},
        {0x59, "Y"}, {0x0d, "A"}, {0x1b, "escape"},
    }
    for _, input_entry in ipairs(inputs) do
        local down = user32.GetAsyncKeyState(input_entry[1]) < 0
        local previous = a11y.diagnostic_keyboard_state[input_entry[1]]
        if down and not previous then
            a11y.record_game_plan_input(input_entry[2], "keyboard")
        end
        a11y.diagnostic_keyboard_state[input_entry[1]] = down
    end
end

function a11y.poll_attribute_input(now_ms)
    a11y.poll_diagnostic_keyboard()
    local i_down = user32.GetAsyncKeyState(0x49) < 0
    local k_down = user32.GetAsyncKeyState(0x4b) < 0
    local o_down = user32.GetAsyncKeyState(0x4f) < 0
    local keyboard_y_down = user32.GetAsyncKeyState(0x59) < 0
    local escape_down = user32.GetAsyncKeyState(0x1b) < 0
    if escape_down and not a11y.attribute_escape_down then
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
    end
    if i_down and not a11y.attribute_i_down then
        a11y.read_game_plan_attribute(-1)
    elseif k_down and not a11y.attribute_k_down then
        a11y.read_game_plan_attribute(1)
    end
    if o_down and not a11y.lineup_keyboard_o_down
            and a11y.game_plan_lineup_screen_visible() then
        a11y.game_plan_lineup_due_ms = now_ms + 80
        a11y.game_plan_lineup_input = "O"
    end
    if keyboard_y_down and not a11y.attribute_keyboard_y_down
            and now_ms - a11y.game_plan_attribute_opened_ms > 500 then
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
    end
    a11y.attribute_i_down = i_down
    a11y.attribute_k_down = k_down
    a11y.lineup_keyboard_o_down = o_down
    a11y.attribute_keyboard_y_down = keyboard_y_down
    a11y.attribute_escape_down = escape_down

    if not a11y.xinput or now_ms < (a11y.xinput_next_poll_ms or 0) then
        return
    end
    -- Sample once per render frame. The previous 80 ms interval could miss a
    -- quick D-pad tap, leaving pre-match and Game Plan speech waiting for a
    -- later visual debounce even though the game had already moved.
    a11y.xinput_next_poll_ms = now_ms + 16
    if a11y.xinput.XInputGetState(0, a11y.xinput_state) ~= 0 then
        a11y.attribute_right_stick_y = 0
        a11y.lineup_right_stick_x = 0
        return
    end
    local raw = tonumber(a11y.xinput_state[0].Gamepad.sThumbRY)
    local buttons = tonumber(a11y.xinput_state[0].Gamepad.wButtons)
    local y_down = math.floor(buttons / 0x8000) % 2 == 1
    local b_down = math.floor(buttons / 0x2000) % 2 == 1
    local gamepad_buttons = {
        {0x0001, "up"}, {0x0002, "down"},
        {0x0004, "left"}, {0x0008, "right"},
        {0x1000, "A"}, {0x8000, "Y"}, {0x2000, "B"},
    }
    for _, input_entry in ipairs(gamepad_buttons) do
        local down = math.floor(buttons / input_entry[1]) % 2 == 1
        local previous = a11y.diagnostic_gamepad_state[input_entry[1]]
        if down and not previous then
            a11y.record_game_plan_input(input_entry[2], "gamepad-button")
        end
        a11y.diagnostic_gamepad_state[input_entry[1]] = down
    end
    local left_x = tonumber(a11y.xinput_state[0].Gamepad.sThumbLX)
    local left_y = tonumber(a11y.xinput_state[0].Gamepad.sThumbLY)
    local left_direction = left_y > 16000 and "up"
        or (left_y < -16000 and "down"
        or (left_x < -16000 and "left"
        or (left_x > 16000 and "right" or nil)))
    if left_direction and not a11y.diagnostic_left_stick_direction then
        a11y.record_game_plan_input(left_direction, "gamepad-left-stick")
    end
    a11y.diagnostic_left_stick_direction = left_direction
    local right_x = tonumber(a11y.xinput_state[0].Gamepad.sThumbRX)
    local horizontal = right_x < -16000 and -1
        or (right_x > 16000 and 1 or 0)
    if horizontal == -1 and a11y.lineup_right_stick_x == 0
            and a11y.game_plan_lineup_screen_visible() then
        -- Horizontal right-stick movement has no documented Game Plan menu
        -- action. Use the left edge as a read-only accessibility command.
        a11y.game_plan_lineup_due_ms = now_ms + 80
        a11y.game_plan_lineup_input = "right-stick-left"
    end
    a11y.lineup_right_stick_x = horizontal
    if (b_down and not a11y.attribute_b_down)
            or (y_down and not a11y.attribute_y_down
                and now_ms - a11y.game_plan_attribute_opened_ms > 500) then
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
    end
    local vertical = raw > 16000 and 1 or (raw < -16000 and -1 or 0)
    if vertical ~= 0 and a11y.attribute_right_stick_y == 0 then
        a11y.read_game_plan_attribute(vertical > 0 and -1 or 1)
    end
    a11y.attribute_right_stick_y = vertical
    a11y.attribute_y_down = y_down
    a11y.attribute_b_down = b_down
end

local side_names = {"Em casa", "Neutro", "Fora"}

local function side_user(text)
    return text and text:match("^Usuário %d+$") ~= nil
end

local function speak_side(user, position)
    speak(user .. ", " .. side_names[position] .. ", selecionado")
end

local function begin_side_screen(initial_position, widget_key, user)
    side_screen_active = true
    local mapped_position = side_widget_positions[widget_key]
    if initial_position then
        mapped_position = initial_position
    elseif not mapped_position and side_widget_count < 3 then
        mapped_position = side_widget_count + 1
    end
    if not mapped_position then
        return
    end
    if not side_widget_positions[widget_key] then
        side_widget_count = math.max(side_widget_count, mapped_position)
        side_widget_positions[widget_key] = mapped_position
        log(string.format(
            "[FLAccess] side-widget widget=%s position=%d",
            widget_key,
            mapped_position))
    end
    side_position = mapped_position
    speak_side(user, side_position)
end

local function end_side_screen()
    if side_screen_active then
        side_widget_positions = {}
        side_widget_count = 0
    end
    side_screen_active = false
    side_position = nil
end

local function is_focused(text_id)
    local entry = widgets[text_id]
    if not entry or not readable(entry.address + 0x104, 4) then
        return false
    end
    return memory.unpack("u32", memory.read(entry.address + 0x104, 4)) == 1
end

local function is_widget_focused(widget)
    if not widget or not readable(widget + 0x104, 4) then
        return false
    end
    return memory.unpack("u32", memory.read(widget + 0x104, 4)) == 1
end

local function register_control_label(label, widget, role, is_control)
    local label_key = memory.hex(widget)
    local previous_row = control_rows_by_label_widget[label_key]
    if previous_row and previous_row.label == label then
        previous_row.role = role or previous_row.role
        previous_row.is_control = is_control or previous_row.is_control
        previous_row.created_frame = frame
        controller_rows[label] = previous_row
        pending_control_row = previous_row
        return previous_row
    end
    if previous_row and previous_row.value_widget_key
            and control_row_by_value_widget[previous_row.value_widget_key]
                == previous_row then
        control_row_by_value_widget[previous_row.value_widget_key] = nil
    end
    local row = {
        label = label,
        label_widget = widget,
        label_widget_key = label_key,
        role = role or selector_role(label),
        is_control = is_control or false,
        created_frame = frame,
        value_variants = {},
        value_variant_count = 0,
    }
    control_rows_by_label_widget[label_key] = row
    controller_rows[label] = row
    pending_control_row = row
    return row
end

local function attach_control_value(row, widget, value)
    if not row or widget == row.label_widget then
        return false
    end
    local value_key = memory.hex(widget)
    local previous_owner = control_row_by_value_widget[value_key]
    if previous_owner and previous_owner ~= row then
        previous_owner.value_widget = nil
        previous_owner.value_widget_key = nil
        previous_owner.value = nil
        previous_owner.is_control = controller_labels[previous_owner.label] or false
    end
    if row.value_widget_key and row.value_widget_key ~= value_key
            and control_row_by_value_widget[row.value_widget_key] == row then
        control_row_by_value_widget[row.value_widget_key] = nil
    end
    row.value_widget = widget
    row.value_widget_key = value_key
    row.value = value
    row.value_frame = frame
    if not row.value_variants then
        row.value_variants = {}
        row.value_variant_count = 0
    end
    if not row.value_variants[value] then
        row.value_variants[value] = true
        row.value_variant_count = row.value_variant_count + 1
    end
    row.is_control = row.is_control
        or row.native_slider
        or controller_labels[row.label]
        or (not non_control_labels[row.label]
            and row.value_variant_count >= 2)
    control_row_by_value_widget[value_key] = row
    return true
end

local function formatted_slider_value(row, value)
    if row.minimum == 0 and row.maximum == 15 then
        return tostring(value) .. " de 15"
    end
    return tostring(value)
end

local function bind_delayed_speed_slider(row)
    if not row or row.label ~= "Velocidade do jogo" then
        return
    end
    local best_key
    local best
    for key, candidate in pairs(unmapped_sliders) do
        if frame - (candidate.last_frame or frame) <= 60
                and (not best
                    or (candidate.last_frame or 0) > (best.last_frame or 0)) then
            best_key = key
            best = candidate
        end
    end
    if not best then
        return
    end
    row.role = "controle deslizante"
    row.native_slider = true
    row.minimum = best.minimum or -2
    row.maximum = best.maximum or 2
    row.is_control = true
    row.value = formatted_slider_value(row, best.value or 0)
    slider_rows[best_key] = {
        id = nil,
        text = row.label,
        control = row,
    }
    unmapped_sliders[best_key] = nil
    log(string.format(
        "[FLAccess] slider-map-delayed text=%q object=%s value=%d min=%d max=%d",
        row.label,
        best_key,
        best.value or 0,
        row.minimum,
        row.maximum))
end

function m.on_slider_init(ctx, event_id, registers)
    local slider = read_u64(registers.rcx)
    local maximum = tonumber(ffi.cast("int32_t", read_u64(registers.rdx)))
    local minimum = tonumber(ffi.cast("int32_t", read_u64(registers.r8)))
    local value = tonumber(ffi.cast("int32_t", read_u64(registers.r9)))
    local pending = pending_control_row
    local pending_is_fresh = pending
        and frame - (pending.created_frame or frame) <= 2
    local mapped_id = last_audio_id
    local mapped_entry = mapped_id and widgets[mapped_id] or nil
    local key = memory.hex(slider)
    if minimum >= -1000 and maximum <= 1000 and minimum < maximum then
        unmapped_sliders[key] = {
            minimum = minimum,
            maximum = maximum,
            value = value,
            last_frame = frame,
        }
    end
    if not mapped_entry and pending_is_fresh then
        mapped_entry = {
            text = pending.label,
            address = pending.label_widget,
        }
    end
    if mapped_entry and minimum >= -1000 and maximum <= 1000
            and minimum < maximum then
        local control = (not mapped_id and pending_is_fresh) and pending
            or register_control_label(
            mapped_entry.text,
            mapped_entry.address,
            "controle deslizante",
            true)
        control.role = "controle deslizante"
        control.native_slider = true
        control.minimum = minimum
        control.maximum = maximum
        control.is_control = true
        control.value = formatted_slider_value(control, value)
        slider_rows[key] = {
            id = mapped_id,
            text = mapped_entry.text,
            control = control,
        }
        unmapped_sliders[key] = nil
        if mapped_id then
            slider_values[mapped_id] = value
        end
        if a11y.game_plan_context == "Configurações táticas básicas"
                or a11y.game_plan_context == "Basic Tactical Settings" then
            active_control_row = control
            active_controller_label = control.label
            active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
            a11y.game_plan_active_tactical_label = control.label
            a11y.game_plan_active_tactical_value = control.value
            a11y.game_plan_active_tactical_widget = control.label_widget_key
            a11y.game_plan_active_tactical_frame = frame
            last_spoken_controller_tooltip_key = nil
        end
        log(string.format(
            "[FLAccess] slider-map id=%s text=%q object=%s value=%d min=%d max=%d",
            mapped_id and tostring(mapped_id) or "dynamic",
            mapped_entry.text,
            key,
            value,
            minimum,
            maximum))
        a11y.record_slider(
            "init", key, value, control, minimum, maximum)
        pending_control_row = nil
        last_audio_id = nil
    end
end

function m.on_slider_set(ctx, event_id, registers)
    local slider = read_u64(registers.rcx)
    local value = tonumber(ffi.cast("int32_t", read_u64(registers.rdx)))
    local key = memory.hex(slider)
    local row = slider_rows[key]
    if not row then
        local pending = unmapped_sliders[key] or {}
        pending.value = value
        pending.last_frame = frame
        unmapped_sliders[key] = pending
    end
    if row then
        if row.id then
            slider_values[row.id] = value
        end
        local full_value = formatted_slider_value(row.control, value)
        row.control.value = full_value
        local focused = active_control_row == row.control
            or (row.id and is_focused(row.id))
            or is_widget_focused(row.control.label_widget)
        if focused then
            if active_control_row == row.control then
                -- Preserve the range for the complete focus announcement, but
                -- lateral changes should say only the newly selected value.
                local full = control_speech(row.control)
                if last_announced_control_row ~= row.control then
                    announce_control(row.control)
                elseif full ~= last_controller_announcement then
                    last_controller_announcement = full
                    speak(tostring(value))
                end
            else
                announce_control(row.control)
            end
        end
    end
    a11y.record_slider(
        "set",
        key,
        value,
        row and row.control or nil,
        row and row.control.minimum or nil,
        row and row.control.maximum or nil)
    trace_log(string.format(
        "[FLAccess] slider-set value=%d object=%s id=%s text=%q",
        value,
        key,
        row and tostring(row.id) or "none",
        row and row.text or ""))
end

local function language_value(registers)
    local controller = read_u64(registers.rcx)
    local index = tonumber(ffi.cast("uint32_t", read_u64(registers.rdx)))
    if not controller or controller < 0x10000 or index > 255
            or not readable(controller + 0x90, 8) then
        return nil, controller, index
    end
    local first = read_u64(memory.read(controller + 0x90, 8))
    return a11y.read_msvc_string(first + index * 0x20), controller, index
end

local function language_value_at(controller, index)
    if not controller or controller < 0x10000 or not index or index > 255
            or not readable(controller + 0x90, 8) then
        return nil
    end
    local first = read_u64(memory.read(controller + 0x90, 8))
    return a11y.read_msvc_string(first + index * 0x20)
end

local function speak_language(registers, label, update_ui_language)
    local value, controller, index = language_value(registers)
    log(string.format(
        "[FLAccess] language-set label=%q object=%s index=%d value=%q",
        label,
        memory.hex(controller or 0),
        index or -1,
        value or ""))
    if value and value ~= "" then
        if update_ui_language then
            a11y.set_ui_language_from_name(value)
        end
        local key = "language:" .. memory.hex(controller or 0)
        local row = language_control_by_controller[key] or {
            label = label,
            role = "seletor",
            label_widget_key = key,
            is_control = true,
            external_value = true,
        }
        row.label = label
        row.value = value
        language_control_by_controller[key] = row
        announce_control(row)
    end
end

function m.on_game_text_language_set(ctx, event_id, registers)
    speak_language(registers, "Texto do jogo", true)
end

function m.on_commentary_language_set(ctx, event_id, registers)
    speak_language(registers, "Idioma do comentário", false)
end

function m.on_game_text_language_nav(ctx, event_id, registers)
    local controller = read_u64(registers.rbx)
    local index = tonumber(ffi.cast("uint32_t", read_u64(registers.rax)))
    local value = language_value_at(controller, index)
    log(string.format(
        "[FLAccess] language-nav object=%s index=%d value=%q",
        memory.hex(controller or 0),
        index or -1,
        value or ""))
    if value and value ~= "" then
        local key = "language:" .. memory.hex(controller or 0)
        local row = language_control_by_controller[key] or {
            label = "Texto do jogo",
            role = "seletor",
            label_widget_key = key,
            is_control = true,
            external_value = true,
        }
        language_control_by_controller[key] = row
        -- This startup screen has only one control. Repeating its label is
        -- useful context: a bare language name does not tell a screen-reader
        -- user whether it changes commentary, menus, or the game's text.
        row.value = value
        announce_control(row)
    end
end

function m.on_ui_text_set(ctx, event_id, registers)
    local widget = read_u64(registers.rcx)
    local string_object = read_u64(registers.rdx)
    local text = a11y.read_msvc_string(string_object)
    if not text or text == "" or widget < 0x10000 then
        return
    end

    local widget_key = memory.hex(widget)
    a11y.ui_string_object_by_widget[widget_key] = string_object
    if a11y.diagnostic_mode then
        local saved_rsp = read_u64(registers.rsp)
        if saved_rsp and readable(saved_rsp + 64, 8) then
            local return_address = read_u64(memory.read(saved_rsp + 64, 8))
            local caller_number = tonumber(return_address)
            local base_number = tonumber(process_base_u64)
            if caller_number and base_number and caller_number >= base_number
                    and caller_number < base_number + 0x40000000 then
                a11y.ui_text_caller_by_widget[widget_key] =
                    caller_number - base_number
            else
                a11y.ui_text_caller_by_widget[widget_key] = nil
            end
        end
    end
    local previous = ui_text_by_widget[widget_key]
    ui_text_by_widget[widget_key] = text
    local normal_game_plan_marker = text == "Escalação/Editar posição"
        or text == "Team Sheet/Edit Position"
    if normal_game_plan_marker and not a11y.game_plan_active then
        -- The normal Game Plan screen does not expose its visible "Plano de
        -- jogo" caption through the dedicated title widget used by submenus.
        -- Its Team Sheet/Edit Position command is unique to this surface and
        -- therefore provides a safe structural entry marker.
        a11y.game_plan_active = true
        a11y.game_plan_main_surface = true
        a11y.game_plan_context = a11y.ui_language == "pt"
            and "Plano de jogo normal" or "Normal Game Plan"
        a11y.game_plan_pending_title = a11y.game_plan_context
        a11y.game_plan_announced_context = nil
        a11y.game_plan_last_focus_text = nil
        a11y.game_plan_last_focus_widget = nil
        a11y.game_plan_last_menu_focus = text
        a11y.game_plan_selected_heading = nil
        a11y.game_plan_selected_heading_widget = nil
        a11y.game_plan_selected_heading_frame = -10000
        a11y.game_plan_selected_heading_due_frame = nil
        a11y.game_plan_last_announced_heading = nil
        a11y.game_plan_last_player_section = nil
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
        a11y.game_plan_attribute_due_ms = nil
        a11y.game_plan_attribute_hold_until_ms = 0
        a11y.game_plan_formation_active = false
        a11y.game_plan_lineup_generation_frame = frame
        a11y.pre_match_active = false
        a11y.pre_match_entry_pending = false
        -- Control widgets are aggressively recycled between screens. Do not
        -- let the last selector on the previous screen claim a Game Plan
        -- command (for example "Agressiva, Gestão de dados") as its value.
        active_control_row = nil
        active_controller_label = nil
        pending_control_row = nil
        focused_control_hint = nil
        pending_controller_tooltip = nil
        pending_controller_tooltip_label = nil
        controller_tooltip_due_ms = nil
        reset_focus_reuse_state()
        -- This default command can exist for only one render frame before the
        -- first-use tutorial opens. Capture and announce it synchronously so
        -- a quick confirmation still enters Edit Position with the right
        -- semantic context.
        local initial_announcement = a11y.game_plan_focus_speech(
            text,
            widget_key)
        if initial_announcement then
            speak(initial_announcement)
        end
    end
    local tactical_label, tactical_value =
        text:match("^(.+)%s+:%s+(.+)$")
    if tactical_label and tactical_value then
        local short_or_long_pass = tactical_value == "Passe curto"
            or tactical_value == "Passe longo"
            or tactical_value == "Short-pass"
            or tactical_value == "Long-pass"
            or tactical_value == "Short Pass"
            or tactical_value == "Long Pass"
        if short_or_long_pass and not a11y.game_plan_tactical_labels[
                tactical_label] then
            -- The second row exposes its current advanced-instruction value
            -- (for example "Provocador") where its label should be.
            tactical_label = a11y.ui_language == "pt"
                and "Construção" or "Build Up"
        end
    end
    local tactical_heading = a11y.game_plan_active
        and tactical_label and tactical_value
        and a11y.game_plan_tactical_labels[tactical_label]
    if tactical_heading then
        local entering_tactical = a11y.game_plan_context ~=
            "Configurações táticas básicas"
            and a11y.game_plan_context ~= "Basic Tactical Settings"
        if entering_tactical then
            a11y.game_plan_formation_active = false
            reset_focus_reuse_state()
            a11y.game_plan_last_focus_text = nil
            a11y.game_plan_announced_context = nil
        end
        a11y.game_plan_context = a11y.ui_language == "pt"
            and "Configurações táticas básicas" or "Basic Tactical Settings"
        local tactical_changed = tactical_label ~=
                a11y.game_plan_active_tactical_label
            or tactical_value ~= a11y.game_plan_active_tactical_value
        local horizontal_value_change = tactical_label ==
                a11y.game_plan_active_tactical_label
            and (a11y.diagnostic_last_input_action == "left"
                or a11y.diagnostic_last_input_action == "right")
            and frame - a11y.diagnostic_last_input_frame <= 12
        a11y.game_plan_active_tactical_label = tactical_label
        a11y.game_plan_active_tactical_value = tactical_value
        a11y.game_plan_active_tactical_widget = widget_key
        a11y.game_plan_active_tactical_frame = frame
        local row = controller_rows[tactical_label] or {
            label = tactical_label,
            role = a11y.ui_language == "pt" and "seletor" or "selector",
            label_widget_key = "game-plan-tactical:" .. tactical_label,
            is_control = true,
        }
        row.value = tactical_value
        row.is_control = true
        controller_rows[tactical_label] = row
        if tactical_changed then
            active_control_row = row
            active_controller_label = tactical_label
            active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
            last_controller_announcement = control_speech(row)
            last_announced_control_row = row
            last_announced_selector_label = row.label_widget_key
            last_spoken_controller_tooltip_key = nil
            speak(horizontal_value_change
                and tactical_value or last_controller_announcement)
            if pending_controller_tooltip
                    and frame - a11y.game_plan_tactical_navigation_frame <= 30 then
                pending_controller_tooltip_label = tactical_label
                controller_tooltip_due_ms =
                    tonumber(ffi.C.GetTickCount64()) + 250
            end
        end
    end
    local numbered_player_heading = a11y.game_plan_active
        and text:match("^%d+%s+%S") ~= nil
    local game_plan_player_heading = numbered_player_heading
        and a11y.game_plan_edit_contexts[a11y.game_plan_context]
    if game_plan_player_heading then
        a11y.record_game_plan_heading(text, widget_key)
    end
    if a11y.game_plan_active or a11y.game_plan_roster_contexts[text] then
        a11y.game_plan_attribute_text_events[
            #a11y.game_plan_attribute_text_events + 1] = {
                text = text,
                frame = frame,
                widget = widget_key,
            }
        while #a11y.game_plan_attribute_text_events > 256 do
            table.remove(a11y.game_plan_attribute_text_events, 1)
        end
    end
    local root_game_plan_title = text == "Menu de configuração básica"
        or text == "Basic Settings Menu"
    if root_game_plan_title then
        -- This widget is redrawn on every real transition back to the Basic
        -- Settings menu. Refusing it because the previous context differed
        -- left Formation active and silenced the menu after returning.
        a11y.game_plan_title_widgets[widget_key] = true
    end
    local authoritative_game_plan_title =
        a11y.game_plan_roster_contexts[text]
        and a11y.game_plan_title_widgets[widget_key]
    if authoritative_game_plan_title then
        local previous_game_plan_context = a11y.game_plan_context
        local entering_basic_menu = root_game_plan_title
            and a11y.game_plan_context ~= text
        local entering_edit = a11y.game_plan_edit_contexts[text]
            and not a11y.game_plan_edit_contexts[a11y.game_plan_context]
        local entering_lineup = (a11y.game_plan_edit_contexts[text]
                or text == "Plano de jogo normal"
                or text == "Normal Game Plan")
            and a11y.game_plan_context ~= text
        if entering_basic_menu then
            a11y.game_plan_basic_menu_heading_widget = nil
            a11y.game_plan_basic_menu_heading_text = nil
            a11y.game_plan_basic_menu_heading_due_frame = nil
            a11y.game_plan_basic_prompt_active = false
        end
        a11y.game_plan_active = true
        a11y.game_plan_main_surface = text == "Plano de jogo normal"
            or text == "Normal Game Plan"
        a11y.game_plan_context = text
        a11y.game_plan_pending_title = text
        if previous_game_plan_context ~= text then
            a11y.game_plan_formation_active = false
            a11y.game_plan_last_menu_focus = nil
            reset_focus_reuse_state()
            a11y.game_plan_last_focus_text = nil
            a11y.game_plan_last_focus_widget = nil
            a11y.game_plan_announced_context = nil
            a11y.game_plan_last_announced_heading = nil
            a11y.game_plan_selected_heading_due_frame = nil
        end
        if text ~= "Configurações táticas básicas"
                and text ~= "Basic Tactical Settings" then
            a11y.game_plan_active_tactical_label = nil
            a11y.game_plan_active_tactical_value = nil
            a11y.game_plan_active_tactical_widget = nil
            a11y.game_plan_last_player_section = nil
        end
        if entering_edit then
            a11y.game_plan_last_player_section = nil
            a11y.game_plan_last_announced_heading = nil
            a11y.game_plan_observed_lineup = {}
        end
        if entering_lineup then
            a11y.game_plan_lineup_generation_frame = frame
        end
        a11y.pre_match_active = false
        a11y.pre_match_entry_pending = false
        a11y.stadium_active = false
    elseif text == "Configurações do sistema"
            or text == "System Settings" then
        if not a11y.pre_match_active then
            a11y.pre_match_entry_pending = true
            a11y.pre_match_entry_guard_until_frame = frame + 120
            a11y.pre_match_last_action = nil
        end
        a11y.pre_match_active = true
        a11y.game_plan_active = false
        a11y.game_plan_main_surface = false
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
        a11y.game_plan_context = nil
        a11y.game_plan_announced_context = nil
        a11y.game_plan_last_focus_text = nil
        a11y.game_plan_attribute_due_ms = nil
        a11y.game_plan_attribute_hold_until_ms = 0
        a11y.game_plan_last_player_section = nil
        a11y.game_plan_basic_prompt_active = false
        a11y.game_plan_active_tactical_label = nil
        a11y.game_plan_active_tactical_value = nil
        a11y.stadium_active = false
    elseif text == "Altura da grama" or text == "Grass Length" then
        if not a11y.stadium_active
                or frame - a11y.stadium_last_marker_frame > 120 then
            reset_stadium_screen()
        end
        a11y.stadium_last_marker_frame = frame
        a11y.stadium_active = true
        a11y.game_plan_active = false
        a11y.game_plan_main_surface = false
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
        a11y.game_plan_context = nil
        a11y.game_plan_announced_context = nil
        a11y.game_plan_last_focus_text = nil
        a11y.game_plan_attribute_due_ms = nil
        a11y.game_plan_attribute_hold_until_ms = 0
        a11y.game_plan_last_player_section = nil
        a11y.game_plan_basic_prompt_active = false
        a11y.game_plan_active_tactical_label = nil
        a11y.game_plan_active_tactical_value = nil
        a11y.pre_match_active = false
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if a11y.game_plan_active
            and (text == "Altura (cm)" or text == "Height (cm)") then
        local panel_was_closed = now_ms > a11y.game_plan_attribute_panel_until_ms
        a11y.game_plan_attribute_last_marker_frame = frame
        local opened_by_y = a11y.diagnostic_last_input_action == "Y"
            and frame - a11y.diagnostic_last_input_frame <= 90
            and a11y.game_plan_selected_heading ~= nil
        if panel_was_closed and opened_by_y then
            a11y.game_plan_attribute_locked_name =
                a11y.normalized_player_name(
                    a11y.game_plan_selected_heading
                        or a11y.game_plan_last_focus_text)
            a11y.game_plan_player_record = nil
            a11y.game_plan_player_name =
                a11y.game_plan_attribute_locked_name
            a11y.game_plan_player_attributes = {}
            local player = a11y.player_for_text(
                a11y.game_plan_attribute_locked_name)
            if player then
                a11y.game_plan_player_record = player.pointer
                a11y.game_plan_player_name =
                    a11y.game_plan_attribute_locked_name or player.name
                a11y.game_plan_player_attributes = player.attributes
            end
            a11y.game_plan_attribute_due_ms = now_ms + 300
            a11y.game_plan_attribute_opened_ms = now_ms
        end
        if opened_by_y then
            a11y.game_plan_attribute_panel_until_ms = now_ms + 30000
        end
    end
    local tooltip_control_label = control_label_from_tooltip(text)
    if last_ui_text_ms > 0 and now_ms - last_ui_text_ms > 500 then
        -- A pause between text updates is not a screen boundary. Lists and
        -- side-selector cells legitimately create widgets after such a pause.
        reset_focus_reuse_state()
    end
    if previous ~= text then
        announce_screen_title(text, widget_key)
        local tactical_tooltip = a11y.game_plan_active
            and a11y.game_plan_active_tactical_label
            and frame - a11y.game_plan_active_tactical_frame <= 90
            and looks_like_message(text)
            and not a11y.is_instruction_message(text)
            and not tactical_heading
        if tactical_tooltip then
            if a11y.read_tooltips then
                pending_controller_tooltip = text
                pending_controller_tooltip_label =
                    a11y.game_plan_active_tactical_label
                active_controller_label =
                    a11y.game_plan_active_tactical_label
                controller_tooltip_due_ms = now_ms + 350
            end
        elseif tooltip_control_label then
            focused_control_hint = tooltip_control_label
            focused_control_hint_ms = now_ms
            if a11y.read_tooltips then
                pending_controller_tooltip = text
                pending_controller_tooltip_label = tooltip_control_label
                controller_tooltip_due_ms = now_ms + 2000
            end
        elseif not game_plan_player_heading and not tactical_heading then
            remember_message_text(text, widget_key)
        end
        if not queue_startup_text(text, now_ms)
                and is_plain_text(text)
                and not is_noninteractive_text(text) then
            speak(text)
        end
        if #text >= 4 and #text <= 50
                and not is_modal_button(text)
                and not is_plain_text(text)
                and not is_splash_text(text)
                and not is_noninteractive_text(text)
                and not text:match("^Usuário %d+$") then
            recent_heading_text = text
            recent_heading_frame = frame
        end
    end
    if is_modal_button(text) then
        last_modal_button_frame = frame
        if text ~= "OK" or not instruction_message_locked then
            queue_recent_message()
        end
    end
    if text == "No String" or text == "/" then
        -- These values are emitted while the game constructs a different
        -- screen. Clear both focus widgets and their semantic ownership: UI
        -- addresses are aggressively recycled between unrelated menus.
        reset_navigation_generation()
    end
    if text == "Sim" or text == "Não" then
        register_dialog_option(text, widget, widget_key)
    end
    last_ui_text_ms = now_ms
    if #text >= 2 and #text <= 50
            and not text:find("%%") and not text:match("^%d+$")
            and text ~= "-" and text:match("[%w]")
            and not is_noninteractive_text(text)
            and widget_key ~= main_menu_title_widget_key
            and text ~= main_menu_tooltip
            and not is_selector_label(text)
            and text ~= pending_controller_tooltip then
        local previous_focus = ui_focus_widgets[widget_key]
        if previous_focus and frame - previous_focus.last_seen > 30 then
            reset_focus_reuse_state()
        end
        if not ui_focus_widgets[widget_key] then
            if ui_focus_widget_count >= 300 then
                local oldest_key
                local oldest_frame = frame + 1
                for candidate_key, candidate in pairs(ui_focus_widgets) do
                    if (candidate.last_seen or 0) < oldest_frame then
                        oldest_key = candidate_key
                        oldest_frame = candidate.last_seen or 0
                    end
                end
                if oldest_key then
                    ui_focus_widgets[oldest_key] = nil
                    ui_focus_widget_count = ui_focus_widget_count - 1
                end
            end
            ui_focus_widget_count = ui_focus_widget_count + 1
        end
        ui_focus_widgets[widget_key] = {
            address = widget,
            text = text,
            last_seen = frame,
        }
    end

    local label_row = control_rows_by_label_widget[widget_key]
    if label_row and text ~= label_row.label then
        if label_row.value_widget_key
                and control_row_by_value_widget[label_row.value_widget_key]
                    == label_row then
            control_row_by_value_widget[label_row.value_widget_key] = nil
        end
        if controller_rows[label_row.label] == label_row then
            controller_rows[label_row.label] = nil
        end
        control_rows_by_label_widget[widget_key] = nil
        if active_control_row == label_row then
            active_control_row = nil
        end
        label_row = nil
    end

    local value_row
    if label_row and text == label_row.label then
        pending_control_row = label_row
    elseif active_control_row
            and not active_control_row.native_slider
            and not active_control_row.external_value
            and not a11y.game_plan_active
            and now_ms - active_control_focused_ms <= 500
            and widget ~= active_control_row.label_widget
            and not label_row
            and is_widget_focused(widget) then
        value_row = active_control_row
        attach_control_value(value_row, widget, text)
        pending_control_row = nil
    elseif pending_control_row
            and frame - (pending_control_row.created_frame or frame) <= 2
            and widget ~= pending_control_row.label_widget then
        value_row = pending_control_row
        attach_control_value(value_row, widget, text)
        pending_control_row = nil
    else
        value_row = control_row_by_value_widget[widget_key]
        if value_row and not value_row.native_slider then
            attach_control_value(value_row, widget, text)
        elseif value_row and value_row.native_slider then
            value_row = nil
        end
    end
    local tactical_context = a11y.game_plan_context ==
            "Configurações táticas básicas"
        or a11y.game_plan_context == "Basic Tactical Settings"
    if value_row and active_control_row == value_row and previous ~= text
            and not tactical_context then
        announce_control_value(value_row, text)
    end

    local seen_key = widget_key .. "\0" .. text
    if not ui_text_seen[seen_key] and ui_text_unique_count < 6000 then
        ui_text_seen[seen_key] = true
        ui_text_unique_count = ui_text_unique_count + 1
        trace_log(string.format(
            "[FLAccess] ui-text widget=%s previous=%q text=%q",
            widget_key,
            previous or "",
            text))
    end

end

-- The league/team carousel renders nine records around its selection. At this
-- call site r13 is the visible-cell index (0..8) and r15 is the corresponding
-- data record. Cell 4 is the real selected record, independent of scroll
-- direction and of the widget addresses recycled by the UI.
function m.on_list_item_render(ctx, event_id, registers)
    local visible_index = tonumber(read_u64(registers.r13))
    if visible_index ~= 4 then
        return
    end

    local record = tonumber(read_u64(registers.r15))
    if not record or record < 0x10000 or not readable(record + 0x20, 0x20) then
        return
    end

    local text = a11y.read_msvc_string(record + 0x20)
    if not text or text == "" or is_noninteractive_text(text) then
        return
    end
    if a11y.game_plan_context == "Configurações táticas básicas"
            or a11y.game_plan_context == "Basic Tactical Settings"
            or a11y.game_plan_edit_contexts[a11y.game_plan_context] then
        -- This renderer is shared by carousels and game-plan background
        -- lists. Tactical headings and player headings are authoritative.
        return
    end
    local formation_context = a11y.game_plan_context == "Alterar formação"
        or a11y.game_plan_context == "Change Formation"
    local formation_inside = text:match("%((.-)%)")
    local compact_formation = formation_inside
        and formation_inside:gsub("%s+", "") or nil
    local formation_value = (compact_formation
            and compact_formation:match("^%d[%d%-]+$"))
        or text:match("^%d[%d%-]+$")
    if a11y.game_plan_active and formation_context and formation_value then
        a11y.game_plan_formation_active = true
    elseif a11y.game_plan_active then
        -- Both teams' formations are permanently rendered on the normal Game
        -- Plan pitch. They are display data, not the focused bottom command.
        return
    end

    if text ~= last_native_list_text then
        last_native_list_text = text
        last_native_list_frame = frame
        log(string.format(
            "[FLAccess] native-list-focus text=%q record=%s",
            text,
            memory.hex(record)))
        speak(ui_focus_speech(text))
    end
end

-- Club selection uses a separate nine-cell renderer. r14 is its visible-cell
-- index and the game itself treats cell 4 as selected. Both native and
-- alternate/modded club-name branches build the displayed MSVC string in the
-- same stack slot immediately before assigning it to the UI widget.
function m.on_team_item_text(ctx, event_id, registers)
    local visible_index = tonumber(read_u64(registers.r14))
    if visible_index ~= 4 then
        return
    end

    local saved_rbp = tonumber(read_u64(registers.rbp))
    if not saved_rbp or saved_rbp < 0x10000 then
        return
    end
    local text = a11y.read_msvc_string(saved_rbp - 0x19)
    if not text or text == "" or is_noninteractive_text(text) then
        return
    end
    if a11y.game_plan_active then
        return
    end

    if text ~= last_native_list_text then
        last_native_list_text = text
        last_native_list_frame = frame
        log(string.format(
            "[FLAccess] native-team-focus text=%q",
            text))
        speak(ui_focus_speech(text))
    end
end

function m.on_player_record_copy(ctx, event_id, registers)
    local operation = tonumber(ffi.cast("uint32_t", read_u64(registers.rax)))
    if operation == 2 then
        a11y.capture_player_record(read_u64(registers.rdx), "copy")
    end
end

function m.on_player_record_lookup(ctx, event_id, registers)
    a11y.capture_player_record(read_u64(registers.rax), "lookup")
end

function m.on_resolved_text(ctx, event_id, registers)
    local source = read_u64(registers.rax)
    local length = tonumber(read_u64(registers.r8))
    if not source or not length or length < 1 or length > 512 then
        return
    end

    local text = memory.read(source, length)
    local zero = text:find("\0", 1, true)
    if zero then
        text = text:sub(1, zero - 1)
    end

    -- At this hook location, Sider's saved RSP is 64 bytes below the
    -- localization resolver caller's return address.
    local saved_rsp = read_u64(registers.rsp)
    local return_address = read_u64(memory.read(saved_rsp + 64, 8))
    local caller_rva = tonumber(return_address - process_base_u64)
    local text_id = tonumber(ffi.cast("uint32_t", read_u64(registers.rdi)))
    local resolved_text = clean_text(text)
    a11y.detect_ui_language(resolved_text)
    if caller_rva == 0xb22537 and resolved_text ~= "" then
        language_options[resolved_text] = true
    end
    local is_football_life_tooltip_part = false
    if text_id == 13107593 then
        football_life_tooltip_title = resolved_text
        is_football_life_tooltip_part = true
    elseif text_id == 13107596 then
        football_life_tooltip_description = resolved_text
        is_football_life_tooltip_part = true
    end
    if is_football_life_tooltip_part
            and football_life_tooltip_title
            and football_life_tooltip_description
            and current_main_menu_title
            and current_main_menu_title:find("Football Life", 1, true) then
        if a11y.read_tooltips then
            main_menu_tooltip = football_life_tooltip_title .. ". " ..
                football_life_tooltip_description
            main_menu_tooltip_due_ms =
                tonumber(ffi.C.GetTickCount64()) + 1000
        end
    end
    if controller_labels[resolved_text] then
        local label = resolved_text
        local row = controller_rows[label] or {}
        controller_rows[label] = row
        pending_controller_label = label
    end
    local controller_label = controller_tooltip_labels[text_id]
    if text_id == 13238441 then
        if active_controller_label == "Condição: Em casa" then
            controller_label = "Condição: Fora"
        else
            controller_label = "Condição: Em casa"
        end
    end
    if controller_label then
        active_controller_label = controller_label
        local row = controller_rows[controller_label]
        local value = controller_tooltip_values[text_id]
        if not value and row then
            value = row.value
        end
        announce_controller_row(controller_label, value)
        if a11y.read_tooltips then
            pending_controller_tooltip = clean_text(text)
            pending_controller_tooltip_label = controller_label
            controller_tooltip_due_ms = tonumber(ffi.C.GetTickCount64()) + 2000
        end
    end
    if caller_rva == 0xe4901d then
        local widget = read_u64(memory.read(saved_rsp + 72, 8))
        local spoken = clean_text(text)
        if widget >= 0x10000 and spoken ~= "" then
            local widget_key = memory.hex(widget)
            local previous_widget_text = standard_text_by_widget[widget_key]
            standard_text_by_widget[widget_key] = spoken
            local now_ms = tonumber(ffi.C.GetTickCount64())
            local is_game_plan_tactical_tooltip =
                a11y.game_plan_active
                and a11y.game_plan_active_tactical_label
                and frame - a11y.game_plan_active_tactical_frame <= 90
                and #spoken >= 35
                and not a11y.is_instruction_message(spoken)
                and not is_noninteractive_text(spoken)
            local is_active_tooltip = is_game_plan_tactical_tooltip
                or (not a11y.is_instruction_message(spoken)
                    and active_control_row
                    and active_control_row.label_widget
                    and widget ~= active_control_row.label_widget
                    and now_ms - active_control_focused_ms <= 5000
                    and #spoken >= 35
                    and not is_noninteractive_text(spoken))
            if previous_widget_text ~= spoken then
                announce_screen_title(spoken, widget_key)
                -- Help for the focused control is a tooltip, not a modal
                -- message. Keep it out of the message queue so disabling
                -- tooltip reading suppresses every route to speech.
                if not is_active_tooltip then
                    remember_message_text(spoken, widget_key)
                end
                if not queue_startup_text(spoken, now_ms)
                        and is_plain_text(spoken)
                        and not is_noninteractive_text(spoken) then
                    speak(spoken)
                end
            end
            if is_modal_button(spoken) then
                last_modal_button_frame = frame
                register_dialog_option(spoken, widget, widget_key)
                if spoken ~= "OK" or not instruction_message_locked then
                    queue_recent_message()
                end
            end
            if a11y.read_tooltips and #spoken >= 35 and not is_noninteractive_text(spoken) then
                latest_generic_tooltip = spoken
                latest_generic_tooltip_widget = widget
                latest_generic_tooltip_ms = now_ms
            end
            if a11y.read_tooltips and is_active_tooltip then
                pending_controller_tooltip = spoken
                pending_controller_tooltip_label =
                    is_game_plan_tactical_tooltip
                        and a11y.game_plan_active_tactical_label
                        or active_control_row.label
                active_controller_label = pending_controller_tooltip_label
                controller_tooltip_due_ms =
                    now_ms + (is_game_plan_tactical_tooltip and 350 or 2000)
            end
            if #spoken <= 60 and not audio_ids[text_id]
                    and not non_control_labels[spoken]
                    and not is_noninteractive_text(spoken)
                    and not is_splash_text(spoken)
                    and not looks_like_message(spoken)
                    and not is_active_tooltip then
                local candidate_row = register_control_label(
                    spoken,
                    widget,
                    selector_role(spoken),
                    controller_labels[spoken] or false)
                bind_delayed_speed_slider(candidate_row)
                pending_controller_label = candidate_row.label
            end
            if featured_initial_ids[text_id] then
                main_menu_title_widget_key = widget_key
            end
            local is_main_menu_title = main_menu_title_widget_key == widget_key
                and text_id >= 60948000 and text_id <= 60949000
            if is_main_menu_title and (previous_widget_text ~= spoken
                    or featured_initial_ids[text_id]) then
                local is_initial_featured = featured_initial_ids[text_id]
                    and previous_widget_text == nil
                reset_navigation_generation()
                startup_complete = true
                startup_completed_frame = frame
                main_menu_focus_guard_until = frame + 45
                current_main_menu_title = spoken
                -- Speak now for navigation and retain a short fallback for the
                -- first main-menu frame, which can arrive just before Windows
                -- reports the game as foreground. Duplicate suppression keeps
                -- this from speaking twice during ordinary navigation.
                dynamic_text_candidate = is_initial_featured
                    and nil or spoken .. ", item"
                dynamic_text_due_ms = is_initial_featured
                    and nil or tonumber(ffi.C.GetTickCount64()) + 250
                main_menu_tooltip = nil
                main_menu_tooltip_due_ms = nil
                log(string.format(
                    "[FLAccess] main-menu-title widget=%s previous=%q text=%q",
                    widget_key,
                    previous_widget_text or "",
                    spoken))
                if not is_initial_featured then
                    speak(spoken .. ", item")
                end
            elseif main_menu_title_widget_key
                    and text_id >= 13107000 and text_id <= 13108000 then
                if a11y.read_tooltips then
                    main_menu_tooltip = spoken
                    main_menu_tooltip_due_ms =
                        tonumber(ffi.C.GetTickCount64()) + 1000
                end
            end
            if frame - last_widget_frame > 12 and widget_count > 0 then
                trace_log(string.format(
                    "[FLAccess] widget-generation-gap gap=%d",
                    frame - last_widget_frame))
            end
            last_widget_frame = frame
            local previous = widgets[text_id]
            if not previous then
                widget_count = widget_count + 1
            end
            widgets[text_id] = {
                address = widget,
                text = spoken,
                last_seen = frame,
            }
            if audio_ids[text_id] then
                last_audio_id = text_id
            end
            if not previous or previous.address ~= widget then
                trace_log(string.format(
                    "[FLAccess] widget id=%u text=%q address=%s",
                    text_id,
                    spoken,
                    memory.hex(widget)))
            end
        end
    end

    local key = tostring(text_id) .. "\0" .. text
    if seen[key] then
        return
    end
    seen[key] = true
    unique_count = unique_count + 1
    if unique_count > 4000 then
        return
    end
    trace_log(string.format(
        "[FLAccess] resolved id=%u text=%q length=%d caller_rva=%s",
        text_id,
        text,
        length,
        memory.hex(caller_rva)))
end

local function scan_dialog_focus()
    local yes = dialog_options["Sim"]
    local no = dialog_options["Não"]
    if not yes or not no or yes.key == no.key
            or math.abs(yes.last_seen - no.last_seen) > 3
            or frame - math.max(yes.last_seen, no.last_seen) > 900 then
        return nil, nil
    end
    local function selected_at(offset)
        if not readable(yes.address + offset, 4)
                or not readable(no.address + offset, 4) then
            return nil
        end
        local yes_value = memory.unpack(
            "u32", memory.read(yes.address + offset, 4))
        local no_value = memory.unpack(
            "u32", memory.read(no.address + offset, 4))
        if yes_value == 1 and no_value ~= 1 then
            return "Sim"
        elseif no_value == 1 and yes_value ~= 1 then
            return "Não"
        end
        return nil
    end
    if dialog_preferred_offset then
        local selected = selected_at(dialog_preferred_offset)
        if selected then
            return selected, dialog_preferred_offset
        end
    end
    for _, offset in ipairs(dialog_focus_offsets) do
        local selected = selected_at(offset)
        if selected then
            return selected, offset
        end
    end
    return nil, nil
end

local function dialog_is_active()
    local yes = dialog_options["Sim"]
    local no = dialog_options["Não"]
    return yes and no and yes.key ~= no.key
        and math.abs(yes.last_seen - no.last_seen) <= 3
        and frame - math.max(yes.last_seen, no.last_seen) <= 900
end

function a11y.dismiss_dialog_for_focus(
        dialog_active, modal_focus_blocked, selected_entry, selected_activity)
    if not dialog_active or not selected_entry
            or is_modal_button(selected_entry.text) then
        return dialog_active, modal_focus_blocked, false
    end
    local yes = dialog_options["Sim"]
    local no = dialog_options["Não"]
    local last_button_seen = math.max(
        yes and yes.last_seen or -1,
        no and no.last_seen or -1)
    if not selected_activity or selected_activity <= last_button_seen + 3 then
        return dialog_active, modal_focus_blocked, false
    end

    -- Football Life leaves the old Sim/Não objects and their focus bits alive
    -- after closing this confirmation. A freshly activated non-button belongs
    -- to the destination screen and is the reliable dismissal signal.
    dialog_options = {}
    dialog_signature = nil
    dialog_preferred_offset = nil
    dialog_focus_candidate = nil
    dialog_focus_candidate_since = 0
    last_dialog_announcement = nil
    a11y.confirmation_dialog_until_frame = 0
    a11y.dialog_button_queued_for_message = false
    modal_focus_hold_until_ms = 0
    log(string.format(
        "[FLAccess] dialog-dismissed destination=%q",
        selected_entry.text))
    return false, false, true
end

local function process_dialog_focus(modal_focus_blocked, queue_after_message)
    if frame % 2 ~= 0
            or (modal_focus_blocked and not queue_after_message) then
        return
    end
    local dialog_selected, dialog_offset = scan_dialog_focus()
    local candidate = dialog_selected and
        (dialog_signature .. ":" .. dialog_selected) or nil
    if candidate ~= dialog_focus_candidate then
        dialog_focus_candidate = candidate
        dialog_focus_candidate_since = frame
    elseif candidate and frame - dialog_focus_candidate_since >= 4
            and candidate ~= last_dialog_announcement then
        last_dialog_announcement = candidate
        dialog_preferred_offset = dialog_offset
        log(string.format(
            "[FLAccess] dialog-focus offset=0x%x text=%q",
            dialog_offset,
            dialog_selected))
        local should_queue = queue_after_message
            and not a11y.dialog_button_queued_for_message
        speak(dialog_selected .. ", botão selecionado", not should_queue)
        if should_queue then
            a11y.dialog_button_queued_for_message = true
        end
    end
end

local function process_delayed_speech(now_ms, modal_focus_blocked)
    if a11y.read_tooltips and not modal_focus_blocked and controller_tooltip_due_ms
            and now_ms >= controller_tooltip_due_ms then
        local tooltip_key = (pending_controller_tooltip_label or "") .. "\0" ..
            (pending_controller_tooltip or "")
        if active_controller_label == pending_controller_tooltip_label
                and pending_controller_tooltip
                and pending_controller_tooltip ~= ""
                and tooltip_key ~= last_spoken_controller_tooltip_key then
            last_spoken_controller_tooltip_key = tooltip_key
            speak(pending_controller_tooltip, false)
        end
        controller_tooltip_due_ms = nil
    end
    if not modal_focus_blocked and dynamic_text_due_ms
            and now_ms >= dynamic_text_due_ms then
        if dynamic_text_candidate and dynamic_text_candidate ~= "" then
            speak(dynamic_text_candidate, false)
        end
        dynamic_text_candidate = nil
        dynamic_text_due_ms = nil
    end
    if a11y.read_tooltips and not modal_focus_blocked and main_menu_tooltip_due_ms
            and now_ms >= main_menu_tooltip_due_ms then
        if main_menu_tooltip and main_menu_tooltip ~= "" then
            speak(main_menu_tooltip, false)
        end
        main_menu_tooltip = nil
        main_menu_tooltip_due_ms = nil
    end
end

local function log_focus_snapshot(counts, selected, selected_seen)
    local parts = {}
    for index, count in ipairs(counts) do
        if count > 0 and selected[index] then
            local entry = ui_focus_widgets[selected[index]]
            if entry then
                parts[#parts + 1] = string.format(
                    "0x%x=%q(age=%d,candidates=%d)",
                    ui_focus_offsets[index],
                    entry.text,
                    frame - (selected_seen[index] or frame),
                    count)
            end
        end
    end
    log("[FLAccess] focus-snapshot " .. table.concat(parts, " "))
end

function a11y.diagnostic_role(widget_key, entry)
    local row = control_rows_by_label_widget[widget_key]
        or control_row_by_value_widget[widget_key]
    if row then
        if row.native_slider then
            return "slider", row
        end
        return row.role or "control", row
    end
    if is_modal_button(entry.text) then
        return "dialog-button", nil
    end
    if a11y.game_plan_title_widgets[widget_key]
            and a11y.game_plan_screen_titles[entry.text] then
        return "screen-title", nil
    end
    if widget_key == a11y.game_plan_active_tactical_widget then
        return "tactical-control-heading", nil
    end
    if widget_key == a11y.game_plan_selected_heading_widget then
        return "selected-player-heading", nil
    end
    if a11y.game_plan_menu_items[entry.text] then
        return "menu-item", nil
    end
    if a11y.pre_match_actions[entry.text] then
        return "pre-match-action", nil
    end
    if a11y.is_instruction_message(entry.text) then
        return "instruction-dialog-text", nil
    end
    if looks_like_message(entry.text) then
        return "message-or-tooltip", nil
    end
    if is_noninteractive_text(entry.text) then
        return "noninteractive-text", nil
    end
    return "unknown-focusable", nil
end

function a11y.record_focus(kind, widget_key, entry, selected_offset,
        counts, selected, selected_seen, dense_virtual_list)
    if not a11y.diagnostic_mode or not entry then
        return
    end
    a11y.diagnostic_sequence = a11y.diagnostic_sequence + 1
    local role, row = a11y.diagnostic_role(widget_key, entry)
    local lines = {
        string.format(
            "EVENT %d frame=%d kind=%s widget=%s offset=0x%x age=%d dense_list=%s role=%s",
            a11y.diagnostic_sequence,
            frame,
            tostring(kind or "stable-focus"),
            widget_key,
            selected_offset or 0,
            frame - (entry.last_seen or frame),
            dense_virtual_list and "true" or "false",
            a11y.diagnostic_text(role)),
        string.format("text=%q", a11y.diagnostic_text(entry.text)),
    }
    local caller_rva = a11y.ui_text_caller_by_widget[widget_key]
    lines[#lines + 1] = "text_set_caller_rva=" ..
        (caller_rva and string.format("0x%x", caller_rva) or "unknown")
    lines[#lines + 1] = string.format(
        "screen_context heading=%q main_menu=%q recent_message=%q",
        a11y.diagnostic_text(recent_heading_text),
        a11y.diagnostic_text(current_main_menu_title),
        a11y.diagnostic_text(recent_message_text))
    if row then
        lines[#lines + 1] = string.format(
            "control label=%q value=%q type=%q label_widget=%s value_widget=%s native_slider=%s min=%s max=%s",
            a11y.diagnostic_text(row.label),
            a11y.diagnostic_text(row.value),
            a11y.diagnostic_text(row.role),
            tostring(row.label_widget_key or "nil"),
            tostring(row.value_widget_key or "nil"),
            row.native_slider and "true" or "false",
            tostring(row.minimum or "nil"),
            tostring(row.maximum or "nil"))
    end

    local address = entry.address
    local raw = {}
    if address and readable(address, 0x40) then
        for offset = 0, 0x38, 8 do
            local value = read_u64(memory.read(address + offset, 8))
            raw[#raw + 1] = string.format(
                "+0x%02x=%s", offset, a11y.diagnostic_hex(value))
        end
        local vtable = read_u64(memory.read(address, 8))
        local vtable_key = a11y.diagnostic_hex(vtable)
        local class_id = a11y.diagnostic_class_ids[vtable_key]
        if not class_id then
            a11y.diagnostic_class_count = a11y.diagnostic_class_count + 1
            class_id = string.format(
                "class-%03d", a11y.diagnostic_class_count)
            a11y.diagnostic_class_ids[vtable_key] = class_id
        end
        local vtable_number = tonumber(vtable)
        local base_number = tonumber(process_base_u64)
        local rva = "outside-main-module"
        if vtable_number and base_number and vtable_number >= base_number
                and vtable_number < base_number + 0x40000000 then
            rva = string.format("0x%x", vtable_number - base_number)
        end
        lines[#lines + 1] = string.format(
            "object class=%s vtable=%s vtable_rva=%s raw_qwords={%s}",
            class_id,
            vtable_key,
            rva,
            table.concat(raw, ","))
    else
        lines[#lines + 1] = "object unreadable"
    end

    local focus_fields = {}
    for _, offset in ipairs(ui_focus_offsets) do
        local value = "unreadable"
        if address and readable(address + offset, 4) then
            value = tostring(memory.unpack(
                "u32", memory.read(address + offset, 4)))
        end
        focus_fields[#focus_fields + 1] = string.format(
            "+0x%x=%s", offset, value)
    end
    lines[#lines + 1] = "focus_fields={" ..
        table.concat(focus_fields, ",") .. "}"

    local banks = {}
    for index, count in ipairs(counts) do
        if count > 0 then
            local key = selected[index]
            local candidate = key and ui_focus_widgets[key] or nil
            banks[#banks + 1] = string.format(
                "+0x%x count=%d selected=%s text=%q age=%d",
                ui_focus_offsets[index],
                count,
                tostring(key or "nil"),
                a11y.diagnostic_text(candidate and candidate.text or ""),
                candidate and frame - (selected_seen[index] or frame) or -1)
        end
    end
    lines[#lines + 1] = "candidate_banks={" ..
        table.concat(banks, "; ") .. "}"

    local links = {}
    if address and readable(address, 0xf0) then
        for offset = 0, 0xe8, 8 do
            local pointer = read_u64(memory.read(address + offset, 8))
            local key = a11y.diagnostic_hex(pointer)
            local linked_text = ui_text_by_widget[key]
            if linked_text then
                links[#links + 1] = string.format(
                    "+0x%x=%s %q",
                    offset,
                    key,
                    a11y.diagnostic_text(linked_text))
                if #links >= 16 then
                    break
                end
            end
        end
    end
    lines[#lines + 1] = "known_widget_links={" ..
        table.concat(links, "; ") .. "}"

    local recent = {}
    for key, candidate in pairs(ui_focus_widgets) do
        local age = frame - (candidate.last_seen or frame)
        if age <= 120 then
            recent[#recent + 1] = {
                key = key,
                text = candidate.text,
                age = age,
            }
        end
    end
    table.sort(recent, function(left, right)
        if left.age == right.age then
            return left.key < right.key
        end
        return left.age < right.age
    end)
    local inventory = {}
    for index = 1, math.min(#recent, 40) do
        local candidate = recent[index]
        inventory[#inventory + 1] = string.format(
            "%s %q age=%d",
            candidate.key,
            a11y.diagnostic_text(candidate.text),
            candidate.age)
    end
    lines[#lines + 1] = string.format(
        "recent_screen_inventory count=%d shown=%d {%s}",
        #recent,
        #inventory,
        table.concat(inventory, "; "))

    local controls = {}
    for label, control in pairs(controller_rows) do
        controls[#controls + 1] = string.format(
            "%q type=%q value=%q label_widget=%s value_widget=%s created=%s value_frame=%s",
            a11y.diagnostic_text(label),
            a11y.diagnostic_text(control.role),
            a11y.diagnostic_text(control.value),
            tostring(control.label_widget_key or "nil"),
            tostring(control.value_widget_key or "nil"),
            tostring(control.created_frame or "nil"),
            tostring(control.value_frame or "nil"))
    end
    table.sort(controls)
    while #controls > 50 do
        table.remove(controls)
    end
    lines[#lines + 1] = "known_control_inventory={" ..
        table.concat(controls, "; ") .. "}"
    lines[#lines + 1] = ""
    a11y.diagnostic_write(lines)
end

function a11y.safe_record_focus(kind, selected_key, selected_entry,
        selected_offset, counts, selected, selected_seen, dense_virtual_list)
    -- Every memory access inside record_focus is guarded by readable().
    a11y.record_focus(
        kind,
        selected_key or "nil",
        selected_entry,
        selected_offset,
        counts,
        selected,
        selected_seen,
        dense_virtual_list)
end

function a11y.observe_diagnostic_focus(candidate_key, selected_key, selected_entry,
        selected_offset, counts, selected, selected_seen, dense_virtual_list)
    if not a11y.diagnostic_mode or not candidate_key or not selected_entry then
        return
    end
    local diagnostic_key = candidate_key .. ":" ..
        string.format("0x%x", selected_offset or 0)
    if diagnostic_key ~= a11y.diagnostic_candidate_key then
        a11y.diagnostic_candidate_key = diagnostic_key
        a11y.diagnostic_candidate_since = frame
        if frame - a11y.diagnostic_last_snapshot_frame >= 90 then
            a11y.diagnostic_last_snapshot_frame = frame
            a11y.safe_record_focus(
                "focus-snapshot",
                selected_key,
                selected_entry,
                selected_offset,
                counts,
                selected,
                selected_seen,
                dense_virtual_list)
        end
        return
    end
    if frame - a11y.diagnostic_candidate_since < 4
            or diagnostic_key == a11y.diagnostic_last_key then
        return
    end
    a11y.diagnostic_last_key = diagnostic_key
    a11y.safe_record_focus(
        "stable-focus",
        selected_key,
        selected_entry,
        selected_offset,
        counts,
        selected,
        selected_seen,
        dense_virtual_list)
end

local function scan_current_ui_focus(modal_focus_blocked, dialog_active)
    if ui_focus_widget_count <= 0 then
        return false
    end
    if frame < main_menu_focus_guard_until then
        return false
    end
    local counts = {}
    local selected = {}
    local selected_seen = {}
    for index = 1, #ui_focus_offsets do
        counts[index] = 0
        selected_seen[index] = -1
    end
    local game_plan_menu_bank_active = false
    for widget_key, entry in pairs(ui_focus_widgets) do
        if not is_noninteractive_text(entry.text)
                and readable(entry.address + 0xf0, 0x30) then
            local bytes = memory.read(entry.address + 0xf0, 0x30)
            local state = ui_focus_state[widget_key] or {}
            local activated = ui_focus_activated[widget_key] or {}
            ui_focus_state[widget_key] = state
            ui_focus_activated[widget_key] = activated
            for index, offset in ipairs(ui_focus_offsets) do
                local relative = offset - 0xf0
                local value = memory.unpack(
                    "u32", bytes:sub(relative + 1, relative + 4))
                if value == 1 and state[index] ~= 1 then
                    activated[index] = frame
                end
                state[index] = value
                if value == 1 then
                    if index == 5 and a11y.game_plan_active
                            and a11y.game_plan_menu_items[entry.text] then
                        game_plan_menu_bank_active = true
                    end
                    counts[index] = counts[index] + 1
                    local activity = math.max(
                        activated[index] or -1,
                        entry.last_seen or -1)
                    if activity > selected_seen[index] then
                        selected_seen[index] = activity
                        selected[index] = widget_key
                    end
                end
            end
        end
    end
    local selected_key
    local selected_offset
    local selected_offset_index
    local freshest_offset_index
    local freshest_seen = -1
    for index = 1, #ui_focus_offsets do
        if counts[index] > 0 and selected_seen[index] > freshest_seen then
            freshest_seen = selected_seen[index]
            freshest_offset_index = index
        end
    end
    -- League/club grids refresh several visible rows at 0x104 and 0x100.
    -- Prefer the freshest 0x100 row only while both banks belong to the same
    -- update cycle. Never lock a widget: recycled addresses caused stale
    -- leagues, players and pre-match items to leak into later screens.
    local dense_virtual_list = counts[1] >= 3 and counts[5] >= 3
    local game_plan_roster_offset_index = 10 -- 0xfc
    local primary_entry = selected[1] and ui_focus_widgets[selected[1]] or nil
    local context_entry = selected[5] and ui_focus_widgets[selected[5]] or nil
    local game_plan_roster_context = a11y.game_plan_active
        and a11y.game_plan_context
        and a11y.game_plan_edit_contexts[a11y.game_plan_context]
    local game_plan_settings_context = a11y.game_plan_active
        and game_plan_menu_bank_active
    local basic_settings_menu = a11y.game_plan_active
        and (a11y.game_plan_context == "Menu de configuração básica"
            or a11y.game_plan_context == "Basic Settings Menu")
    local edit_position_active = a11y.game_plan_active
        and (a11y.game_plan_context == "Escalação/Editar posição"
            or a11y.game_plan_context == "Team Sheet/Edit Position"
            or (frame - recent_heading_frame <= 120
                and (recent_heading_text == "Trocar ícone de jog."
                    or recent_heading_text == "Change Player Icon")))
    local recent_game_plan_player = edit_position_active
        and counts[game_plan_roster_offset_index] > 0
        and frame - selected_seen[game_plan_roster_offset_index] <= 30
    local game_plan_setting_offset_index
    local game_plan_setting_activation = -1
    local basic_menu_offset_index
    local basic_menu_activation = -1
    local game_plan_player_header_offset_index
    local game_plan_player_header_seen = -1
    if edit_position_active then
        for index = 1, #ui_focus_offsets do
            local entry = selected[index] and ui_focus_widgets[selected[index]] or nil
            if entry and entry.text:match("^%d+%s+%S")
                    and selected_seen[index] > game_plan_player_header_seen then
                game_plan_player_header_seen = selected_seen[index]
                game_plan_player_header_offset_index = index
            end
        end
    end
    if game_plan_settings_context then
        for index = 1, #ui_focus_offsets do
            local entry = selected[index] and ui_focus_widgets[selected[index]] or nil
            local activation = selected[index]
                and ui_focus_activated[selected[index]]
                and ui_focus_activated[selected[index]][index] or -1
            if entry and (a11y.game_plan_menu_items[entry.text]
                    or controller_labels[entry.text])
                    and activation > game_plan_setting_activation then
                game_plan_setting_activation = activation
                game_plan_setting_offset_index = index
            end
        end
    end
    if basic_settings_menu then
        for index = 1, #ui_focus_offsets do
            local entry = selected[index]
                and ui_focus_widgets[selected[index]] or nil
            local activation = selected[index]
                and ui_focus_activated[selected[index]]
                and ui_focus_activated[selected[index]][index] or -1
            if entry and not a11y.game_plan_title_widgets[selected[index]]
                    and (a11y.game_plan_menu_items[entry.text]
                    or a11y.game_plan_basic_prompt_items[entry.text])
                    and activation > basic_menu_activation then
                basic_menu_activation = activation
                basic_menu_offset_index = index
            end
        end
    end
    local primary_is_game_plan_control = primary_entry
        and (a11y.game_plan_menu_items[primary_entry.text]
            or a11y.game_plan_basic_prompt_items[primary_entry.text]
            or primary_entry.text:match("%(%s*[%d%-]+%s*%)")
            or primary_entry.text:match("^%d[%d%-]+$"))
    if basic_settings_menu then
        -- Team and player cards keep their focus flags behind this menu.
        -- Only its actual commands and Use/Do not use dialog are eligible.
        if basic_menu_offset_index
                and frame - basic_menu_activation <= 120 then
            selected_offset_index = basic_menu_offset_index
        else
            return false
        end
    elseif a11y.game_plan_active and primary_is_game_plan_control then
        -- Menus and formation lists expose the real selection at 0x104.
        -- Player cards at 0xfc keep animating behind them.
        selected_offset_index = 1
    elseif edit_position_active and game_plan_player_header_offset_index then
        -- The numbered heading is the only object tied to the selected
        -- footballer. The 0xfc bank contains every card being redrawn.
        selected_offset_index = game_plan_player_header_offset_index
    elseif edit_position_active then
        -- Silence is preferable to announcing a random background player
        -- while the selected-player heading is temporarily unavailable.
        return false
    elseif game_plan_settings_context then
        -- While this menu opens, 0x100 contains every visible entry and old
        -- players. A submenu may use a different bank, so prefer the control
        -- whose focus bit was most recently activated; fall back to 0x104.
        if game_plan_setting_offset_index
                and frame - game_plan_setting_activation <= 90 then
            selected_offset_index = game_plan_setting_offset_index
        elseif counts[1] > 0 then
            selected_offset_index = 1
        end
    elseif recent_game_plan_player then
        selected_offset_index = game_plan_roster_offset_index
    elseif dense_virtual_list then
        -- 0x104 is the actual selected row. 0x100 is the previous row: for
        -- example, while the game selects LaLiga 2 it still exposes LaLiga at
        -- 0x100. This applies to clubs and also avoids stale "Confirmar" rows.
        selected_offset_index = 1
    elseif counts[1] > 0 then
        -- Ordinary menus, pre-match actions and settings consistently expose
        -- their real selection at 0x104. Player names and hidden selectors on
        -- nearby offsets are refreshed continuously and otherwise steal the
        -- "freshest" heuristic even while their focus bits are stale.
        selected_offset_index = 1
    elseif ui_focus_preferred_offset_index
            and counts[ui_focus_preferred_offset_index] > 0 then
        selected_offset_index = ui_focus_preferred_offset_index
    elseif freshest_offset_index then
        selected_offset_index = freshest_offset_index
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if modal_focus_blocked or now_ms < modal_focus_hold_until_ms + 1500 then
        local freshest_button_seen = -1
        for index = 1, #ui_focus_offsets do
            local button_entry = selected[index]
                and ui_focus_widgets[selected[index]] or nil
            if button_entry and is_modal_button(button_entry.text)
                    and selected_seen[index] >= freshest_seen - 3
                    and selected_seen[index] > freshest_button_seen then
                freshest_button_seen = selected_seen[index]
                selected_offset_index = index
            end
        end
    end
    if selected_offset_index then
        selected_key = selected[selected_offset_index]
        selected_offset = ui_focus_offsets[selected_offset_index]
    end
    local selected_entry = selected_key and ui_focus_widgets[selected_key] or nil
    last_selected_ui_entry = selected_entry
    local preserved_pre_match_row = selected_key
        and control_rows_by_label_widget[selected_key] or nil
    if not (a11y.pre_match_active and preserved_pre_match_row
            and a11y.pre_match_actions[preserved_pre_match_row.label]) then
        preserved_pre_match_row = nil
    end
    local inferred_pre_match_text
    local selected_activity = selected_offset_index
        and selected_seen[selected_offset_index] or nil
    local recent_navigation = frame - a11y.navigation_frame <= 20
    if a11y.pre_match_active and not preserved_pre_match_row
            and selected_entry
            and not a11y.pre_match_actions[selected_entry.text]
            and selected_activity
            and ((recent_navigation
                    and ((a11y.navigation_action == "left"
                            and (a11y.pre_match_last_action == "Início"
                                or a11y.pre_match_last_action == "Kick Off"))
                        or (a11y.navigation_action == "right"
                            and (a11y.pre_match_last_action == "Uniforme"
                                or a11y.pre_match_last_action == "Uniform"))))
                or (frame - selected_activity > 30
                    and (a11y.pre_match_last_action == "Uniforme"
                        or a11y.pre_match_last_action == "Uniform"
                        or a11y.pre_match_last_action == "Início"
                        or a11y.pre_match_last_action == "Kick Off"
                        or a11y.pre_match_last_action == "Plano de jogo"
                        or a11y.pre_match_last_action == "Game Plan"))) then
        inferred_pre_match_text = a11y.ui_language == "pt"
            and "Estádio" or "Stadium"
    end
    local selected_focus_text = preserved_pre_match_row
        and preserved_pre_match_row.label
        or inferred_pre_match_text
        or (selected_entry and selected_entry.text or nil)
    local selected_formation_inside = selected_focus_text
        and selected_focus_text:match("%((.-)%)") or nil
    local selected_compact_formation = selected_formation_inside
        and selected_formation_inside:gsub("%s+", "") or nil
    local selected_is_formation = selected_focus_text and
        ((selected_compact_formation
                and selected_compact_formation:match("^%d[%d%-]+$"))
            or selected_focus_text:match("^%d[%d%-]+$"))
    if a11y.game_plan_active and selected_focus_text
            and a11y.game_plan_menu_items[selected_focus_text]
            and selected_activity and frame - selected_activity <= 12
            and not a11y.game_plan_edit_contexts[a11y.game_plan_context]
            and a11y.game_plan_context ~= "Configurações táticas básicas"
            and a11y.game_plan_context ~= "Basic Tactical Settings" then
        a11y.game_plan_last_menu_focus = selected_focus_text
    end
    if a11y.pre_match_active and selected_focus_text
            and not a11y.pre_match_actions[selected_focus_text]
            and not inferred_pre_match_text
            and not is_modal_button(selected_focus_text) then
        -- Game Plan widgets continue toggling focus bits behind pre-match.
        -- Ignore them without replacing the current candidate; otherwise the
        -- real horizontal action never survives the debounce interval.
        return false
    end
    if a11y.game_plan_main_surface and selected_focus_text
            and not a11y.game_plan_menu_items[selected_focus_text]
            and not is_modal_button(selected_focus_text) then
        -- Player names and both teams' formations are display-only on the
        -- overview. The five bottom commands are the only actionable focus.
        return false
    end
    if selected_focus_text
            and a11y.game_plan_basic_prompt_items[selected_focus_text]
            and not a11y.game_plan_basic_prompt_active then
        -- A closed Basic Settings prompt survives in the widget pool. Its
        -- stale focus flag used to say "Usar, selecionado" between players.
        return false
    end
    local candidate_key = selected_entry and (
        (dense_virtual_list and "virtual-list:" or selected_key .. ":") ..
        selected_focus_text) or nil
    local pre_match_action = selected_focus_text and a11y.pre_match_active
        and a11y.pre_match_actions[selected_focus_text] or false
    local dialog_dismissed
    dialog_active, modal_focus_blocked, dialog_dismissed =
        a11y.dismiss_dialog_for_focus(
            dialog_active,
            modal_focus_blocked,
            selected_entry,
            selected_activity)
    local fast_known_focus = selected_key
        and (control_rows_by_label_widget[selected_key]
            or control_row_by_value_widget[selected_key]
            or controller_labels[selected_focus_text]
            or a11y.fast_focus_items[selected_focus_text])
    local focus_debounce_frames = pre_match_action and 4
        or (game_plan_roster_context and selected_offset == 0xfc and 18)
        -- 0x104 is the verified active-focus bank on ordinary PES menus.
        -- Hidden widgets may retain bits elsewhere, but cannot enter this
        -- fast path unless the selection resolver chose this exact bank.
        or (selected_offset == 0x104 and 4)
        or (fast_known_focus and 4)
        or 12
    a11y.observe_diagnostic_focus(
        candidate_key,
        selected_key,
        selected_entry,
        selected_offset,
        counts,
        selected,
        selected_seen,
        dense_virtual_list)
    if edit_position_active and selected_focus_text
            and selected_focus_text:match("^%d+%s+%S") then
        -- Player headings are updated in place. Their dedicated delayed
        -- reader follows that update directly; the generic focus debounce
        -- would otherwise miss fast navigation or repeat the same player.
        return selected_entry ~= nil
    end
    local selected_is_modal_button = selected_entry
        and is_modal_button(selected_entry.text)
    local selected_is_known_control = selected_key
        and (control_rows_by_label_widget[selected_key]
            or control_row_by_value_widget[selected_key])
    local selected_is_startup_item = selected_is_modal_button
        or selected_is_known_control
        or (selected_entry and language_options[selected_entry.text])
    local changed_after_message = modal_focus_blocked
        and selected_offset_index
        and selected_seen[selected_offset_index] > modal_message_spoken_frame + 2
    -- Keep the initial item silent after an instructional paragraph. There is
    -- no reliable NVDA completion callback here. A real arrow movement changes
    -- the focus after the paragraph began and is announced immediately.
    if candidate_key and modal_focus_blocked and not changed_after_message
            and not pre_match_action then
        last_ui_focus_announcement = candidate_key
    end
    local startup_focus_allowed = selected_entry and (
        (startup_complete and frame - startup_completed_frame >= 12)
        or selected_is_startup_item)
    if dialog_dismissed and pre_match_action and startup_focus_allowed then
        a11y.pre_match_entry_pending = false
        a11y.pre_match_last_action = selected_focus_text
        last_ui_focus_announcement = candidate_key
        ui_focus_candidate_key = candidate_key
        ui_focus_candidate_since = frame
        if a11y.pre_match_notice_text then
            speak(a11y.pre_match_notice_text)
            speak(ui_focus_speech(selected_focus_text), false)
        else
            speak(ui_focus_speech(selected_focus_text))
        end
        return true
    end
    if a11y.pre_match_entry_pending and pre_match_action
            and startup_focus_allowed then
        if frame > a11y.pre_match_entry_guard_until_frame then
            a11y.pre_match_entry_pending = false
        elseif modal_message_spoken_frame == frame
                and pending_message_text == nil then
            a11y.pre_match_entry_pending = false
            a11y.pre_match_last_action = selected_focus_text
            last_ui_focus_announcement = candidate_key
            ui_focus_candidate_key = candidate_key
            ui_focus_candidate_since = frame
            speak(ui_focus_speech(selected_focus_text), false)
            return true
        else
            ui_focus_candidate_key = candidate_key
            ui_focus_candidate_since = frame
            return true
        end
    end
    if candidate_key ~= ui_focus_candidate_key then
        log_focus_snapshot(counts, selected, selected_seen)
        ui_focus_candidate_key = candidate_key
        ui_focus_candidate_since = frame
        local game_plan_menu_navigation = recent_navigation
            and a11y.game_plan_active
            and (((a11y.navigation_action == "up"
                        or a11y.navigation_action == "down")
                    and selected_is_formation
                    and (a11y.game_plan_context == "Alterar formação"
                        or a11y.game_plan_context == "Change Formation"))
                or (a11y.game_plan_menu_items[selected_focus_text]
                    and not a11y.game_plan_edit_contexts[
                        a11y.game_plan_context]
                    and a11y.game_plan_context ~=
                        "Configurações táticas básicas"
                    and a11y.game_plan_context ~=
                        "Basic Tactical Settings"
                    and not a11y.game_plan_formation_active))
        if game_plan_menu_navigation and startup_focus_allowed
                and candidate_key ~= last_ui_focus_announcement then
            -- Known Game Plan rows are authoritative and often exist for only
            -- one render frame between animated player-card refreshes.
            last_ui_focus_announcement = candidate_key
            ui_focus_preferred_offset_index = selected_offset_index
            local announcement = a11y.game_plan_focus_speech(
                selected_focus_text, selected_key)
            if announcement then speak(announcement) end
        elseif pre_match_action and startup_focus_allowed
                and (not dialog_active or selected_is_modal_button)
                and candidate_key ~= last_ui_focus_announcement then
            -- Pre-match recreates unrelated widgets continuously, resetting
            -- the generic debounce before it can finish. Its six known action
            -- strings already identify the selected command reliably.
            last_ui_focus_announcement = candidate_key
            ui_focus_preferred_offset_index = selected_offset_index
            a11y.pre_match_last_action = selected_focus_text
            speak(ui_focus_speech(selected_focus_text))
        end
    elseif candidate_key
            and frame - ui_focus_candidate_since >= focus_debounce_frames
            and (not modal_focus_blocked or changed_after_message
                or pre_match_action)
            and startup_focus_allowed
            and (not dense_virtual_list or a11y.game_plan_active
                or selected_is_startup_item)
            and (not dialog_active or selected_is_modal_button)
            and candidate_key ~= last_ui_focus_announcement then
        last_ui_focus_announcement = candidate_key
        if selected_key ~= main_menu_title_widget_key then
            dynamic_text_candidate = nil
            dynamic_text_due_ms = nil
            main_menu_tooltip = nil
            main_menu_tooltip_due_ms = nil
        end
        log(string.format(
            "[FLAccess] ui-focus offset=0x%x widget=%s text=%q",
            selected_offset,
            selected_key,
            selected_entry.text))
        ui_focus_preferred_offset_index = selected_offset_index
        local selected_control = control_rows_by_label_widget[selected_key]
            or (controller_labels[selected_entry.text]
                and controller_rows[selected_entry.text])
        if preserved_pre_match_row then
            selected_control = nil
        end
        if selected_control
                and selected_control.label ~= selected_entry.text then
            selected_control = nil
        end
        local selected_value_control =
            control_row_by_value_widget[selected_key]
        local stadium_control = selected_offset == 0x104
            and stadium_control_for_entry(selected_key, selected_entry) or nil
        local handled_control = false
        local now_ms = tonumber(ffi.C.GetTickCount64())
        local tactical_row
        if a11y.game_plan_active
                and (a11y.game_plan_context ==
                        "Configurações táticas básicas"
                    or a11y.game_plan_context ==
                        "Basic Tactical Settings")
                and a11y.game_plan_active_tactical_label
                and frame - a11y.game_plan_active_tactical_frame <= 90 then
            tactical_row = controller_rows[
                a11y.game_plan_active_tactical_label]
        end
        local formation_inside = selected_focus_text:match("%((.-)%)")
        local compact_formation = formation_inside
            and formation_inside:gsub("%s+", "") or nil
        local formation_context = a11y.game_plan_context == "Alterar formação"
            or a11y.game_plan_context == "Change Formation"
        local formation_text = a11y.game_plan_active and formation_context
            and ((compact_formation
                    and compact_formation:match("^%d[%d%-]+$"))
                or selected_focus_text:match("^%d[%d%-]+$"))
        if formation_text then
            a11y.game_plan_formation_active = true
        end
        if selected_control and selected_control.native_slider then
            active_control_row = selected_control
            active_controller_label = selected_control.label
            a11y.game_plan_active_tactical_label = selected_control.label
            a11y.game_plan_active_tactical_value = selected_control.value
            a11y.game_plan_active_tactical_frame = frame
            announce_control(selected_control)
            handled_control = true
        elseif tactical_row then
            -- A single live heading contains authoritative label and value.
            -- Ignore stale focus bits belonging to the other rendered rows.
            announce_control(tactical_row)
            handled_control = true
        elseif formation_text then
            local announcement = a11y.game_plan_focus_speech(
                selected_focus_text,
                selected_key)
            if announcement then
                speak(announcement)
            end
            handled_control = true
        elseif a11y.game_plan_formation_active then
            -- Formation lists redraw player names and old tactical values in
            -- the same focus banks. Only the formation row is interactive.
            handled_control = true
        elseif a11y.game_plan_active
                and not a11y.game_plan_edit_contexts[a11y.game_plan_context]
                and a11y.game_plan_context ~= "Configurações táticas básicas"
                and a11y.game_plan_context ~= "Basic Tactical Settings"
                and a11y.game_plan_menu_items[selected_focus_text] then
            local announcement = a11y.game_plan_focus_speech(
                selected_focus_text,
                selected_key)
            if announcement then
                speak(announcement)
            end
            handled_control = true
        elseif stadium_control then
            if active_control_row == stadium_control then
                announce_control_value(stadium_control, selected_entry.text)
            else
                announce_control(stadium_control)
            end
            handled_control = true
        elseif focused_control_hint
                and now_ms - focused_control_hint_ms <= 1500
                and selected_entry.text ~= focused_control_hint then
            local hinted_row = controller_rows[focused_control_hint] or {
                label = focused_control_hint,
                role = "seletor",
                label_widget_key = "hint:" .. focused_control_hint,
                is_control = true,
            }
            hinted_row.value = selected_entry.text
            controller_rows[focused_control_hint] = hinted_row
            announce_control(hinted_row)
            focused_control_hint = nil
            handled_control = true
        elseif selected_control and selected_control.is_control then
            announce_control(selected_control)
            handled_control = true
        elseif selected_value_control and selected_value_control.is_control then
            announce_control_value(
                selected_value_control,
                selected_entry.text)
            handled_control = true
        elseif active_control_row
                and not active_control_row.native_slider
                and not active_control_row.external_value
                and not a11y.game_plan_active
                and now_ms - active_control_focused_ms <= 500
                and selected_entry.address ~= active_control_row.label_widget
                and not control_rows_by_label_widget[selected_key] then
            attach_control_value(
                active_control_row,
                selected_entry.address,
                selected_entry.text)
            announce_control_value(active_control_row, selected_entry.text)
            handled_control = true
        end
        if not handled_control then
            if side_user(selected_entry.text) then
                local user = selected_entry.text
                -- The visible side labels retain stale state bits. The three
                -- focused Usuário widgets, discovered in order, are reliable.
                begin_side_screen(nil, selected_key, user)
            elseif side_screen_active
                    and (selected_entry.text == "Modificar ajustes pessoais"
                        or selected_entry.text == "Informações") then
                log(string.format(
                    "[FLAccess] side-auxiliary-suppressed text=%q",
                    selected_entry.text))
            else
                end_side_screen()
                if pre_match_action then
                    a11y.pre_match_last_action = selected_focus_text
                end
                local announcement = a11y.game_plan_focus_speech(
                    selected_focus_text,
                    selected_key)
                if announcement then
                    speak(announcement)
                end
                if changed_after_message then
                    modal_focus_hold_until_ms = 0
                end
            end
        end
    end
    return selected_entry ~= nil
end

local function scan_legacy_widget_focus(modal_focus_blocked, dialog_active)
    if modal_focus_blocked or dialog_active or not startup_complete
            or frame - startup_completed_frame < 12 or frame % 3 ~= 0 then
        return
    end
    local focused_id
    local focused_seen = -1
    for text_id, entry in pairs(widgets) do
        if is_focused(text_id) and (entry.last_seen or 0) > focused_seen then
            focused_id = text_id
            focused_seen = entry.last_seen or 0
        end
    end
    if focused_id ~= focus_candidate_id then
        focus_candidate_id = focused_id
        focus_candidate_since = frame
    elseif focused_id and frame - focus_candidate_since >= 12 then
        local entry = widgets[focused_id]
        local focus_key = entry and
            (tostring(focused_id) .. ":" .. memory.hex(entry.address)) or nil
        if focus_key and focus_key ~= last_announced_focus_key then
            last_announced_focus_key = focus_key
            last_focused_id = focused_id
            local control = entry and control_rows_by_label_widget[
                memory.hex(entry.address)] or nil
            if control and control.label == entry.text and control.is_control then
                active_controller_label = control.label
                announce_control(control)
            elseif entry and not controller_labels[entry.text]
                    and memory.hex(entry.address) ~= main_menu_title_widget_key then
                active_controller_label = nil
                active_control_row = nil
                pending_controller_tooltip = nil
                pending_controller_tooltip_label = nil
                controller_tooltip_due_ms = nil
                speak(spoken_row(focused_id))
            end
        end
    end
end

function m.display_frame(ctx)
    frame = frame + 1
    a11y.current_frame = frame
    a11y.poll_direct_message_update()
    if not prism_started and frame >= 120 then
        prism_started = true
        start_native_prism(ctx)
    end
    if prism_started then
        a11y.flush_native_speech(tonumber(ffi.C.GetTickCount64()))
    end
    if not game_is_foreground() then
        game_was_foreground = false
        return
    end
    if not game_was_foreground then
        game_was_foreground = true
        foreground_resume_frame = frame + 4
        ui_focus_candidate_key = nil
        last_ui_focus_announcement = nil
        focus_candidate_id = nil
        last_announced_focus_key = nil
        return
    end
    if frame < foreground_resume_frame then
        return
    end
    if overlay_visible or sider_overlay_visible then
        return
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    a11y.poll_attribute_input(now_ms)
    if a11y.game_plan_lineup_due_ms
            and now_ms >= a11y.game_plan_lineup_due_ms then
        a11y.read_visible_game_plan_lineup()
        a11y.game_plan_lineup_due_ms = nil
        a11y.game_plan_lineup_input = nil
        if prism_started then
            a11y.flush_native_speech(tonumber(ffi.C.GetTickCount64()))
        end
    end
    local startup_busy = process_startup_speech(now_ms)
    if not startup_busy and pending_message_due_ms
            and now_ms >= pending_message_due_ms then
        if pending_message_text and pending_message_text ~= ""
                and pending_message_key ~= last_announced_message_key then
            speak(pending_message_text)
            a11y.dialog_button_queued_for_message = false
            modal_message_spoken_frame = frame
            last_announced_message_key = pending_message_key
            local reading_time = #pending_message_text * 65 + 500
            if reading_time < 1800 then reading_time = 1800 end
            if reading_time > 10000 then reading_time = 10000 end
            modal_focus_hold_until_ms = now_ms + reading_time
        end
        pending_message_text = nil
        pending_message_key = nil
        pending_message_due_ms = nil
    end
    -- Startup and dialog work above can enqueue speech before later guards
    -- return early. Deliver it now instead of paying another render frame.
    if prism_started then
        a11y.flush_native_speech(now_ms)
    end
    if a11y.game_plan_attribute_due_ms then
        if not startup_busy and pending_message_text == nil
                and now_ms >= a11y.game_plan_attribute_due_ms then
            local attribute_summary = a11y.game_plan_attribute_summary()
            speak(attribute_summary)
            a11y.game_plan_attribute_due_ms = nil
            local attribute_reading_time = #attribute_summary * 55 + 500
            if attribute_reading_time < 2500 then
                attribute_reading_time = 2500
            end
            if attribute_reading_time > 9000 then
                attribute_reading_time = 9000
            end
            a11y.game_plan_attribute_hold_until_ms =
                now_ms + attribute_reading_time
            if prism_started then
                a11y.flush_native_speech(
                    tonumber(ffi.C.GetTickCount64()))
            end
        end
        return
    end
    if now_ms < a11y.game_plan_attribute_hold_until_ms then
        return
    end
    if now_ms <= a11y.game_plan_attribute_panel_until_ms then
        -- The game renders every player card while the attribute overlay is
        -- open. None of those background names represents a focus change.
        return
    end
    local modal_focus_blocked = startup_busy
        or pending_message_text ~= nil
        or now_ms < modal_focus_hold_until_ms
    local dialog_active = frame <= a11y.confirmation_dialog_until_frame
        and dialog_is_active() or false
    a11y.process_game_plan_selected_heading(
        modal_focus_blocked or dialog_active)
    a11y.process_game_plan_basic_menu_heading(
        modal_focus_blocked or dialog_active)
    -- The specialized reader is enabled only by the current destructive-back
    -- confirmation. This reads its Sim/Não focus without allowing old dialog
    -- widgets to compete with later screens.
    if dialog_active then
        process_dialog_focus(
            modal_focus_blocked,
            now_ms < modal_focus_hold_until_ms)
    end
    -- Do not mix the current UI-state reader with the legacy localization
    -- fallback. Hidden widgets retain their old focus bit after a transition,
    -- so the fallback can overwrite a correct announcement with an item from
    -- the previous screen (for example "Partida local" on the league list).
    scan_current_ui_focus(modal_focus_blocked, dialog_active)

    -- Delayed speech is evaluated after focus. A newly focused item can then
    -- cancel an obsolete tooltip before it reaches the screen reader.
    process_delayed_speech(now_ms, modal_focus_blocked)
    -- Hooks and focus scanning enqueue only. Flush again after processing so
    -- confirmed navigation reaches Prism in this render frame rather than the
    -- next one. Prism calls remain serialized on display_frame.
    if prism_started then
        a11y.flush_native_speech(tonumber(ffi.C.GetTickCount64()))
    end
end

function a11y.overlay_text()
    local s = a11y.strings()
    local tooltip = string.format(
        s.tooltip_option,
        a11y.read_tooltips and s.yes or s.no)
    local diagnostic = string.format(
        s.diagnostic_option,
        a11y.diagnostic_mode and s.yes or s.no)
    if a11y.selected_option == 1 then
        tooltip = "---> " .. tooltip .. " <---"
    else
        diagnostic = "---> " .. diagnostic .. " <---"
    end
    return table.concat({
        string.format(s.title, VERSION),
        s.menu_reading,
        s.speech_output,
        tooltip,
        diagnostic,
        "",
        s.navigate_options,
        s.change_option,
        s.restore_defaults,
        s.close_sider,
        s.next_module,
        s.previous_module,
    }, "\n")
end

function a11y.selected_option_text()
    local s = a11y.strings()
    if a11y.selected_option == 2 then
        return string.format(
            s.diagnostic_option,
            a11y.diagnostic_mode and s.yes or s.no)
    end
    return string.format(
        s.tooltip_option,
        a11y.read_tooltips and s.yes or s.no)
end

function m.overlay_on(ctx)
    return a11y.overlay_text()
end

function m.show(ctx)
    overlay_visible = true
    pending_message_text = nil
    pending_message_key = nil
    pending_message_due_ms = nil
    a11y.clear_pending_tooltips()
    dynamic_text_candidate = nil
    dynamic_text_due_ms = nil
    local s = a11y.strings()
    speak(string.format(
        s.opened,
        VERSION,
        a11y.selected_option_text()))
end

function m.hide(ctx)
    overlay_visible = false
    sider_overlay_visible = false
end

function m.global_key_down(ctx, vkey)
    if vkey == 0x49 then -- I: previous attribute
        a11y.read_game_plan_attribute(-1)
    elseif vkey == 0x4b then -- K: next attribute
        a11y.read_game_plan_attribute(1)
    end
end

function m.global_gamepad_input(ctx, inputs)
    local vertical = inputs and inputs.RSy
    if vertical == 1 then
        a11y.read_game_plan_attribute(-1)
    elseif vertical == -1 then
        a11y.read_game_plan_attribute(1)
    end
end

function m.key_down(ctx, vkey)
    local s = a11y.strings()
    if vkey == 0x20 then
        overlay_visible = false
        sider_overlay_visible = false
        return
    end
    if vkey == a11y.previous_option_key then
        a11y.selected_option = a11y.selected_option - 1
        if a11y.selected_option < 1 then
            a11y.selected_option = a11y.option_count
        end
        speak(a11y.selected_option_text())
        return
    elseif vkey == a11y.next_option_key then
        a11y.selected_option = a11y.selected_option + 1
        if a11y.selected_option > a11y.option_count then
            a11y.selected_option = 1
        end
        speak(a11y.selected_option_text())
        return
    end
    if vkey ~= a11y.restore_key
            and vkey ~= a11y.previous_value_key
            and vkey ~= a11y.next_value_key then
        return
    end

    if a11y.selected_option == 2 then
        local enabled = vkey == a11y.restore_key
            and false or not a11y.diagnostic_mode
        if not a11y.set_diagnostic(enabled, "Sider panel") then
            speak(s.diagnostic_failed)
            return
        end
        speak(string.format(
            s.diagnostic_changed,
            a11y.diagnostic_mode and s.yes or s.no))
        if a11y.diagnostic_mode then
            speak(s.diagnostic_file)
        end
        return
    end

    a11y.read_tooltips = vkey == a11y.restore_key
        and true or not a11y.read_tooltips
    if not a11y.read_tooltips then
        a11y.clear_pending_tooltips()
    end
    a11y.save_config()
    speak(string.format(
        s.tooltip_changed,
        a11y.read_tooltips and s.yes or s.no))
end

function a11y.readable_sider_module(module_name)
    return tostring(module_name or a11y.strings().module)
        :gsub("[\\/]", " ")
        :gsub("%.lua$", "")
        :gsub("[_%-]+", " ")
end

function a11y.overlay_lines(text)
    local result = {}
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            result[#result + 1] = line
        end
    end
    return result
end

function a11y.clean_overlay_line(line)
    return tostring(line or "")
        :gsub("^%-%-%->%s*", "")
        :gsub("%s*<%-%-%-$", "")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

function a11y.selected_overlay_line(text)
    for _, line in ipairs(a11y.overlay_lines(text)) do
        if line:find("--->", 1, true) then
            return a11y.clean_overlay_line(line)
        end
    end
    return nil
end

function a11y.is_static_overlay_instruction(line)
    local lower = line:lower()
    return lower:match("^version%s") ~= nil
        or lower:match("^keys:") ~= nil
        or lower:match("^gamepad:") ~= nil
        or lower:match("^press%s") ~= nil
        or lower:match("commands:$") ~= nil
        or lower:find("subcommands:", 1, true) ~= nil
        or lower:find("to manually select", 1, true) ~= nil
        or lower:find("to set current", 1, true) ~= nil
        or lower:find("to use your favorite", 1, true) ~= nil
end

function a11y.changed_overlay_text(previous, current)
    local previous_selected = a11y.selected_overlay_line(previous)
    local current_selected = a11y.selected_overlay_line(current)
    if current_selected and current_selected ~= previous_selected then
        return current_selected
    end

    local old_counts = {}
    for _, line in ipairs(a11y.overlay_lines(previous)) do
        local clean = a11y.clean_overlay_line(line)
        old_counts[clean] = (old_counts[clean] or 0) + 1
    end
    local changed = {}
    for _, line in ipairs(a11y.overlay_lines(current)) do
        local clean = a11y.clean_overlay_line(line)
        if old_counts[clean] and old_counts[clean] > 0 then
            old_counts[clean] = old_counts[clean] - 1
        elseif clean ~= "" and not a11y.is_static_overlay_instruction(clean) then
            changed[#changed + 1] = clean
        end
    end
    if #changed == 0 then
        return current_selected
    end
    while #changed > 3 do
        table.remove(changed, 1)
    end
    return table.concat(changed, ". ")
end

function a11y.full_overlay_text(text)
    local lines = a11y.overlay_lines(text)
    for index, line in ipairs(lines) do
        lines[index] = a11y.clean_overlay_line(line)
    end
    return table.concat(lines, ". ")
end

function m.on_sider_overlay_content(ctx, module_name, text, visible)
    sider_overlay_visible = visible == true
    if not visible then
        overlay_visible = false
        a11y.last_sider_overlay_module = nil
        speak(a11y.strings().closed)
        return
    end

    -- Our own panel is already announced by m.show, which also preserves
    -- compatibility with an unmodified Sider.
    if module_name == "FLAccess.lua" then
        a11y.sider_overlay_text_by_module[module_name] = text
        a11y.last_sider_overlay_module = module_name
        return
    end
    local source = tostring(module_name or "")
    local previous = a11y.sider_overlay_text_by_module[source]
    local module_changed = source ~= a11y.last_sider_overlay_module
    local announcement
    if previous == nil then
        announcement = a11y.full_overlay_text(text)
    elseif previous ~= text then
        announcement = a11y.changed_overlay_text(previous, text)
    elseif module_changed then
        announcement = a11y.selected_overlay_line(text)
    end
    a11y.sider_overlay_text_by_module[source] = text
    a11y.last_sider_overlay_module = source

    local prefix = module_changed
        and (a11y.strings().sider .. ". " .. a11y.readable_sider_module(source)) or nil
    if prefix and announcement and announcement ~= "" then
        speak(prefix .. ". " .. announcement)
    elseif prefix then
        speak(prefix)
    elseif announcement and announcement ~= "" then
        speak(announcement)
    end
end

function a11y.reset_widget_tracking_state()
    widgets = {}
    widget_count = 0
    slider_rows = {}
    slider_values = {}
    unmapped_sliders = {}
    ui_text_by_widget = {}
    ui_focus_widgets = {}
    ui_focus_widget_count = 0
    ui_focus_state = {}
    ui_focus_activated = {}
    last_ui_text_ms = 0
    ui_focus_candidate_key = nil
    ui_focus_candidate_since = 0
    last_ui_focus_announcement = nil
    ui_focus_preferred_offset_index = nil
    last_selected_ui_entry = nil
end

function a11y.reset_dialog_and_message_state()
    dialog_options = {}
    dialog_signature = nil
    dialog_preferred_offset = nil
    dialog_focus_candidate = nil
    dialog_focus_candidate_since = 0
    last_dialog_announcement = nil
    reset_message_state()
end

function a11y.reset_menu_tracking_state()
    standard_text_by_widget = {}
    dynamic_text_candidate = nil
    dynamic_text_due_ms = nil
    main_menu_title_widget_key = nil
    current_main_menu_title = nil
    main_menu_tooltip = nil
    main_menu_tooltip_due_ms = nil
    main_menu_focus_guard_until = 0
    last_screen_title_key = nil
    football_life_tooltip_title = nil
    football_life_tooltip_description = nil
end

function a11y.reset_control_tracking_state()
    controller_rows = {}
    control_rows_by_label_widget = {}
    control_row_by_value_widget = {}
    pending_control_row = nil
    active_control_row = nil
    active_control_focused_ms = 0
    pending_controller_label = nil
    active_controller_label = nil
    last_controller_announcement = nil
    last_announced_control_row = nil
    last_announced_selector_label = nil
    pending_controller_tooltip = nil
    pending_controller_tooltip_label = nil
    controller_tooltip_due_ms = nil
    last_spoken_controller_tooltip_key = nil
    latest_generic_tooltip = nil
    latest_generic_tooltip_widget = nil
    latest_generic_tooltip_ms = 0
    language_control_by_controller = {}
end

function a11y.reset_selection_tracking_state()
    last_audio_id = nil
    last_focused_id = nil
    focus_candidate_id = nil
    last_announced_focus_key = nil
end

function m.context_reset(ctx)
    a11y.reset_widget_tracking_state()
    a11y.reset_dialog_and_message_state()
    a11y.reset_menu_tracking_state()
    a11y.reset_control_tracking_state()
    a11y.reset_selection_tracking_state()
    a11y.pre_match_active = false
    a11y.game_plan_active = false
    a11y.game_plan_main_surface = false
    a11y.game_plan_context = nil
    a11y.game_plan_announced_context = nil
    a11y.game_plan_last_focus_text = nil
    a11y.game_plan_last_menu_focus = nil
    a11y.game_plan_attribute_due_ms = nil
    a11y.game_plan_attribute_hold_until_ms = 0
    a11y.game_plan_attribute_last_marker_frame = -10000
    a11y.game_plan_attribute_panel_until_ms = 0
    a11y.game_plan_attribute_index = 0
    a11y.game_plan_attribute_items = {}
    a11y.game_plan_attribute_text_events = {}
    a11y.game_plan_player_record = nil
    a11y.game_plan_player_name = nil
    a11y.game_plan_player_attributes = {}
    a11y.game_plan_player_cache = {}
    a11y.game_plan_attribute_locked_name = nil
    a11y.game_plan_attribute_opened_ms = 0
    a11y.game_plan_last_focus_widget = nil
    a11y.game_plan_last_focus_frame = -10000
    a11y.game_plan_pending_title = nil
    a11y.game_plan_title_widgets = {}
    a11y.game_plan_basic_menu_heading_widget = nil
    a11y.game_plan_basic_menu_heading_text = nil
    a11y.game_plan_basic_menu_heading_due_frame = nil
    a11y.game_plan_lineup_due_ms = nil
    a11y.game_plan_lineup_input = nil
    a11y.game_plan_lineup_generation_frame = -10000
    a11y.game_plan_observed_lineup = {}
    a11y.lineup_keyboard_o_down = false
    a11y.lineup_right_stick_x = 0
    a11y.game_plan_selected_heading = nil
    a11y.game_plan_selected_heading_widget = nil
    a11y.game_plan_selected_heading_frame = -10000
    a11y.game_plan_selected_heading_due_frame = nil
    a11y.game_plan_last_announced_heading = nil
    a11y.game_plan_last_player_section = nil
    a11y.game_plan_basic_prompt_active = false
    a11y.game_plan_active_tactical_label = nil
    a11y.game_plan_active_tactical_value = nil
    a11y.game_plan_active_tactical_widget = nil
    a11y.game_plan_active_tactical_frame = -10000
    a11y.game_plan_tactical_navigation_frame = -10000
    a11y.navigation_frame = -10000
    a11y.navigation_action = nil
    a11y.game_plan_formation_active = false
    a11y.ui_string_object_by_widget = {}
    a11y.stadium_active = false
    a11y.stadium_last_marker_frame = -10000
    reset_stadium_screen()
    a11y.pre_match_notice_text = nil
    a11y.pre_match_entry_pending = false
    a11y.pre_match_entry_guard_until_frame = 0
    a11y.pre_match_last_action = nil
    reset_side_state()
    last_widget_frame = frame
    log("[FLAccess] context-reset")
end

local function install_probe(ctx)
    local target = process_base + RESOLVED_TEXT_RVA
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[FLAccess] probe=%s reused-existing-hook target=%s",
            VERSION,
            memory.hex(target)))
        return
    end
    memory.guard(target, #ORIGINAL_PROLOGUE, "b", ORIGINAL_PROLOGUE)

    local event_id = ctx.get_event_id("custom:flaccess_resolved_text")
    local codecave = memory.allocate_codecave(96)
    local resume = target + #ORIGINAL_PROLOGUE

    local event_trigger =
        "\x53" ..
        "\x51" ..
        "\x48\xbb" .. memory.pack("u64", ctx.custom_evt_rbx) ..
        "\x66\xb9" .. memory.pack("u16", event_id) ..
        "\xff\xd3" ..
        "\x48\x83\xc4\x10"

    local return_to_game =
        ORIGINAL_PROLOGUE ..
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", resume)

    memory.write(codecave, event_trigger .. return_to_game)
    memory.write(
        target,
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", codecave) .. "\x90")

    log(string.format(
        "[FLAccess] probe=%s target=%s codecave=%s mode=resolved-text",
        VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

local function install_event_probe(ctx, rva, prologue, event_name, label)
    local target = process_base + rva
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[FLAccess] %s=%s reused-existing-hook target=%s",
            label,
            VERSION,
            memory.hex(target)))
        return
    end
    memory.guard(target, #prologue, "b", prologue)

    local event_id = ctx.get_event_id(event_name)
    local codecave = memory.allocate_codecave(96)
    local resume = target + #prologue
    local event_trigger =
        "\x53" ..
        "\x51" ..
        "\x48\xbb" .. memory.pack("u64", ctx.custom_evt_rbx) ..
        "\x66\xb9" .. memory.pack("u16", event_id) ..
        "\xff\xd3" ..
        "\x48\x83\xc4\x10"
    local return_to_game =
        prologue ..
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", resume)

    memory.write(codecave, event_trigger .. return_to_game)
    if #prologue < 14 then
        error(label .. " prologue is too short for an absolute jump")
    end
    memory.write(
        target,
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", codecave) ..
            string.rep("\x90", #prologue - 14))
    log(string.format(
        "[FLAccess] %s=%s target=%s codecave=%s",
        label,
        VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

local function install_slider_probes(ctx)
    install_event_probe(
        ctx, SLIDER_INIT_RVA, SLIDER_INIT_PROLOGUE,
        "custom:flaccess_slider_init", "slider-init-probe")
    install_event_probe(
        ctx, SLIDER_SET_RVA, SLIDER_SET_PROLOGUE,
        "custom:flaccess_slider_set", "slider-set-probe")
end

local function install_selector_probes(ctx)
    install_event_probe(
        ctx, UI_TEXT_SET_RVA, UI_TEXT_SET_PROLOGUE,
        "custom:flaccess_ui_text_set", "ui-text-set-probe")
    install_event_probe(
        ctx, GAME_TEXT_LANGUAGE_SET_RVA, LANGUAGE_SET_PROLOGUE,
        "custom:flaccess_game_text_language_set", "game-text-language-probe")
    install_event_probe(
        ctx, COMMENTARY_LANGUAGE_SET_RVA, LANGUAGE_SET_PROLOGUE,
        "custom:flaccess_commentary_language_set", "commentary-language-probe")
    install_event_probe(
        ctx, GAME_TEXT_LANGUAGE_NAV_RVA, LANGUAGE_NAV_PROLOGUE,
        "custom:flaccess_game_text_language_nav", "game-text-language-nav-probe")
end

local function install_list_probe(ctx)
    install_event_probe(
        ctx, LIST_ITEM_RENDER_RVA, LIST_ITEM_RENDER_PROLOGUE,
        "custom:flaccess_list_item_render", "list-item-render-probe")
    install_event_probe(
        ctx, TEAM_ITEM_TEXT_A_RVA, TEAM_ITEM_TEXT_PROLOGUE,
        "custom:flaccess_team_item_text", "team-item-text-a-probe")
    install_event_probe(
        ctx, TEAM_ITEM_TEXT_B_RVA, TEAM_ITEM_TEXT_PROLOGUE,
        "custom:flaccess_team_item_text", "team-item-text-b-probe")
end

function a11y.install_player_record_probes(ctx)
    install_event_probe(
        ctx, 0xc6d770,
        "\x0f\x10\x02\x0f\x11\x01\x0f\x10\x4a\x10\x0f\x11\x49\x10",
        "custom:flaccess_player_record_copy", "player-record-copy-probe")
    install_event_probe(
        ctx, 0x8e1e47,
        "\x48\x8b\x40\x2c\x48\x89\x02\x48\x8b\xc2\xc3\xcc\xcc\xcc",
        "custom:flaccess_player_record_lookup", "player-record-lookup-probe")
end


function m.init(ctx)
    if not ctx.custom_evt_rbx then
        error("Sider custom events are unavailable")
    end
    process_base = memory.get_process_info().base
    process_base_u64 = ffi.cast("uint64_t", process_base)
    a11y.sider_dir = ctx.sider_dir
    local xinput_file = io.open(ctx.sider_dir .. "\\..\\xinput1_3.dll", "rb")
    if xinput_file then
        xinput_file:close()
        a11y.xinput = ffi.load("xinput1_3")
        a11y.xinput_state = ffi.new("FLACCESS_XINPUT_STATE[1]")
    end
    a11y.config_path = ctx.sider_dir .. "\\modules\\FLAccess.ini"
    a11y.diagnostic_path = ctx.sider_dir .. "\\FLAccess-diagnostic.log"
    a11y.diagnostic_mode = false
    if not a11y.load_config() then
        a11y.save_config()
    end
    ctx.register("custom:flaccess_resolved_text", m.on_resolved_text)
    ctx.register("custom:flaccess_slider_init", m.on_slider_init)
    ctx.register("custom:flaccess_slider_set", m.on_slider_set)
    ctx.register("custom:flaccess_ui_text_set", m.on_ui_text_set)
    ctx.register("custom:flaccess_list_item_render", m.on_list_item_render)
    ctx.register("custom:flaccess_team_item_text", m.on_team_item_text)
    ctx.register("custom:flaccess_game_text_language_set", m.on_game_text_language_set)
    ctx.register("custom:flaccess_commentary_language_set", m.on_commentary_language_set)
    ctx.register("custom:flaccess_game_text_language_nav", m.on_game_text_language_nav)
    ctx.register("custom:flaccess_player_record_copy", m.on_player_record_copy)
    ctx.register("custom:flaccess_player_record_lookup", m.on_player_record_lookup)
    ctx.register("display_frame", m.display_frame)
    ctx.register("context_reset", m.context_reset)
    ctx.register("overlay_on", m.overlay_on)
    ctx.register("overlay_content", m.on_sider_overlay_content)
    ctx.register("key_down", m.key_down)
    ctx.register("show", m.show)
    ctx.register("hide", m.hide)
    install_probe(ctx)
    install_slider_probes(ctx)
    install_selector_probes(ctx)
    install_list_probe(ctx)
    a11y.install_player_record_probes(ctx)
end

return m
