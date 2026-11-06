-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 0, "FLAccess reader: missing or reordered component bootstrap")
shared.core_context=ctx.flaccess
shared.m = {name = "FLAccess"}

shared.VERSION = "0.2.1"
shared.DEBUG_TRACE = false
shared.RESOLVED_TEXT_RVA = 0x1496a3c
shared.SLIDER_INIT_RVA = 0xe59f80
shared.SLIDER_SET_RVA = 0xe5a190
shared.UI_TEXT_SET_RVA = 0xe49070
shared.LIST_ITEM_RENDER_RVA = 0xc97408
shared.TEAM_ITEM_TEXT_A_RVA = 0xc97c32
shared.TEAM_ITEM_TEXT_B_RVA = 0xc97ca8
shared.GAME_TEXT_LANGUAGE_SET_RVA = 0xb22a50
shared.COMMENTARY_LANGUAGE_SET_RVA = 0xb229f0
shared.GAME_TEXT_LANGUAGE_NAV_RVA = 0xb22871
shared.a11y = {
    build = 87,
    selection_diagnostic = false,
    runtime_version = shared.VERSION,
    keyboard_echo_insertions = false,
    player_secondary_partial = true,
    player_secondary_verified = false,
    previous_option_key = 0x36, -- 6
    next_option_key = 0x37, -- 7
    restore_key = 0x38, -- 8
    previous_value_key = 0x39, -- 9
    next_value_key = 0x30, -- 0
    read_tooltips = true,
    use_text_assets = true,
    text_asset_roles = {pt = {}, en = {}},
    text_asset_templates = {pt = {}, en = {}},
    text_asset_counts = {pt = 0, en = 0},
    diagnostic_mode = false,
    selected_option = 1,
    possession_interval = 5,
    possession_number = false,
    controlled_player = false,
    tts_voice = "",
    tts_rate = 50,
    tts_pitch = 50,
    tts_volume = 100,
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
    pending_modal_button_text = nil,
    pending_message_widget_key = nil,
    modal_message_backlog = {},
    deferred_modal_announcement = nil,
    last_modal_message_text = nil,
    modal_navigation_last_ms = nil,
    modal_dialog_start_frame = -10000,
    nvda_stop_requested = false,
    transition_old_focus_texts = nil,
    transition_guard_until_ms = 0,
    skip_hint_last_frame = -10000,
    side_last_user = nil,
    title_pending_first_item = nil,
    title_pending_first_item_until_ms = 0,
    last_screen_title_frame = -10000,
    ui_language = "en",
    ui_language_locked = false,
    sider_overlay_text_by_module = {},
    pre_match_active = false,
    game_plan_active = false,
    game_plan_main_surface = false,
    game_plan_entry_requested = false,
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
    game_plan_menu_probe_due_frame = nil,
    game_plan_menu_probe_action = nil,
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
    cup_group_table_active = false,
    cup_group_cell_by_widget = {},
    cup_group_current_cell = nil,
    cup_group_last_announced = nil,
    cup_group_last_navigation_frame = -10000,
    screen_title_hold_until_ms = 0,
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
shared.ORIGINAL_PROLOGUE =
    "\x48\x8b\xd0" ..
    "\x48\x8b\xcb" ..
    "\x48\x8b\x5c\x24\x30" ..
    "\x48\x83\xc4\x20"
shared.SLIDER_INIT_PROLOGUE =
    "\x48\x89\x5c\x24\x18" ..
    "\x48\x89\x74\x24\x20" ..
    "\x41\x56" ..
    "\x48\x83\xec\x20"
shared.SLIDER_SET_PROLOGUE =
    "\x48\x89\x5c\x24\x10" ..
    "\x48\x89\x6c\x24\x18" ..
    "\x57" ..
    "\x48\x83\xec\x20"
shared.LANGUAGE_SET_PROLOGUE =
    "\x48\x89\x5c\x24\x08" ..
    "\x57" ..
    "\x48\x83\xec\x30" ..
    "\x8b\xda" ..
    "\x48\x8b\xf9"
shared.LANGUAGE_NAV_PROLOGUE =
    "\x48\x8b\x93\xa8\x00\x00\x00" ..
    "\x48\x8b\xcb" ..
    "\x8b\xf0" ..
    "\x8b\x3c\xb2"
-- Final NodeRectText setter, also called directly without e48bf0.
shared.UI_TEXT_SET_PROLOGUE =
    "\x48\x8b\xc4\x55\x56\x57" ..
    "\x48\x81\xec\x00\x01\x00\x00" ..
    "\x48\xc7\x44\x24\x20\xfe\xff\xff\xff"
shared.LIST_ITEM_RENDER_PROLOGUE =
    "\x45\x8b\x07" ..
    "\x4d\x8d\x4f\x40" ..
    "\x48\x8b\x4c\x24\x78" ..
    "\x48\x8b\xd0"
shared.TEAM_ITEM_TEXT_PROLOGUE =
    "\x90" ..
    "\x45\x33\xc9" ..
    "\x45\x33\xc0" ..
    "\x48\x8d\x55\xe7" ..
    "\x48\x8b\xcf"

shared.process_base = nil
shared.process_base_u64 = nil
shared.readable = nil
shared.read_u64 = nil
shared.speak = nil
shared.seen = {}
shared.unique_count = 0
shared.widgets = {}
shared.widget_count = 0
shared.slider_rows = {}
shared.slider_values = {}
shared.unmapped_sliders = {}
shared.ui_text_by_widget = {}
shared.ui_text_seen = {}
shared.ui_text_unique_count = 0
shared.ui_focus_widgets = {}
shared.ui_focus_widget_count = 0
shared.ui_focus_state = {}
shared.ui_focus_activated = {}
shared.ui_focus_candidate_key = nil
shared.ui_focus_candidate_since = 0
shared.last_ui_focus_announcement = nil
shared.ui_focus_preferred_offset_index = nil
shared.last_selected_ui_entry = nil
shared.dialog_options = {}
shared.dialog_signature = nil
shared.dialog_preferred_offset = nil
shared.dialog_focus_candidate = nil
shared.dialog_focus_candidate_since = 0
shared.last_dialog_announcement = nil
shared.recent_message_text = nil
shared.recent_message_widget_key = nil
shared.recent_message_frame = -10000
shared.pending_message_text = nil
shared.pending_message_key = nil
shared.pending_message_due_ms = nil
shared.last_announced_message_key = nil
shared.modal_focus_hold_until_ms = 0
shared.last_modal_button_frame = -10000
shared.modal_message_spoken_frame = -10000
shared.instruction_message_locked = false
shared.recent_heading_text = nil
shared.recent_heading_frame = -10000
shared.standard_text_by_widget = {}
shared.dynamic_text_candidate = nil
shared.dynamic_text_due_ms = nil
shared.main_menu_title_widget_key = nil
shared.current_main_menu_title = nil
shared.main_menu_tooltip = nil
shared.main_menu_tooltip_due_ms = nil
shared.main_menu_focus_guard_until = 0
shared.last_screen_title_key = nil
shared.controller_rows = {}
shared.control_rows_by_label_widget = {}
shared.control_row_by_value_widget = {}
shared.pending_control_row = nil
shared.active_control_row = nil
shared.active_control_focused_ms = 0
shared.active_controller_label = nil
shared.last_controller_announcement = nil
shared.last_announced_control_row = nil
shared.last_announced_selector_label = nil
shared.pending_controller_tooltip = nil
shared.pending_controller_tooltip_label = nil
shared.controller_tooltip_due_ms = nil
shared.last_spoken_controller_tooltip_key = nil
shared.focused_control_hint = nil
shared.focused_control_hint_ms = 0
shared.latest_generic_tooltip = nil
shared.latest_generic_tooltip_widget = nil
shared.latest_generic_tooltip_ms = 0
shared.last_audio_id = nil
shared.speech_sequence = 0
shared.last_spoken_text = nil
shared.last_spoken_ms = 0
shared.last_widget_frame = -10000
shared.prism_started = false
shared.frame = 0
shared.startup_complete = false
shared.startup_completed_frame = -10000
shared.game_was_foreground = true
shared.foreground_resume_frame = 0
shared.overlay_visible = false
shared.sider_overlay_visible = false
shared.startup_speech = {
    queue = {},
    first = 1,
    last = 0,
    next_ms = 0,
    seen = {},
    version = nil,
    version_due_ms = nil,
    version_queued = false,
}
shared.audio_ids = {
    [393228] = true,
    [393230] = true,
    [393260] = true,
    [393261] = true,
    [393262] = true,
    [393263] = true,
    [393264] = true,
}
shared.a11y.fast_focus_items = {
    ["Configurações de áudio"] = true,
    ["Música"] = true,
    ["Comentário"] = true,
    ["Configurações de volume"] = true,
    ["Audio Settings"] = true,
    ["Music"] = true,
    ["Commentary"] = true,
    ["Volume Settings"] = true,
}
shared.controller_labels = {
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
shared.a11y.game_plan_roster_contexts = {
    ["Menu de configuração básica"] = true,
    ["Configurações táticas básicas"] = true,
    ["Plano de jogo normal"] = true,
    ["Escalação/Editar posição"] = true,
    ["Basic Tactical Settings"] = true,
    ["Basic Settings Menu"] = true,
    ["Normal Game Plan"] = true,
    ["Team Sheet/Edit Position"] = true,
}
shared.a11y.game_plan_edit_contexts = {
    ["Escalação/Editar posição"] = true,
    ["Team Sheet/Edit Position"] = true,
}
shared.a11y.game_plan_cycling_choices = {
    ["Plano de jogo normal"] = true,
    ["Escalação/Editar posição"] = true,
    ["Configurações táticas básicas"] = true,
    ["Normal Game Plan"] = true,
    ["Team Sheet/Edit Position"] = true,
    ["Basic Tactical Settings"] = true,
}
shared.a11y.game_plan_menu_items = {
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
shared.a11y.game_plan_basic_prompt_items = {
    ["Usar"] = true,
    ["Não usar"] = true,
    ["Use"] = true,
    ["Do not use"] = true,
}
shared.a11y.game_plan_tactical_labels = {
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
shared.a11y.game_plan_basic_configuration_items = {
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
shared.a11y.game_plan_screen_titles = {
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
shared.a11y.game_plan_attribute_names = {
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
shared.a11y.player_attribute_specs = {
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
shared.a11y.player_position_names = {
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

function shared.a11y.normalized_player_name(text)
    if not text then return nil end
    local normalized = text:gsub("^%s*%d+%s+", "")
        :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return normalized ~= "" and normalized or nil
end

function shared.a11y.player_for_text(text)
    local normalized = shared.a11y.normalized_player_name(text)
    if not normalized then return nil end
    if shared.a11y.game_plan_player_cache[normalized] then
        return shared.a11y.game_plan_player_cache[normalized]
    end
    for stored_name, player in pairs(shared.a11y.game_plan_player_cache) do
        -- The live PES record has a 15-byte name field, while the UI can show
        -- the complete localized name. Match that validated record prefix.
        if normalized:sub(1, #stored_name) == stored_name then
            return player
        end
    end
    return nil
end

function shared.a11y.record_game_plan_input(action, source)
    if (shared.a11y.main_menu_choice_state or shared.a11y.dashboard_review) and (action=="up" or action=="down" or action=="left"
            or action=="right" or action=="A" or action=="B") then
        shared.a11y.main_navigation_probe={action=action,source=source or "unknown",before=shared.a11y.main_navigation_last}
    end
    if shared.overlay_visible or shared.sider_overlay_visible then return end
    if action=="Y" then
        local node=shared.a11y.focused_player_node()
        local record=node and shared.a11y.current_player_record(node,true)
        shared.a11y.visualization_player=record and {player_id=record.player_id,slot=record.slot,side=record.side,
            descriptor_offset=record.descriptor_offset,name=shared.a11y.normalized_player_name(node.text)} or nil
        shared.a11y.visualization_review=nil
    elseif action=="B" or action=="escape" then
        shared.a11y.visualization_player=nil;shared.a11y.visualization_review=nil
    end
    if (action == "A" or action == "B" or action == "escape")
            and shared.a11y.read_context and shared.a11y.read_context.question
            and shared.pending_message_text == nil and #shared.a11y.modal_message_backlog == 0 then
        if action == "A" and shared.a11y.read_context.answer_owners then
            shared.a11y.answer_chain = {owners=shared.a11y.read_context.answer_owners,
                message_key=shared.a11y.read_context.message_key, frame=shared.frame,
                model_generation=shared.a11y.ui_model and shared.a11y.ui_model.generation}
        else
            shared.a11y.answer_chain = nil
        end
        shared.a11y.reset_read_context("dialog-input")
    end
    if action == "up" or action == "down" or action == "left" or action == "right"
            or action == "A" or action == "B" or action == "escape" then
        shared.a11y.begin_focus_trace(action)
    end
    shared.a11y.diagnostic_last_input_action = action
    shared.a11y.diagnostic_last_input_source = source
    shared.a11y.diagnostic_last_input_frame = shared.frame
    if action == "A" and shared.last_selected_ui_entry
            and (shared.last_selected_ui_entry.text == "Plano de jogo"
                or shared.last_selected_ui_entry.text == "Game Plan") then
        shared.a11y.game_plan_entry_requested = true
    elseif action == "B" or action == "escape" then
        shared.a11y.game_plan_entry_requested = false
    end
    if action == "A" and shared.last_selected_ui_entry then
        local selected_text = shared.last_selected_ui_entry.text
        if selected_text == "OK" or selected_text == "Confirmar"
                or selected_text == "Avançar"
                or selected_text == "Concordo."
                or selected_text == "I agree." then
            local old_texts = {}
            for _, entry in pairs(shared.ui_focus_widgets) do
                old_texts[entry.text] = true
            end
            shared.a11y.transition_old_focus_nodes = {}
            for key, entry in pairs(shared.ui_focus_widgets) do
                local node = shared.a11y.ui_model and shared.a11y.ui_model.nodes[key]
                shared.a11y.transition_old_focus_nodes[key] = {
                    identity=node and node.identity, text=entry.text,
                }
            end
            shared.a11y.transition_started_frame = shared.frame
            shared.a11y.transition_old_focus_texts = old_texts
            shared.a11y.transition_guard_until_ms =
                tonumber(ffi.C.GetTickCount64()) + 30000
            shared.a11y.clear_speech_queue()
            shared.a11y.deferred_modal_announcement = nil
        end
    end
    local directional = action == "up" or action == "down"
        or action == "left" or action == "right"
    if directional and shared.a11y.prism_backend_name == "NVDA" then
        if shared.pending_message_text == nil
                and (tonumber(ffi.C.GetTickCount64())
                    < shared.modal_focus_hold_until_ms
                    or shared.a11y.title_pending_first_item) then
            shared.modal_focus_hold_until_ms = 0
            shared.a11y.screen_title_hold_until_ms = 0
            shared.a11y.title_pending_first_item = nil
            shared.a11y.deferred_modal_announcement = nil
            shared.a11y.last_modal_message_text = nil
            shared.a11y.nvda_stop_requested = true
            shared.a11y.clear_speech_queue()
            shared.a11y.reset_focus_reuse_state()
            shared.dialog_focus_candidate = nil
            shared.last_dialog_announcement = nil
            shared.a11y.game_plan_last_focus_text = nil
        end
    elseif directional and shared.pending_message_text == nil
            and shared.frame > shared.modal_message_spoken_frame
            and tonumber(ffi.C.GetTickCount64()) < shared.modal_focus_hold_until_ms then
        local now_ms = tonumber(ffi.C.GetTickCount64())
        if shared.a11y.modal_navigation_last_ms
                and now_ms - shared.a11y.modal_navigation_last_ms >= 650 then
            -- Keep the conservative second-burst fallback for SAPI and other
            -- backends where the NVDA-specific interruption is unavailable.
            shared.modal_focus_hold_until_ms = 0
            shared.a11y.deferred_modal_announcement = nil
            shared.a11y.last_modal_message_text = nil
            shared.a11y.reset_focus_reuse_state()
            shared.dialog_focus_candidate = nil
            shared.last_dialog_announcement = nil
            shared.a11y.game_plan_last_focus_text = nil
        end
        shared.a11y.modal_navigation_last_ms = now_ms
    end
    if action == "A" and shared.pending_message_text == nil
            and #shared.a11y.modal_message_backlog == 0
            and shared.a11y.last_modal_message_text
            and not shared.a11y.is_instruction_message(
                shared.a11y.last_modal_message_text) then
        -- An explicit confirmation leaves a finished dialog. Do not let its
        -- estimated reading time mute the next list or control. Paged
        -- instructions keep their hold and remain queued in order.
        shared.modal_focus_hold_until_ms = 0
        shared.a11y.deferred_modal_announcement = nil
        shared.a11y.last_modal_message_text = nil
        shared.a11y.modal_navigation_last_ms = nil
        shared.a11y.reset_focus_reuse_state()
        shared.dialog_focus_candidate = nil
        shared.last_dialog_announcement = nil
        shared.a11y.game_plan_last_focus_text = nil
    end
    if directional then
        shared.a11y.navigation_frame = shared.frame
        shared.a11y.navigation_action = action
        if shared.a11y.game_plan_active
                and (shared.a11y.game_plan_context ==
                        "Menu de configuração básica"
                    or shared.a11y.game_plan_context ==
                        "Basic Settings Menu") then
            shared.a11y.game_plan_menu_probe_due_frame = shared.frame + 3
            shared.a11y.game_plan_menu_probe_action = action
        end
    elseif action == "B" or action == "escape" then
        -- A fast return must not treat reused destination widgets as read.
        shared.a11y.reset_focus_reuse_state()
        shared.a11y.game_plan_last_focus_text = nil
    end
    if not shared.a11y.game_plan_active then return end
    if action == "A" and shared.a11y.game_plan_basic_prompt_active
            and shared.last_selected_ui_entry
            and shared.a11y.game_plan_basic_prompt_items[
                shared.last_selected_ui_entry.text] then
        -- The prompt is gone after confirmation. Its old widgets and focus
        -- bits must not keep winning over the following Game Plan menu.
        shared.a11y.game_plan_basic_prompt_active = false
        shared.a11y.game_plan_last_menu_focus = nil
        shared.a11y.reset_focus_reuse_state()
    end
    if action == "A" and shared.a11y.game_plan_last_menu_focus
            and not shared.a11y.game_plan_basic_prompt_active then
        -- Several Game Plan sub-screens do not reuse the Basic Settings title
        -- widget. The command confirmed by the user is therefore the most
        -- reliable context transition signal.
        shared.a11y.game_plan_context = shared.a11y.game_plan_last_menu_focus
        shared.a11y.game_plan_main_surface = false
        shared.a11y.game_plan_formation_active = false
        shared.a11y.game_plan_announced_context = nil
        shared.a11y.game_plan_last_focus_text = nil
        shared.a11y.reset_focus_reuse_state()
    elseif (action == "B" or action == "escape")
            and (shared.a11y.game_plan_context == "Alterar formação"
                or shared.a11y.game_plan_context == "Change Formation") then
        shared.a11y.game_plan_context = shared.a11y.ui_language == "pt"
            and "Menu de configuração básica" or "Basic Settings Menu"
        shared.a11y.game_plan_formation_active = false
        shared.a11y.game_plan_announced_context = nil
        shared.a11y.game_plan_last_focus_text = nil
        shared.a11y.game_plan_last_menu_focus = nil
        shared.a11y.reset_focus_reuse_state()
    end
    if shared.a11y.game_plan_context == "Configurações táticas básicas"
            or shared.a11y.game_plan_context == "Basic Tactical Settings" then
        if action == "down" or action == "up" then
            shared.a11y.game_plan_tactical_navigation_frame = shared.frame
            shared.a11y.clear_pending_tooltips()
            shared.last_controller_announcement = nil
            shared.last_announced_control_row = nil
            shared.last_announced_selector_label = nil
        elseif action == "left" or action == "right" then
            shared.a11y.game_plan_tactical_navigation_frame = shared.frame
            shared.a11y.clear_pending_tooltips()
        elseif action == "escape" or action == "B" then
            shared.a11y.game_plan_context = shared.a11y.ui_language == "pt"
                and "Plano de jogo normal" or "Normal Game Plan"
            shared.a11y.game_plan_active_tactical_label = nil
            shared.a11y.game_plan_active_tactical_value = nil
            shared.a11y.game_plan_active_tactical_widget = nil
            shared.a11y.game_plan_active_tactical_frame = -10000
            shared.active_control_row = nil
            shared.active_controller_label = nil
            shared.a11y.reset_focus_reuse_state()
            shared.a11y.game_plan_last_focus_text = nil
            shared.a11y.game_plan_announced_context = nil
        end
    end
    if not shared.a11y.diagnostic_mode then return end
    shared.a11y.diagnostic_input_sequence = shared.a11y.diagnostic_input_sequence + 1
    local heading = shared.a11y.game_plan_selected_heading
        or shared.a11y.diagnostic_selected_heading
        or shared.a11y.game_plan_last_focus_text
    local player = shared.a11y.player_for_text(heading)
    shared.a11y.diagnostic_sequence = shared.a11y.diagnostic_sequence + 1
    shared.a11y.diagnostic_write({
        string.format(
            "EVENT %d frame=%d kind=game-plan-input input=%d source=%s action=%s",
            shared.a11y.diagnostic_sequence, shared.frame,
            shared.a11y.diagnostic_input_sequence, tostring(source), tostring(action)),
        string.format(
            "before heading=%q context=%q heading_age=%d",
            shared.a11y.diagnostic_text(heading),
            shared.a11y.diagnostic_text(shared.a11y.game_plan_context),
            shared.frame - shared.a11y.diagnostic_selected_heading_frame),
        string.format(
            "player pointer=%s player_id=%s team_id=%s registered_position=%q attribute_panel=%s",
            shared.a11y.diagnostic_hex(player and player.pointer),
            tostring(player and player.player_id or "unknown"),
            tostring(player and player.team_id or "unknown"),
            shared.a11y.diagnostic_text(player and player.position),
            tonumber(ffi.C.GetTickCount64()) <=
                shared.a11y.game_plan_attribute_panel_until_ms and "open" or "closed"),
        "",
    })
end

function shared.a11y.record_game_plan_menu_probe()
    local due = shared.a11y.game_plan_menu_probe_due_frame
    if not due or shared.frame < due then return end
    shared.a11y.game_plan_menu_probe_due_frame = nil
    if not shared.a11y.game_plan_active
            or (shared.a11y.game_plan_context ~= "Menu de configuração básica"
                and shared.a11y.game_plan_context ~= "Basic Settings Menu") then
        return
    end
    local recent = {}
    local parents = {}
    local selected_text, selected_key, selected_age
    for key, entry in pairs(shared.ui_focus_widgets) do
        local age = shared.frame - (entry.last_seen or shared.frame)
        if age <= 8 and shared.a11y.game_plan_cycling_choices[entry.text]
                and not shared.a11y.game_plan_title_widgets[key]
                and shared.a11y.widget_internal_name(entry.address) == "text"
                and (not selected_age or age < selected_age) then
            selected_text, selected_key, selected_age = entry.text, key, age
        end
        if shared.a11y.diagnostic_mode and age <= 30 then
            local name = shared.a11y.widget_internal_name(entry.address)
            if name == "titleHeadlineText"
                    or name == "titleHeadlineTextB" then
                if shared.readable(entry.address + 0x38, 8) then
                    local parent = shared.read_u64(memory.read(
                        entry.address + 0x38, 8))
                    if parent and parent >= 0x10000
                            and shared.readable(parent, 0x100) then
                        parents[shared.a11y.diagnostic_hex(parent)] = parent
                    end
                end
            end
            recent[#recent + 1] = string.format(
                "%s %q name=%q age=%d",
                key, shared.a11y.diagnostic_text(entry.text),
                shared.a11y.diagnostic_text(name), age)
        end
    end
    if selected_text then
        -- These rotating choices never appear inside the Usar/Não usar
        -- dialog, so their presence also proves that prompt is closed.
        shared.a11y.game_plan_basic_prompt_active = false
        shared.a11y.game_plan_last_menu_focus = selected_text
        local announcement = shared.a11y.game_plan_focus_speech(
            selected_text, selected_key)
        if announcement then shared.speak(announcement) end
    end
    if not shared.a11y.diagnostic_mode then return end
    table.sort(recent)
    local parent_fields = {}
    for key, address in pairs(parents) do
        local fields = {}
        for offset = 0, 0xfc, 4 do
            local value = memory.unpack(
                "u32", memory.read(address + offset, 4))
            if value ~= 0 then
                fields[#fields + 1] = string.format(
                    "+0x%x=%x", offset, value)
            end
        end
        parent_fields[#parent_fields + 1] = key .. " {" ..
            table.concat(fields, ",") .. "}"
    end
    table.sort(parent_fields)
    shared.a11y.diagnostic_sequence = shared.a11y.diagnostic_sequence + 1
    shared.a11y.diagnostic_write({
        string.format(
            "EVENT %d frame=%d kind=game-plan-menu-probe action=%s context=%q",
            shared.a11y.diagnostic_sequence, shared.frame,
            shared.a11y.diagnostic_text(shared.a11y.game_plan_menu_probe_action),
            shared.a11y.diagnostic_text(shared.a11y.game_plan_context)),
        "recent_widgets={" .. table.concat(recent, "; ") .. "}",
        "title_parents={" .. table.concat(parent_fields, "; ") .. "}",
        "",
    })
end

function shared.a11y.record_game_plan_heading(text, widget_key)
    if not shared.a11y.game_plan_active then
        return
    end
    local changed = text ~= shared.a11y.game_plan_selected_heading
    if changed
            and tonumber(ffi.C.GetTickCount64()) <=
                shared.a11y.game_plan_attribute_panel_until_ms
            and shared.frame - shared.a11y.game_plan_attribute_last_marker_frame > 12 then
        -- The attribute panel has closed, but its 30-second safety timer was
        -- still suppressing the newly selected player.
        shared.a11y.game_plan_attribute_panel_until_ms = 0
        shared.a11y.game_plan_attribute_locked_name = nil
        shared.a11y.game_plan_attribute_due_ms = nil
        shared.a11y.game_plan_attribute_hold_until_ms = 0
    end
    shared.a11y.game_plan_selected_heading = text
    shared.a11y.game_plan_selected_heading_frame = shared.frame
    shared.a11y.game_plan_selected_heading_widget = widget_key
    if changed then
        -- This heading mutates in place and uniquely represents the selected
        -- player. Give its pitch/bench parent layout a few frames to finish
        -- rebinding before classifying the section.
        shared.a11y.game_plan_selected_heading_due_frame = shared.frame + 6
    end
    if not shared.a11y.diagnostic_mode
            or text == shared.a11y.diagnostic_selected_heading then return end
    local previous = shared.a11y.diagnostic_selected_heading
    shared.a11y.diagnostic_selected_heading = text
    shared.a11y.diagnostic_selected_heading_frame = shared.frame
    shared.a11y.diagnostic_selected_heading_widget = widget_key
    shared.a11y.diagnostic_selection_sequence =
        shared.a11y.diagnostic_selection_sequence + 1
    shared.a11y.diagnostic_player_visits[text] =
        (shared.a11y.diagnostic_player_visits[text] or 0) + 1
    local player = shared.a11y.player_for_text(text)
    shared.a11y.diagnostic_sequence = shared.a11y.diagnostic_sequence + 1
    shared.a11y.diagnostic_write({
        string.format(
            "EVENT %d frame=%d kind=game-plan-selection selection=%d widget=%s",
            shared.a11y.diagnostic_sequence, shared.frame,
            shared.a11y.diagnostic_selection_sequence, tostring(widget_key)),
        string.format(
            "transition previous=%q current=%q visit=%d",
            shared.a11y.diagnostic_text(previous), shared.a11y.diagnostic_text(text),
            shared.a11y.diagnostic_player_visits[text]),
        string.format(
            "after_input action=%s source=%s delta_frames=%d",
            tostring(shared.a11y.diagnostic_last_input_action or "none"),
            tostring(shared.a11y.diagnostic_last_input_source or "none"),
            shared.frame - shared.a11y.diagnostic_last_input_frame),
        string.format(
            "player pointer=%s player_id=%s team_id=%s registered_position=%q",
            shared.a11y.diagnostic_hex(player and player.pointer),
            tostring(player and player.player_id or "unknown"),
            tostring(player and player.team_id or "unknown"),
            shared.a11y.diagnostic_text(player and player.position)),
        "",
    })
    -- Capture the UI object that displays the same player on the pitch/bench.
    -- Its parent chain is the missing structural signal for classifying the
    -- selected slot without player-name tables or assumptions about Option Files.
    local normalized = shared.a11y.normalized_player_name(text)
    if not normalized then return end
    local matches = {}
    for candidate_key, candidate in pairs(shared.ui_focus_widgets) do
        local candidate_name = shared.a11y.normalized_player_name(candidate.text)
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
            shared.a11y.diagnostic_selection_sequence,
            tostring(widget_key),
            shared.a11y.diagnostic_text(normalized),
            #matches),
    }
    for _, match in ipairs(matches) do
        local address = match.entry.address
        local fields = {}
        if address and shared.readable(address, 0x180) then
            for offset = 0, 0x178, 8 do
                fields[#fields + 1] = string.format(
                    "+0x%03x=%s", offset,
                    shared.a11y.diagnostic_hex(shared.read_u64(
                        memory.read(address + offset, 8))))
            end
        end
        lines[#lines + 1] = string.format(
            "card widget=%s text=%q age=%d qwords={%s}",
            match.key,
            shared.a11y.diagnostic_text(match.entry.text),
            shared.frame - (match.entry.last_seen or shared.frame),
            table.concat(fields, ","))
        if address and shared.readable(address + 0x38, 8) then
            local parent = shared.read_u64(memory.read(address + 0x38, 8))
            local parent_fields = {}
            if parent and parent >= 0x10000 and shared.readable(parent, 0x100) then
                for offset = 0, 0xf8, 8 do
                    parent_fields[#parent_fields + 1] = string.format(
                        "+0x%02x=%s", offset,
                        shared.a11y.diagnostic_hex(shared.read_u64(
                            memory.read(parent + offset, 8))))
                end
            end
            lines[#lines + 1] = string.format(
                "card_parent pointer=%s qwords={%s}",
                shared.a11y.diagnostic_hex(parent),
                table.concat(parent_fields, ","))
        end
    end
    lines[#lines + 1] = ""
    shared.a11y.diagnostic_write(lines)
end

function shared.a11y.player_record_bits(bytes, offset, start_bit, bit_length)
    local first = bytes:byte(offset + 1) or 0
    local second = bytes:byte(offset + 2) or 0
    local third = bytes:byte(offset + 3) or 0
    local packed = first + second * 0x100 + third * 0x10000
    return math.floor(packed / (2 ^ start_bit)) % (2 ^ bit_length)
end

function shared.a11y.capture_player_record(pointer, source)
    if not shared.a11y.game_plan_active or pointer == nil or pointer == 0 then
        return false
    end
    local address = tonumber(pointer)
    if not address or address < 0x10000 then
        return false
    end
    local wanted=shared.a11y.detail_reads_allowed and 0x17c or 0x48
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
            or address + wanted > region_end then
        return false
    end
    local bytes = shared.a11y.safe_memory_read(address,wanted)
    if type(bytes) ~= "string" or #bytes < wanted then
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
    if not shared.a11y.detail_reads_allowed then
        local id=tonumber(memory.unpack("u32",bytes:sub(0x31,0x34)))
        if not id or id==0 then return false end
        shared.a11y.game_plan_player_cache[name]={pointer=pointer,name=name,player_id=id,attributes={}}
        return true -- names/status remain available, attribute decoding is deferred
    end
    local decoded = {}
    local plausible = 0
    for _, definition in ipairs(shared.a11y.player_attribute_specs) do
        local value = shared.a11y.player_record_bits(
            bytes, definition[3], definition[4], 7)
        if value >= 40 and value <= 99 then
            plausible = plausible + 1
        end
        decoded[#decoded + 1] = {
            label = shared.a11y.ui_language == "pt" and definition[1] or definition[2],
            value = tostring(value),
            source = "player-record",
        }
    end
    if plausible < 20 then
        return false
    end
    local position_id = shared.a11y.player_record_bits(bytes, 0x07, 4, 4)
    local positions = shared.a11y.player_position_names[shared.a11y.ui_language]
        or shared.a11y.player_position_names.en
    local cached = {
        pointer = pointer,
        name = name,
        position = positions[position_id],
        attributes = decoded,
        player_id = memory.unpack("u32", bytes:sub(0x31, 0x34)),
        team_id = shared.a11y.player_record_bits(bytes, 0x12c, 0, 16),
    }
    shared.a11y.game_plan_player_cache[name] = cached
    local focused_name = shared.a11y.normalized_player_name(
        shared.a11y.game_plan_attribute_locked_name or shared.a11y.game_plan_last_focus_text)
    if focused_name and focused_name ~= name
            and focused_name:sub(1, #name) ~= name then
        return true
    end
    local changed = shared.a11y.game_plan_player_record ~= pointer
        or shared.a11y.game_plan_player_name ~= (focused_name or name)
    shared.a11y.game_plan_player_record = pointer
    shared.a11y.game_plan_player_name = focused_name or name
    shared.a11y.game_plan_player_attributes = decoded
    if tonumber(ffi.C.GetTickCount64()) <= shared.a11y.game_plan_attribute_panel_until_ms then
        shared.a11y.game_plan_attribute_items = decoded
        shared.a11y.game_plan_attribute_index = 0
    end
    if changed and shared.a11y.diagnostic_mode then
        shared.a11y.diagnostic_sequence = shared.a11y.diagnostic_sequence + 1
        local values = {}
        for _, item in ipairs(decoded) do
            values[#values + 1] = item.label .. "=" .. item.value
        end
        shared.a11y.diagnostic_write({
            string.format(
                "EVENT %d frame=%d kind=player-record source=%s pointer=%s name=%q player_id=%s team_id=%s selected_heading=%q",
                shared.a11y.diagnostic_sequence,
                shared.a11y.current_frame or -1,
                tostring(source),
                memory.hex(pointer),
                shared.a11y.diagnostic_text(name),
                tostring(cached.player_id),
                tostring(cached.team_id),
                shared.a11y.diagnostic_text(shared.a11y.diagnostic_selected_heading)),
            "attributes={" .. table.concat(values, "; ") .. "}",
            "",
        })
    end
    return true
end
shared.stadium_labels = {
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
shared.controller_tooltip_labels = {
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
shared.controller_tooltip_values = {
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

function shared.reset_message_state()
    shared.recent_message_text = nil
    shared.recent_message_widget_key = nil
    shared.recent_message_frame = -10000
    shared.pending_message_text = nil
    shared.pending_message_key = nil
    shared.a11y.pending_message_widget_key = nil
    shared.a11y.pending_message_owner=nil
    shared.pending_message_due_ms = nil
    shared.last_announced_message_key = nil
    shared.modal_focus_hold_until_ms = 0
    shared.a11y.last_modal_message_text = nil
    shared.a11y.modal_navigation_last_ms = nil
    shared.a11y.modal_dialog_start_frame = -10000
    shared.a11y.nvda_stop_requested = false
    shared.last_modal_button_frame = -10000
    shared.modal_message_spoken_frame = -10000
    shared.instruction_message_locked = false
    shared.a11y.pending_modal_button_text = nil
    shared.a11y.modal_message_backlog = {}
    shared.a11y.deferred_modal_announcement = nil
    shared.recent_heading_text = nil
    shared.recent_heading_frame = -10000
    shared.focused_control_hint = nil
    shared.focused_control_hint_ms = 0
    shared.a11y.ui_text_caller_by_widget = {}
    shared.a11y.diagnostic_candidate_key = nil
    shared.a11y.diagnostic_candidate_since = shared.frame
    shared.a11y.diagnostic_last_key = nil
end

function shared.a11y.reset_focus_reuse_state()
    shared.a11y.control_focus_owner = nil
    shared.last_controller_announcement, shared.last_announced_control_row = nil, nil
    shared.last_announced_selector_label = nil
    shared.ui_focus_candidate_key = nil
    shared.ui_focus_candidate_since = 0
    shared.last_ui_focus_announcement = nil
    shared.ui_focus_preferred_offset_index = nil
    shared.a11y.diagnostic_candidate_key = nil
    shared.a11y.diagnostic_candidate_since = shared.frame
end

function shared.a11y.focus_widget_reused(previous_focus, text)
    return previous_focus ~= nil and previous_focus.text ~= text
        and shared.frame - (previous_focus.last_seen or shared.frame) > 30
end

function shared.reset_navigation_generation()
    shared.a11y.reset_control_tracking_state()
    shared.ui_focus_widgets = {}
    shared.ui_focus_widget_count = 0
    shared.ui_focus_state = {}
    shared.ui_focus_activated = {}
    shared.a11y.reset_focus_reuse_state()
    shared.last_selected_ui_entry = nil
    shared.dynamic_text_candidate = nil
    shared.dynamic_text_due_ms = nil
    shared.main_menu_tooltip = nil
    shared.main_menu_tooltip_due_ms = nil
    shared.main_menu_focus_guard_until = 0
    shared.last_screen_title_key = nil
    shared.a11y.last_screen_title_frame = -10000
    shared.a11y.title_pending_first_item = nil
    shared.a11y.title_pending_first_item_until_ms = 0
    shared.a11y.transition_old_focus_texts = nil
    shared.a11y.transition_guard_until_ms = 0
    shared.a11y.skip_hint_last_frame = -10000
    shared.a11y.ui_text_caller_by_widget = {}
    shared.slider_rows = {}
    shared.slider_values = {}
    shared.unmapped_sliders = {}
    shared.dialog_options = {}
    shared.dialog_signature = nil
    shared.dialog_preferred_offset = nil
    shared.dialog_focus_candidate = nil
    shared.last_dialog_announcement = nil
    shared.reset_message_state()
end
shared.featured_initial_ids = {
    [60948637] = true,
}
shared.language_options = {}
shared.language_control_by_controller = {}
shared.non_control_labels = {
    ["OK"] = true,
    ["Confirmar"] = true,
    ["Voltar"] = true,
    ["Início"] = true,
    ["Conecte o controle."] = true,
    ["Connect the controller."] = true,
}
shared.ui_focus_offsets = {
    -- 0x114/0x110 are used by the virtualized league and club lists.
    -- Check them before the less reliable auxiliary-state offsets.
    0x104, 0x114, 0x110, 0x108, 0x100, 0x10c,
    0xf0, 0xf4, 0xf8, 0xfc,
    0x118, 0x11c,
}
shared.dialog_focus_offsets = {
    0x104, 0x100, 0x108, 0x10c, 0x110, 0x114, 0x118, 0x11c,
    0x120, 0x124, 0x128, 0x12c, 0x130, 0x134, 0x138, 0x13c,
    0x140, 0x144, 0x148, 0x14c, 0x150, 0x154, 0x158, 0x15c,
    0x160, 0x164, 0x168, 0x16c, 0x170, 0x174, 0x178, 0x17c,
    0xfc, 0xf8, 0xf4, 0xf0, 0xec, 0xe8, 0xe4, 0xe0,
}

function shared.trace_log(message)
    if shared.DEBUG_TRACE then
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
    void *GetCurrentProcess(void);
    int ReadProcessMemory(void*,const void*,void*,size_t,size_t*);
    unsigned long long GetTickCount64(void);
    void *GetForegroundWindow(void);
    unsigned long GetWindowThreadProcessId(
        void *window,
        unsigned long *process_id);
    short GetAsyncKeyState(int virtual_key);
    int GetSystemMetrics(int index);
    typedef void *(__cdecl *FLACCESS_PRISM_INIT)(void *config);
    typedef const char *(__cdecl *FLACCESS_PRISM_VERSION_STRING)(void);
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
    typedef int (__cdecl *FLACCESS_PRISM_BACKEND_STOP)(void *backend);
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

shared.foreground_process_id = ffi.new("unsigned long[1]")
shared.user32 = ffi.load("user32")

function shared.a11y.to_c_string(text)
    local buffer = ffi.new("char[?]", #text + 1)
    ffi.copy(buffer, text, #text)
    return buffer
end

function shared.to_wide(text)
    local source = shared.a11y.to_c_string(text)
    local length = ffi.C.MultiByteToWideChar(
        65001, 0, source, #text, nil, 0)
    if length <= 0 then
        return nil
    end
    local wide = ffi.new("uint16_t[?]", length + 1)
    ffi.C.MultiByteToWideChar(65001, 0, source, #text, wide, length)
    return wide
end

-- Never give an untrusted game pointer directly to lua_pushlstring via
-- Sider memory.read. Windows copies into our own buffer or reports failure.

    shared.stage = 1
end
function component.init(ctx)
    component.install(ctx)

end
return component
