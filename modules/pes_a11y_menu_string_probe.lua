local m = {}

local VERSION = "0.1.4"
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
local latest_generic_tooltip
local latest_generic_tooltip_widget
local latest_generic_tooltip_ms = 0
local last_audio_id
local speech_path
local speech_sequence = 0
local last_spoken_text
local last_spoken_ms = 0
local last_focused_id
local focus_candidate_id
local focus_candidate_since = 0
local last_announced_focus_key
local last_widget_frame = -10000
local bridge_started = false
local frame = 0
local startup_complete = false
local startup_completed_frame = -10000
local side_position
local side_screen_active = false
local side_widget_positions = {}
local side_widget_count = 0
local game_was_foreground = true
local foreground_resume_frame = 0
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
    void *ShellExecuteW(
        void *hwnd,
        const uint16_t *operation,
        const uint16_t *file,
        const uint16_t *parameters,
        const uint16_t *directory,
        int show_command);
    unsigned long GetCurrentProcessId(void);
    unsigned long long GetTickCount64(void);
    void *GetForegroundWindow(void);
    unsigned long GetWindowThreadProcessId(
        void *window,
        unsigned long *process_id);
]]

local foreground_process_id = ffi.new("unsigned long[1]")
local user32 = ffi.load("user32")

local function to_wide(text)
    local wide = ffi.new("uint16_t[?]", #text + 1)
    for index = 1, #text do
        wide[index - 1] = text:byte(index)
    end
    return wide
end

local function start_speech_bridge(ctx)
    local bridge_dir = ctx.sider_dir .. "\\pes-a11y-prism"
    local bridge_exe = bridge_dir .. "\\pes-a11y-prism-bridge.exe"
    local file = io.open(bridge_exe, "rb")
    if not file then
        log(string.format(
            "[pes-a11y-menu-string] prism-bridge-missing path=%q",
            bridge_exe))
        return
    end
    file:close()

    local shell32 = ffi.load("shell32")
    local parameters =
        "--speech-file \"" .. speech_path .. "\" --parent " ..
        tostring(tonumber(ffi.C.GetCurrentProcessId()))
    local result = tonumber(ffi.cast(
        "intptr_t",
        shell32.ShellExecuteW(
            nil,
            to_wide("open"),
            to_wide(bridge_exe),
            to_wide(parameters),
            to_wide(bridge_dir),
            0)))
    log(string.format(
        "[pes-a11y-menu-string] prism-bridge-start result=%d path=%q",
        result,
        bridge_exe))
end

local readable

local function read_u64(bytes)
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
    text = text:gsub("\17..", "")
    text = text:gsub("[\r\n\t]+", " ")
    text = text:gsub("[%z\1-\31]", "")
    -- Form arrows and condition icons are Unicode Private Use Area glyphs.
    -- They have no useful spoken name and can stop some speech backends.
    text = text:gsub("\238[\128-\191][\128-\191]", "")
    text = text:match("^%s*(.-)%s*$") or ""
    return text
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
    return text:find("Dados de atualiz.", 1, true) ~= nil
        or text:find("Pont. unif.", 1, true) ~= nil
        or text == "Pontos da temporada"
        or text == "Progresso"
        or text == "Dados do sistema"
        or (#text == 2 and text:match("^%u%u$") ~= nil
            and text ~= "OK" and text ~= "PN")
end

local function looks_like_message(text)
    return not is_noninteractive_text(text) and not is_splash_text(text)
        and (#text >= 55
        or (#text >= 28 and text:match("[%.%!%?]$") ~= nil)
    )
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
            "[pes-a11y-menu-string] message-append text=%q",
            recent_message_text))
        if is_data_notice(recent_message_text)
                or frame - last_modal_button_frame <= 120 then
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
            "[pes-a11y-menu-string] message-candidate text=%q",
            recent_message_text))
        if is_data_notice(recent_message_text)
                or frame - last_modal_button_frame <= 120 then
            queue_recent_message()
        elseif #recent_message_text >= 100
                and not instruction_message_locked then
            instruction_message_locked = true
            add_recent_heading_to_message()
            queue_recent_message()
        end
    end
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

local function speak(text)
    if not speech_path or not text or text == "" then
        return
    end
    if not game_is_foreground() then
        return
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if text == last_spoken_text and now_ms - last_spoken_ms < 800 then
        return
    end
    last_spoken_text = text
    last_spoken_ms = now_ms
    speech_sequence = speech_sequence + 1
    local file = io.open(speech_path, "wt")
    if not file then
        log(string.format(
            "[pes-a11y-menu-string] speech-write-failed path=%q",
            speech_path))
        return
    end
    file:write(tostring(speech_sequence), "\t", text, "\n")
    file:close()
    log(string.format(
        "[pes-a11y-menu-string] speech sequence=%d text=%q",
        speech_sequence,
        text))
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
        if latest_generic_tooltip
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

local function read_msvc_string(object)
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
    if text == "Sim" or text == "Não" then
        return text .. ", botão selecionado"
    end
    return text .. ", item selecionado"
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
            "[pes-a11y-menu-string] side-widget widget=%s position=%d",
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
        "[pes-a11y-menu-string] slider-map-delayed text=%q object=%s value=%d min=%d max=%d",
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
        log(string.format(
            "[pes-a11y-menu-string] slider-map id=%s text=%q object=%s value=%d min=%d max=%d",
            mapped_id and tostring(mapped_id) or "dynamic",
            mapped_entry.text,
            key,
            value,
            minimum,
            maximum))
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
                if full ~= last_controller_announcement
                        or last_announced_control_row ~= row.control then
                    last_controller_announcement = full
                    last_announced_control_row = row.control
                    speak(tostring(value))
                end
            else
                announce_control(row.control)
            end
        end
    end
    trace_log(string.format(
        "[pes-a11y-menu-string] slider-set value=%d object=%s id=%s text=%q",
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
    return read_msvc_string(first + index * 0x20), controller, index
end

local function language_value_at(controller, index)
    if not controller or controller < 0x10000 or not index or index > 255
            or not readable(controller + 0x90, 8) then
        return nil
    end
    local first = read_u64(memory.read(controller + 0x90, 8))
    return read_msvc_string(first + index * 0x20)
end

local function speak_language(registers, label)
    local value, controller, index = language_value(registers)
    log(string.format(
        "[pes-a11y-menu-string] language-set label=%q object=%s index=%d value=%q",
        label,
        memory.hex(controller or 0),
        index or -1,
        value or ""))
    if value and value ~= "" then
        local key = "language:" .. memory.hex(controller or 0)
        local row = language_control_by_controller[key] or {
            label = label,
            role = "seletor",
            label_widget_key = key,
            is_control = true,
        }
        row.label = label
        row.value = value
        language_control_by_controller[key] = row
        announce_control(row)
    end
end

function m.on_game_text_language_set(ctx, event_id, registers)
    speak_language(registers, "Texto do jogo")
end

function m.on_commentary_language_set(ctx, event_id, registers)
    speak_language(registers, "Idioma do comentário")
end

function m.on_game_text_language_nav(ctx, event_id, registers)
    local controller = read_u64(registers.rbx)
    local index = tonumber(ffi.cast("uint32_t", read_u64(registers.rax)))
    local value = language_value_at(controller, index)
    log(string.format(
        "[pes-a11y-menu-string] language-nav object=%s index=%d value=%q",
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
        }
        language_control_by_controller[key] = row
        if active_control_row == row then
            announce_control_value(row, value)
        else
            row.value = value
            announce_control(row)
        end
    end
end

function m.on_ui_text_set(ctx, event_id, registers)
    local widget = read_u64(registers.rcx)
    local string_object = read_u64(registers.rdx)
    local text = read_msvc_string(string_object)
    if not text or text == "" or widget < 0x10000 then
        return
    end

    local widget_key = memory.hex(widget)
    local previous = ui_text_by_widget[widget_key]
    ui_text_by_widget[widget_key] = text
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if last_ui_text_ms > 0 and now_ms - last_ui_text_ms > 500 then
        -- A pause between text updates is not a screen boundary. Lists and
        -- side-selector cells legitimately create widgets after such a pause.
        reset_focus_reuse_state()
    end
    if previous ~= text then
        announce_screen_title(text, widget_key)
        remember_message_text(text, widget_key)
        if not queue_startup_text(text, now_ms)
                and is_plain_text(text) then
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
    if value_row and active_control_row == value_row and previous ~= text then
        announce_control_value(value_row, text)
    end

    local seen_key = widget_key .. "\0" .. text
    if not ui_text_seen[seen_key] and ui_text_unique_count < 6000 then
        ui_text_seen[seen_key] = true
        ui_text_unique_count = ui_text_unique_count + 1
        trace_log(string.format(
            "[pes-a11y-menu-string] ui-text widget=%s previous=%q text=%q",
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

    local text = read_msvc_string(record + 0x20)
    if not text or text == "" or is_noninteractive_text(text) then
        return
    end

    if text ~= last_native_list_text then
        last_native_list_text = text
        last_native_list_frame = frame
        log(string.format(
            "[pes-a11y-menu-string] native-list-focus text=%q record=%s",
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
    local text = read_msvc_string(saved_rbp - 0x19)
    if not text or text == "" or is_noninteractive_text(text) then
        return
    end

    if text ~= last_native_list_text then
        last_native_list_text = text
        last_native_list_frame = frame
        log(string.format(
            "[pes-a11y-menu-string] native-team-focus text=%q",
            text))
        speak(ui_focus_speech(text))
    end
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
        main_menu_tooltip = football_life_tooltip_title .. ". " ..
            football_life_tooltip_description
        main_menu_tooltip_due_ms =
            tonumber(ffi.C.GetTickCount64()) + 1000
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
        pending_controller_tooltip = clean_text(text)
        pending_controller_tooltip_label = controller_label
        controller_tooltip_due_ms = tonumber(ffi.C.GetTickCount64()) + 2000
    end
    if caller_rva == 0xe4901d then
        local widget = read_u64(memory.read(saved_rsp + 72, 8))
        local spoken = clean_text(text)
        if widget >= 0x10000 and spoken ~= "" then
            local widget_key = memory.hex(widget)
            local previous_widget_text = standard_text_by_widget[widget_key]
            standard_text_by_widget[widget_key] = spoken
            local now_ms = tonumber(ffi.C.GetTickCount64())
            if previous_widget_text ~= spoken then
                announce_screen_title(spoken, widget_key)
                remember_message_text(spoken, widget_key)
                if not queue_startup_text(spoken, now_ms)
                        and is_plain_text(spoken) then
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
            if #spoken >= 35 and not is_noninteractive_text(spoken) then
                latest_generic_tooltip = spoken
                latest_generic_tooltip_widget = widget
                latest_generic_tooltip_ms = now_ms
            end
            local is_active_tooltip = active_control_row
                    and active_control_row.label_widget
                    and widget ~= active_control_row.label_widget
                    and now_ms - active_control_focused_ms <= 5000
                    and #spoken >= 35
                    and not is_noninteractive_text(spoken)
            if is_active_tooltip then
                pending_controller_tooltip = spoken
                pending_controller_tooltip_label = active_control_row.label
                active_controller_label = active_control_row.label
                controller_tooltip_due_ms =
                    now_ms + 2000
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
                    "[pes-a11y-menu-string] main-menu-title widget=%s previous=%q text=%q",
                    widget_key,
                    previous_widget_text or "",
                    spoken))
                if not is_initial_featured then
                    speak(spoken .. ", item")
                end
            elseif main_menu_title_widget_key
                    and text_id >= 13107000 and text_id <= 13108000 then
                main_menu_tooltip = spoken
                main_menu_tooltip_due_ms =
                    tonumber(ffi.C.GetTickCount64()) + 1000
            end
            if frame - last_widget_frame > 12 and widget_count > 0 then
                trace_log(string.format(
                    "[pes-a11y-menu-string] widget-generation-gap gap=%d",
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
                    "[pes-a11y-menu-string] widget id=%u text=%q address=%s",
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
        "[pes-a11y-menu-string] resolved id=%u text=%q length=%d caller_rva=%s",
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

local function process_dialog_focus(modal_focus_blocked)
    if frame % 3 ~= 0 or modal_focus_blocked then
        return
    end
    local dialog_selected, dialog_offset = scan_dialog_focus()
    local candidate = dialog_selected and
        (dialog_signature .. ":" .. dialog_selected) or nil
    if candidate ~= dialog_focus_candidate then
        dialog_focus_candidate = candidate
        dialog_focus_candidate_since = frame
    elseif candidate and frame - dialog_focus_candidate_since >= 6
            and candidate ~= last_dialog_announcement then
        last_dialog_announcement = candidate
        dialog_preferred_offset = dialog_offset
        log(string.format(
            "[pes-a11y-menu-string] dialog-focus offset=0x%x text=%q",
            dialog_offset,
            dialog_selected))
        speak(dialog_selected .. ", botão selecionado")
    end
end

local function process_delayed_speech(now_ms, modal_focus_blocked)
    if not modal_focus_blocked and controller_tooltip_due_ms
            and now_ms >= controller_tooltip_due_ms then
        local tooltip_key = (pending_controller_tooltip_label or "") .. "\0" ..
            (pending_controller_tooltip or "")
        if active_controller_label == pending_controller_tooltip_label
                and pending_controller_tooltip
                and pending_controller_tooltip ~= ""
                and tooltip_key ~= last_spoken_controller_tooltip_key then
            last_spoken_controller_tooltip_key = tooltip_key
            speak(pending_controller_tooltip)
        end
        controller_tooltip_due_ms = nil
    end
    if not modal_focus_blocked and dynamic_text_due_ms
            and now_ms >= dynamic_text_due_ms then
        if dynamic_text_candidate and dynamic_text_candidate ~= "" then
            speak(dynamic_text_candidate)
        end
        dynamic_text_candidate = nil
        dynamic_text_due_ms = nil
    end
    if not modal_focus_blocked and main_menu_tooltip_due_ms
            and now_ms >= main_menu_tooltip_due_ms then
        if main_menu_tooltip and main_menu_tooltip ~= "" then
            speak(main_menu_tooltip)
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
    log("[pes-a11y-menu-string] focus-snapshot " .. table.concat(parts, " "))
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
    for widget_key, entry in pairs(ui_focus_widgets) do
        if readable(entry.address + 0xf0, 0x30) then
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
    if dense_virtual_list then
        -- 0x104 is the actual selected row. 0x100 is the previous row: for
        -- example, while the game selects LaLiga 2 it still exposes LaLiga at
        -- 0x100. This applies to clubs and also avoids stale "Confirmar" rows.
        selected_offset_index = 1
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
    local candidate_key = selected_entry and (
        (dense_virtual_list and "virtual-list:" or selected_key .. ":") ..
        selected_entry.text) or nil
    local selected_is_modal_button = selected_entry
        and is_modal_button(selected_entry.text)
    local changed_after_message = modal_focus_blocked
        and selected_offset_index
        and selected_seen[selected_offset_index] > modal_message_spoken_frame + 2
    -- Keep the initial item silent after an instructional paragraph. There is
    -- no reliable NVDA completion callback here. A real arrow movement changes
    -- the focus after the paragraph began and is announced immediately.
    if candidate_key and modal_focus_blocked and not changed_after_message then
        last_ui_focus_announcement = candidate_key
    end
    local startup_focus_allowed = selected_entry and startup_complete
        and frame - startup_completed_frame >= 12
    if candidate_key ~= ui_focus_candidate_key then
        log_focus_snapshot(counts, selected, selected_seen)
        ui_focus_candidate_key = candidate_key
        ui_focus_candidate_since = frame
    elseif candidate_key and frame - ui_focus_candidate_since >= 12
            and (not modal_focus_blocked or changed_after_message)
            and startup_focus_allowed
            and not dense_virtual_list
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
            "[pes-a11y-menu-string] ui-focus offset=0x%x widget=%s text=%q",
            selected_offset,
            selected_key,
            selected_entry.text))
        ui_focus_preferred_offset_index = selected_offset_index
        local selected_control = control_rows_by_label_widget[selected_key]
        if selected_control
                and selected_control.label ~= selected_entry.text then
            selected_control = nil
        end
        local handled_control = false
        if selected_control and selected_control.is_control then
            announce_control(selected_control)
            handled_control = true
        elseif active_control_row
                and not active_control_row.native_slider
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
                    "[pes-a11y-menu-string] side-auxiliary-suppressed text=%q",
                    selected_entry.text))
            else
                end_side_screen()
                speak(ui_focus_speech(selected_entry.text))
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
    if not bridge_started and frame >= 120 then
        bridge_started = true
        start_speech_bridge(ctx)
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
    local now_ms = tonumber(ffi.C.GetTickCount64())
    local startup_busy = process_startup_speech(now_ms)
    if not startup_busy and pending_message_due_ms
            and now_ms >= pending_message_due_ms then
        if pending_message_text and pending_message_text ~= ""
                and pending_message_key ~= last_announced_message_key then
            speak(pending_message_text)
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
    local modal_focus_blocked = startup_busy
        or pending_message_text ~= nil
        or now_ms < modal_focus_hold_until_ms
    local dialog_active = false
    -- Dialog buttons use the same unified focus reader as every other item.
    -- A separate dialog scanner kept stale Sim/Não widgets alive after the
    -- modal had closed and competed with the next screen.
    -- Do not mix the current UI-state reader with the legacy localization
    -- fallback. Hidden widgets retain their old focus bit after a transition,
    -- so the fallback can overwrite a correct announcement with an item from
    -- the previous screen (for example "Partida local" on the league list).
    scan_current_ui_focus(modal_focus_blocked, dialog_active)

    -- Delayed speech is evaluated after focus. A newly focused item can then
    -- cancel an obsolete tooltip before it reaches the screen reader.
    process_delayed_speech(now_ms, modal_focus_blocked)
end

function m.context_reset(ctx)
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
    dialog_options = {}
    dialog_signature = nil
    dialog_preferred_offset = nil
    dialog_focus_candidate = nil
    dialog_focus_candidate_since = 0
    last_dialog_announcement = nil
    reset_message_state()
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
    last_audio_id = nil
    last_focused_id = nil
    focus_candidate_id = nil
    last_announced_focus_key = nil
    reset_side_state()
    last_widget_frame = frame
    log("[pes-a11y-menu-string] context-reset")
end

local function install_probe(ctx)
    local target = process_base + RESOLVED_TEXT_RVA
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[pes-a11y-menu-string] probe=%s reused-existing-hook target=%s",
            VERSION,
            memory.hex(target)))
        return
    end
    memory.guard(target, #ORIGINAL_PROLOGUE, "b", ORIGINAL_PROLOGUE)

    local event_id = ctx.get_event_id("custom:pes_a11y_resolved_text")
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
        "[pes-a11y-menu-string] probe=%s target=%s codecave=%s mode=resolved-text",
        VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

local function install_event_probe(ctx, rva, prologue, event_name, label)
    local target = process_base + rva
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[pes-a11y-menu-string] %s=%s reused-existing-hook target=%s",
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
        "[pes-a11y-menu-string] %s=%s target=%s codecave=%s",
        label,
        VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

local function install_slider_probes(ctx)
    install_event_probe(
        ctx, SLIDER_INIT_RVA, SLIDER_INIT_PROLOGUE,
        "custom:pes_a11y_slider_init", "slider-init-probe")
    install_event_probe(
        ctx, SLIDER_SET_RVA, SLIDER_SET_PROLOGUE,
        "custom:pes_a11y_slider_set", "slider-set-probe")
end

local function install_selector_probes(ctx)
    install_event_probe(
        ctx, UI_TEXT_SET_RVA, UI_TEXT_SET_PROLOGUE,
        "custom:pes_a11y_ui_text_set", "ui-text-set-probe")
    install_event_probe(
        ctx, GAME_TEXT_LANGUAGE_SET_RVA, LANGUAGE_SET_PROLOGUE,
        "custom:pes_a11y_game_text_language_set", "game-text-language-probe")
    install_event_probe(
        ctx, COMMENTARY_LANGUAGE_SET_RVA, LANGUAGE_SET_PROLOGUE,
        "custom:pes_a11y_commentary_language_set", "commentary-language-probe")
    install_event_probe(
        ctx, GAME_TEXT_LANGUAGE_NAV_RVA, LANGUAGE_NAV_PROLOGUE,
        "custom:pes_a11y_game_text_language_nav", "game-text-language-nav-probe")
end

local function install_list_probe(ctx)
    install_event_probe(
        ctx, LIST_ITEM_RENDER_RVA, LIST_ITEM_RENDER_PROLOGUE,
        "custom:pes_a11y_list_item_render", "list-item-render-probe")
    install_event_probe(
        ctx, TEAM_ITEM_TEXT_A_RVA, TEAM_ITEM_TEXT_PROLOGUE,
        "custom:pes_a11y_team_item_text", "team-item-text-a-probe")
    install_event_probe(
        ctx, TEAM_ITEM_TEXT_B_RVA, TEAM_ITEM_TEXT_PROLOGUE,
        "custom:pes_a11y_team_item_text", "team-item-text-b-probe")
end


function m.init(ctx)
    if not ctx.custom_evt_rbx then
        error("Sider custom events are unavailable")
    end
    process_base = memory.get_process_info().base
    process_base_u64 = ffi.cast("uint64_t", process_base)
    speech_path = ctx.sider_dir .. "\\pes_a11y_speech.txt"
    local speech_file = io.open(speech_path, "wt")
    if speech_file then
        speech_file:close()
    end
    ctx.register("custom:pes_a11y_resolved_text", m.on_resolved_text)
    ctx.register("custom:pes_a11y_slider_init", m.on_slider_init)
    ctx.register("custom:pes_a11y_slider_set", m.on_slider_set)
    ctx.register("custom:pes_a11y_ui_text_set", m.on_ui_text_set)
    ctx.register("custom:pes_a11y_list_item_render", m.on_list_item_render)
    ctx.register("custom:pes_a11y_team_item_text", m.on_team_item_text)
    ctx.register("custom:pes_a11y_game_text_language_set", m.on_game_text_language_set)
    ctx.register("custom:pes_a11y_commentary_language_set", m.on_commentary_language_set)
    ctx.register("custom:pes_a11y_game_text_language_nav", m.on_game_text_language_nav)
    ctx.register("display_frame", m.display_frame)
    ctx.register("context_reset", m.context_reset)
    install_probe(ctx)
    install_slider_probes(ctx)
    install_selector_probes(ctx)
    install_list_probe(ctx)
end

return m
