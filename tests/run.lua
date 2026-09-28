-- Offline FLAccess behavioral tests. Real game memory and Prism output are not
-- certified by this harness; those boundaries are covered by the manual plan.
local module_path = assert(arg[1], "FLAccess.lua path required")
local sider_dir = assert(arg[2], "SiderAddons path required")
local ffi = require("ffi")
local logs = {}
local host = {
    assert=assert, table=table, pairs=pairs, ipairs=ipairs, string=string,
    math=math, tonumber=tonumber, tostring=tostring, unpack=unpack,
    error=error, _VERSION=_VERSION, type=type, io=io,
    collectgarbage=collectgarbage, jit=jit,
    os={time=os.time, clock=os.clock, date=os.date}, ffi=ffi,
    log=function(message) logs[#logs + 1] = message end,
}
host._G = host
host.memory = {
    get_process_info=function() return {base=0} end,
    read=function(_, size) return string.rep("\x90", size) end,
    guard=function() end,
    allocate_codecave=function() return 0x70000000 end,
    pack=function(kind) return string.rep("\0", kind == "u16" and 2 or 8) end,
    write=function() end,
    hex=tostring,
    unpack=function() return 0 end,
}

local chunk = assert(loadfile(module_path))
setfenv(chunk, host)
local module = assert(chunk())

local function upvalue(fn, wanted)
    for index = 1, 200 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then return value, index end
    end
    error("upvalue missing: " .. wanted)
end

local function set_upvalue(fn, wanted, value)
    local _, index = upvalue(fn, wanted)
    debug.setupvalue(fn, index, value)
end

local a11y = upvalue(module.init, "a11y")
a11y.sider_dir = sider_dir
assert(a11y.load_text_assets(), "runtime lexicons missing")
local speak = upvalue(module.key_down, "speak")
set_upvalue(speak, "game_is_foreground", function() return true end)
set_upvalue(module.display_frame, "game_is_foreground",
    function() return true end)
local remember_message = upvalue(a11y.poll_direct_message_update,
    "remember_message_text")
local looks_like_message = upvalue(remember_message, "looks_like_message")
local is_modal_button = upvalue(remember_message, "is_modal_button")
local clean_text = upvalue(module.on_resolved_text, "clean_text")

local checks = 0
local function speech_texts()
    local result = {}
    for index = a11y.native_speech_first, a11y.native_speech_last do
        result[#result + 1] = a11y.native_speech_queue[index].text
    end
    return result
end
local function with_render_harness(fn)
    local output = {}
    local old_init, old_refresh = a11y.initialize_native_prism,
        a11y.refresh_native_prism
    local names = {
        "prism_started", "game_was_foreground", "foreground_resume_frame",
        "process_startup_speech", "scan_current_ui_focus",
        "process_delayed_speech",
    }
    local originals = {}
    for _, name in ipairs(names) do
        originals[name] = upvalue(module.display_frame, name)
    end
    a11y.initialize_native_prism = function() return true end
    a11y.refresh_native_prism = function() return true end
    a11y.prism_backend = {}
    a11y.prism_backend_name = "test"
    a11y.prism_functions = {backend_speak=function(_, text, interrupt)
        output[#output + 1] = {ffi.string(text), interrupt}
        return 0
    end}
    set_upvalue(module.display_frame, "prism_started", true)
    set_upvalue(module.display_frame, "game_was_foreground", true)
    set_upvalue(module.display_frame, "foreground_resume_frame", 0)
    set_upvalue(module.display_frame, "process_startup_speech",
        function() return false end)
    set_upvalue(module.display_frame, "scan_current_ui_focus",
        function() return false end)
    set_upvalue(module.display_frame, "process_delayed_speech", function() end)
    fn(output)
    a11y.initialize_native_prism = old_init
    a11y.refresh_native_prism = old_refresh
    for _, name in ipairs(names) do
        set_upvalue(module.display_frame, name, originals[name])
    end
end
local function check(name, fn)
    module.context_reset({})
    a11y.native_speech_queue = {}
    a11y.native_speech_first = 1
    a11y.native_speech_last = 0
    a11y.ui_language = "pt"
    a11y.use_text_assets = true
    a11y.read_tooltips = true
    set_upvalue(speak, "last_spoken_text", nil)
    fn()
    checks = checks + 1
    print("PASS " .. name)
end

check("localization roles and language isolation", function()
    assert(a11y.text_asset_role("Configurações de volume") == "control")
    assert(a11y.text_asset_role("Cancelar") == "dialog-button")
    a11y.ui_language = "en"
    assert(a11y.text_asset_role("Cancel") == "dialog-button")
    assert(a11y.text_asset_role("Configurações de volume") == nil)
    a11y.use_text_assets = false
    assert(a11y.text_asset_role("Cancel") == nil)
end)

check("text cleaning retains spoken controller markers", function()
    assert(clean_text("  Segure \17ka e \17jm.\r\n") ==
        "Segure botão A e analógico esquerdo.")
    a11y.ui_language = "en"
    assert(clean_text("Hold \17ka and \17jm.\t") ==
        "Hold A button and left stick.")
end)

check("noninteractive status never becomes dialog", function()
    assert(a11y.text_asset_role("Carregando a bola") == "status")
    assert(not looks_like_message("Carregando a bola"))
    assert(not looks_like_message("Dados do sistema"))
    assert(not looks_like_message("Conectar ao servidor agora."))
end)

check("catalog and heuristic recognize instructions", function()
    assert(a11y.is_instruction_message("Enquanto segura o botão A, mova o jogador."))
    assert(a11y.is_instruction_message("While holding A, move the player."))
    assert(not a11y.is_instruction_message("Configurações de volume"))
end)

check("modal buttons and ordinary controls remain distinct", function()
    assert(is_modal_button("Cancelar"))
    assert(is_modal_button("OK"))
    assert(is_modal_button("Concordo."))
    assert(not is_modal_button("Configurações de volume"))
    assert(not looks_like_message("Configurações de volume"))
end)

check("control help is a delayed tooltip, never a modal paragraph", function()
    local label_from_help = upvalue(remember_message,
        "control_label_from_tooltip")
    local help = "Escolha o volume de uma variedade de efeitos sonoros, inclusive os do cursor."
    assert(label_from_help(help) == "Efeitos sonoros do menu")
    assert(label_from_help("Escolha o número de usuários participantes.")
        == "Número de usuários")
    assert(label_from_help("Escolha o volume da narração e dos comentários do jogo.")
        == "Volume dos comentários")
    remember_message(help, "help-widget")
    assert(upvalue(module.display_frame, "pending_message_text") == nil)
    assert(not a11y.capture_resolved_dialog(help, 12345, 0x123456))
    assert(label_from_help(
        "As configurações de câmera que serão usadas ao assistir partidas, incluindo a grande final do Matchday.")
        == "Configurações de câmera")
end)

check("side prompt cannot become the user's control label", function()
    local non_controls = upvalue(module.on_resolved_text,
        "non_control_labels")
    assert(non_controls["Conecte o controle."])
    assert(non_controls["Connect the controller."])
end)

check("side selector does not repeat an unchanged position", function()
    local scan = upvalue(module.display_frame, "scan_current_ui_focus")
    local begin_side = upvalue(scan, "begin_side_screen")
    begin_side(1, "home-widget", "Usuário 1")
    begin_side(nil, "home-widget", "Usuário 1")
    begin_side(2, "neutral-widget", "Usuário 1")
    begin_side(1, "home-widget", "Usuário 1")
    local texts = speech_texts()
    assert(#texts == 3)
    assert(texts[1] == "Usuário 1, Em casa, selecionado")
    assert(texts[2] == "Usuário 1, Neutro, selecionado")
    assert(texts[3] == "Usuário 1, Em casa, selecionado")
end)

check("presentation paragraph without UI widget enters dialog queue", function()
    local message = "Há muitas escolhas na carreira de um jogador de futebol. Talvez você prefira ser o defensor leal das cores do seu time de infância, ou então buscar novos ares e novas conquistas em um grande clube. Qual caminho você vai seguir?"
    assert(a11y.text_asset_role(message) == "dialog")
    assert(a11y.capture_resolved_dialog(message, 8094, 0x123456))
    assert(upvalue(module.display_frame, "pending_message_text") == message)
    assert(not a11y.capture_resolved_dialog(
        "Escolha sua aparência", 6716, 0x123456))
end)

check("parameterized dialog role matches rendered player name", function()
    local message = "A atuação do João na última partida chamou a atenção. Isso é resultado da confiança que ele adquiriu durante a pré-temporada?"
    assert(a11y.text_asset_role(message) == "dialog")
end)

check("catalogued imperative heading is an automatic screen title", function()
    local announce = upvalue(module.on_ui_text_set, "announce_screen_title")
    local is_title = upvalue(announce, "is_screen_title")
    assert(is_title("Escolha sua aparência"))
    assert(not is_title("Nome do treinador"))
    assert(not is_title("Escolha a frequência das transferências dos times do COMP. Quando \"Muito alta\", haverá uma grande quantidade de transferências."))
end)

check("structural title needs no imperative wording", function()
    local announce = upvalue(module.on_ui_text_set, "announce_screen_title")
    local is_title = upvalue(announce, "is_screen_title")
    local original = a11y.widget_internal_name
    a11y.widget_internal_name = function() return "title" end
    assert(is_title("Opções de técnico", 0x100000))
    assert(is_title("Regras", 0x100000))
    a11y.widget_internal_name = function() return "text_title" end
    assert(is_title("Lista de jogadores", 0x100000))
    a11y.widget_internal_name = function() return "text" end
    assert(not is_title("Regras", 0x100000))
    a11y.widget_internal_name = original
end)

check("automatic first focus queues behind screen title", function()
    local announce = upvalue(module.on_ui_text_set, "announce_screen_title")
    announce("Escolha sua aparência", "appearance-title")
    speak("Luis Figo, item selecionado")
    assert(a11y.native_speech_last == 2)
    assert(a11y.native_speech_queue[1].text == "Escolha sua aparência")
    assert(a11y.native_speech_queue[1].interrupt)
    assert(a11y.native_speech_queue[2].text == "Luis Figo, item selecionado")
    assert(not a11y.native_speech_queue[2].interrupt)
end)

check("dialog capture preserves queued title but drops old focus", function()
    local announce = upvalue(module.on_ui_text_set, "announce_screen_title")
    local queue_message = upvalue(remember_message, "queue_recent_message")
    announce("Escolha sua aparência", "title-widget")
    speak("Old selection, item selecionado")
    remember_message("Insira os detalhes do treinador.", "notice-widget")
    queue_message()
    assert(a11y.native_speech_last == 1)
    assert(a11y.native_speech_queue[1].text == "Escolha sua aparência")
end)

check("skip marker announces once while game is foreground", function()
    local original = a11y.game_is_foreground
    a11y.game_is_foreground = function() return true end
    assert(a11y.announce_skip_hint("<Pular>%s"))
    assert(a11y.native_speech_last == 1)
    assert(a11y.native_speech_queue[1].text ==
        "Pressione Options para pular.")
    assert(not a11y.announce_skip_hint("<Pular>%s"))
    assert(a11y.native_speech_last == 1)
    a11y.game_is_foreground = function() return false end
    a11y.skip_hint_last_frame = -10000
    assert(not a11y.announce_skip_hint("<Pular>%s"))
    a11y.game_is_foreground = original
end)

check("control value cannot be a button or unrelated list item", function()
    local original = a11y.widget_internal_name
    a11y.widget_internal_name = function() return "text" end
    assert(a11y.valid_control_value(0x100000, "1"))
    assert(not a11y.valid_control_value(0x100000, "OK"))
    assert(not a11y.valid_control_value(0x100000, "Voltar"))
    a11y.widget_internal_name = function() return "listName" end
    assert(not a11y.valid_control_value(0x100000, "UEFA EURO"))
    a11y.widget_internal_name = original
end)

check("unchanged focus widget does not become new after a pause", function()
    local old_frame = upvalue(a11y.focus_widget_reused, "frame")
    set_upvalue(a11y.focus_widget_reused, "frame", 100)
    local previous = {text="Informações", last_seen=10}
    assert(not a11y.focus_widget_reused(previous, "Informações"))
    assert(a11y.focus_widget_reused(previous, "Nova opção"))
    set_upvalue(a11y.focus_widget_reused, "frame", old_frame)
end)

check("Game Plan reentry requires an explicit selection", function()
    local input = a11y.record_game_plan_input
    local previous = upvalue(input, "last_selected_ui_entry")
    set_upvalue(input, "last_selected_ui_entry", {text="Plano de jogo"})
    input("A", "test")
    assert(a11y.game_plan_entry_requested)
    input("B", "test")
    assert(not a11y.game_plan_entry_requested)
    set_upvalue(input, "last_selected_ui_entry", previous)
end)

check("tournament values pair by structural field name", function()
    local old_name = a11y.widget_internal_name
    local names = {
        [0x110000]="groupStage_item",
        [0x120000]="groupStage_value",
        [0x130000]="third_value",
        [0x140000]="listName",
    }
    a11y.widget_internal_name = function(widget) return names[widget] end
    local register = upvalue(module.on_resolved_text,
        "register_control_label")
    local attach = upvalue(module.on_ui_text_set,
        "attach_control_value")
    local row = register("Fase de grupos", 0x110000, "seletor", true)
    assert(a11y.structural_control_row(0x120000) == row)
    assert(a11y.structural_control_row(0x130000) == nil)
    assert(not attach(row, 0x130000, "Desl."))
    assert(not attach(row, 0x140000, "UEFA EURO"))
    assert(attach(row, 0x120000, "Lig."))
    assert(row.value == "Lig.")
    a11y.widget_internal_name = old_name
end)

check("player names and record prefix", function()
    assert(a11y.normalized_player_name("  11  Ibrahima Konaté  ") ==
        "Ibrahima Konaté")
    a11y.game_plan_player_cache["Ibrahima Konat"] = {position="CB"}
    assert(a11y.player_for_text("11 Ibrahima Konaté").position == "CB")
    assert(a11y.player_for_text("11 Unknown Player") == nil)
end)

check("diagnostic role prefers native widget mapping", function()
    local role = a11y.diagnostic_role("unknown", {text="Configurações de volume"})
    assert(role == "control")
    role = a11y.diagnostic_role("unknown", {text="Cancelar"})
    assert(role == "dialog-button")
end)

check("widget structural name is validated before diagnostics", function()
    local original = a11y.read_msvc_string
    a11y.read_msvc_string = function(address)
        assert(address == 0x100018)
        return "teamName"
    end
    assert(a11y.widget_internal_name(0x100000) == "teamName")
    a11y.read_msvc_string = function() return "corrupted widget name!" end
    assert(a11y.widget_internal_name(0x100000) == nil)
    assert(a11y.widget_internal_name(0) == nil)
    a11y.read_msvc_string = original
end)

check("structural group header hides the trailing grid OK early", function()
    local original = a11y.widget_internal_name
    a11y.widget_internal_name = function() return "groupName" end
    assert(a11y.is_cup_group_header(0x100000, "Grupo A"))
    assert(a11y.is_cup_group_header(0x100000, "Group H"))
    assert(not a11y.is_cup_group_header(0x100000, "OK"))
    a11y.widget_internal_name = function() return "text" end
    assert(not a11y.is_cup_group_header(0x100000, "Grupo A"))
    a11y.widget_internal_name = original
    a11y.activate_cup_group_table(false)
    assert(a11y.ignore_cup_group_focus("OK"))
    assert(not a11y.ignore_cup_group_focus("Galatasaray SK"))
end)

check("slider value preserves range in focus announcement", function()
    local format = upvalue(module.on_slider_set, "formatted_slider_value")
    assert(format({minimum=0, maximum=15}, 7) == "7 de 15")
    assert(format({minimum=-2, maximum=2}, -1) == "-1")
    local control_speech = upvalue(module.on_slider_set, "control_speech")
    assert(control_speech({label="Volume", role="controle deslizante",
        value="7 de 15"}) == "Volume, controle deslizante, 7 de 15")
end)

check("overlay change speaks selected row only", function()
    local old = "---> Audio <---\nKeys: arrows\nMusic: 4"
    local new = "Audio\nKeys: arrows\n---> Music: 5 <---"
    assert(a11y.changed_overlay_text(old, new) == "Music: 5")
    assert(a11y.changed_overlay_text(new, new) == "Music: 5")
end)

check("overlay duplicate lines do not become updates", function()
    local old = "Item\nItem\n---> Chosen <---"
    local new = "Item\n---> Chosen <---\nItem"
    assert(a11y.changed_overlay_text(old, new) == "Chosen")
end)

check("native queue preserves order, mode, and deduplication", function()
    speak("Mensagem longa")
    speak("OK, botão selecionado", false)
    speak("OK, botão selecionado", false)
    assert(a11y.native_speech_last == 2)
    assert(a11y.native_speech_queue[1].interrupt == true)
    assert(a11y.native_speech_queue[2].interrupt == false)
    assert(a11y.native_speech_queue[1].sequence <
        a11y.native_speech_queue[2].sequence)
end)

check("active dialog coalesces rapid focus then queues latest", function()
    local old_hold = upvalue(speak, "modal_focus_hold_until_ms")
    set_upvalue(speak, "modal_focus_hold_until_ms",
        tonumber(ffi.C.GetTickCount64()) + 10000)
    speak("Foco antigo durante o diálogo")
    speak("Foco novo durante o diálogo")
    assert(a11y.native_speech_last == 0)
    assert(a11y.deferred_modal_announcement ==
        "Foco novo durante o diálogo")
    set_upvalue(speak, "modal_focus_hold_until_ms", 0)
    with_render_harness(function(output)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 1)
        assert(output[1][1] == "Foco novo durante o diálogo")
        assert(output[1][2] == false)
    end)
    set_upvalue(speak, "modal_focus_hold_until_ms", old_hold)
end)

check("explicit confirm releases completed dialog but not tutorial", function()
    local input = a11y.record_game_plan_input
    local scan = upvalue(module.display_frame, "scan_current_ui_focus")
    local now = tonumber(ffi.C.GetTickCount64())
    set_upvalue(input, "modal_focus_hold_until_ms", now + 10000)
    a11y.last_modal_message_text =
        "O seu contrato será renovado anualmente e ofertas de outros clubes podem chegar na mesma época, dando a chance de se transferir."
    input("left", "keyboard")
    assert(upvalue(input, "modal_focus_hold_until_ms") > now)
    set_upvalue(scan, "last_ui_focus_announcement", "trainer-name")
    input("A", "keyboard")
    assert(upvalue(input, "modal_focus_hold_until_ms") == 0)
    assert(upvalue(scan, "last_ui_focus_announcement") == nil)
    set_upvalue(input, "modal_focus_hold_until_ms", now + 10000)
    a11y.last_modal_message_text =
        "Enquanto segura o botão A, escolha a posição desejada."
    input("A", "keyboard")
    assert(upvalue(input, "modal_focus_hold_until_ms") > now)
    set_upvalue(input, "modal_focus_hold_until_ms", 0)
end)

check("fresh navigation after paused modal reading restores focus", function()
    local input = a11y.record_game_plan_input
    local scan = upvalue(module.display_frame, "scan_current_ui_focus")
    local old_hold = upvalue(input, "modal_focus_hold_until_ms")
    local old_spoken_frame = upvalue(input, "modal_message_spoken_frame")
    local old_last_focus = upvalue(scan, "last_ui_focus_announcement")
    local now = tonumber(ffi.C.GetTickCount64())
    set_upvalue(input, "modal_focus_hold_until_ms", now + 10000)
    set_upvalue(input, "modal_message_spoken_frame", -1)
    set_upvalue(scan, "last_ui_focus_announcement", "old-focus")
    a11y.last_modal_message_text = "Mensagem de confirmação completa."
    input("left", "keyboard")
    assert(upvalue(input, "modal_focus_hold_until_ms") > now)
    a11y.modal_navigation_last_ms = now - 700
    input("right", "keyboard")
    assert(upvalue(input, "modal_focus_hold_until_ms") == 0)
    assert(upvalue(scan, "last_ui_focus_announcement") == nil)
    assert(a11y.last_modal_message_text == nil)
    set_upvalue(input, "modal_focus_hold_until_ms", old_hold)
    set_upvalue(input, "modal_message_spoken_frame", old_spoken_frame)
    set_upvalue(scan, "last_ui_focus_announcement", old_last_focus)
end)

check("NVDA navigation stops modal speech on first move only", function()
    local input = a11y.record_game_plan_input
    local old_hold = upvalue(input, "modal_focus_hold_until_ms")
    local old_name, old_backend, old_functions =
        a11y.prism_backend_name, a11y.prism_backend, a11y.prism_functions
    local now = tonumber(ffi.C.GetTickCount64())
    set_upvalue(input, "modal_focus_hold_until_ms", now + 10000)
    a11y.prism_backend_name = "NVDA"
    a11y.prism_backend = {}
    local stopped = 0
    a11y.prism_functions = {backend_stop=function()
        stopped = stopped + 1
        return 0
    end}
    input("right", "gamepad")
    assert(upvalue(input, "modal_focus_hold_until_ms") == 0)
    assert(a11y.nvda_stop_requested)
    a11y.stop_nvda_if_requested()
    assert(stopped == 1 and not a11y.nvda_stop_requested)
    input("right", "gamepad")
    a11y.stop_nvda_if_requested()
    assert(stopped == 1)
    a11y.prism_backend_name, a11y.prism_backend,
        a11y.prism_functions = old_name, old_backend, old_functions
    set_upvalue(input, "modal_focus_hold_until_ms", old_hold)
end)

check("any new confirmation can arm fresh yes-no focus", function()
    local frame = upvalue(module.display_frame, "frame")
    local queue_message = upvalue(remember_message, "queue_recent_message")
    remember_message("As configurações não serão salvas.", "cup-confirm")
    queue_message()
    assert(a11y.modal_dialog_start_frame == frame)
    assert(a11y.confirmation_dialog_until_frame == frame + 900)
end)

check("Game Plan prompt does not enter stale player submenu", function()
    a11y.game_plan_active = true
    a11y.game_plan_main_surface = true
    a11y.game_plan_context = "Plano de jogo normal"
    a11y.game_plan_last_menu_focus = "Escalação/Editar posição"
    a11y.game_plan_basic_prompt_active = true
    a11y.record_game_plan_input("A", "keyboard")
    assert(a11y.game_plan_context == "Plano de jogo normal")
    assert(a11y.game_plan_main_surface)
    a11y.game_plan_selected_heading = "25  Giorgi Mamardashvili"
    a11y.game_plan_selected_heading_due_frame = -1
    assert(not a11y.process_game_plan_selected_heading(false))
end)

check("Game Plan confirmation releases prompt-only focus", function()
    local input = a11y.record_game_plan_input
    local old_selected = upvalue(input, "last_selected_ui_entry")
    set_upvalue(input, "last_selected_ui_entry", {text="Usar"})
    a11y.game_plan_active = true
    a11y.game_plan_context = "Menu de configuração básica"
    a11y.game_plan_basic_prompt_active = true
    a11y.game_plan_last_menu_focus = "Escalação/Editar posição"
    input("A", "keyboard")
    assert(not a11y.game_plan_basic_prompt_active)
    assert(a11y.game_plan_last_menu_focus == nil)
    assert(a11y.game_plan_context == "Menu de configuração básica")
    set_upvalue(input, "last_selected_ui_entry", old_selected)
end)

check("Game Plan command wins over refreshed background player", function()
    local scan = upvalue(module.display_frame, "scan_current_ui_focus")
    local names = {
        "frame", "ui_focus_widgets", "ui_focus_widget_count",
        "ui_focus_state", "ui_focus_activated", "readable",
        "startup_complete", "startup_completed_frame",
    }
    local saved = {}
    for _, name in ipairs(names) do saved[name] = upvalue(scan, name) end
    local old_read, old_unpack = host.memory.read, host.memory.unpack
    local function focused_bytes(offset)
        local bytes = {}
        for index = 1, 0x30 do bytes[index] = "\0" end
        bytes[offset - 0xf0 + 1] = "\1"
        return table.concat(bytes)
    end
    host.memory.read = function(address, size)
        if address == 0x10000 + 0xf0 then
            return focused_bytes(0x104)
        elseif address == 0x20000 + 0xf0 then
            return focused_bytes(0xf4)
        end
        return old_read(address, size)
    end
    host.memory.unpack = function(kind, bytes)
        if kind == "u32" then return string.byte(bytes, 1) or 0 end
        return old_unpack(kind, bytes)
    end
    set_upvalue(scan, "readable", function() return true end)
    set_upvalue(scan, "frame", 100)
    set_upvalue(scan, "startup_complete", true)
    set_upvalue(scan, "startup_completed_frame", 0)
    set_upvalue(scan, "ui_focus_widgets", {
        player={text="Giorgi Mamardashvili", address=0x10000,
            last_seen=100},
        command={text="Escalação/Editar posição", address=0x20000,
            last_seen=90},
    })
    set_upvalue(scan, "ui_focus_widget_count", 2)
    set_upvalue(scan, "ui_focus_state", {})
    set_upvalue(scan, "ui_focus_activated", {})
    a11y.game_plan_active = true
    a11y.game_plan_main_surface = true
    a11y.game_plan_context = "Plano de jogo normal"
    a11y.navigation_frame = 100
    a11y.navigation_action = "down"
    scan(false, false)
    local texts = speech_texts()
    assert(#texts > 0 and texts[#texts]:find(
        "Escalação/Editar posição", 1, true))
    host.memory.read, host.memory.unpack = old_read, old_unpack
    for _, name in ipairs(names) do
        set_upvalue(scan, name, saved[name])
    end
end)

check("Game Plan basic menu survives an old focus edge", function()
    local scan = upvalue(module.display_frame, "scan_current_ui_focus")
    local names = {
        "frame", "ui_focus_widgets", "ui_focus_widget_count",
        "ui_focus_state", "ui_focus_activated", "readable",
        "startup_complete", "startup_completed_frame",
    }
    local saved = {}
    for _, name in ipairs(names) do saved[name] = upvalue(scan, name) end
    local old_read, old_unpack = host.memory.read, host.memory.unpack
    host.memory.read = function(address, size)
        if address == 0x30000 + 0xf0 then
            local bytes = {}
            for index = 1, 0x30 do bytes[index] = "\0" end
            bytes[0x104 - 0xf0 + 1] = "\1"
            return table.concat(bytes)
        end
        return old_read(address, size)
    end
    host.memory.unpack = function(kind, bytes)
        if kind == "u32" then return string.byte(bytes, 1) or 0 end
        return old_unpack(kind, bytes)
    end
    set_upvalue(scan, "readable", function() return true end)
    set_upvalue(scan, "frame", 300)
    set_upvalue(scan, "startup_complete", true)
    set_upvalue(scan, "startup_completed_frame", 0)
    set_upvalue(scan, "ui_focus_widgets", {
        command={text="Táticas predefinidas", address=0x30000,
            last_seen=300},
    })
    set_upvalue(scan, "ui_focus_widget_count", 1)
    set_upvalue(scan, "ui_focus_state", {command={[1]=1}})
    set_upvalue(scan, "ui_focus_activated", {command={[1]=100}})
    a11y.game_plan_active = true
    a11y.game_plan_main_surface = false
    a11y.game_plan_basic_prompt_active = false
    a11y.game_plan_context = "Menu de configuração básica"
    a11y.navigation_frame = 300
    a11y.navigation_action = "down"
    scan(false, false)
    local texts = speech_texts()
    assert(#texts > 0 and texts[#texts]:find(
        "Táticas predefinidas", 1, true))
    host.memory.read, host.memory.unpack = old_read, old_unpack
    for _, name in ipairs(names) do
        set_upvalue(scan, name, saved[name])
    end
end)

check("Game Plan rotating text reads first-entry choices", function()
    local probe = a11y.record_game_plan_menu_probe
    local old_frame = upvalue(probe, "frame")
    local old_widgets = upvalue(probe, "ui_focus_widgets")
    local old_name = a11y.widget_internal_name
    local old_diag = a11y.diagnostic_mode
    a11y.widget_internal_name = function() return "text" end
    a11y.diagnostic_mode = false
    a11y.game_plan_active = true
    a11y.game_plan_context = "Menu de configuração básica"
    a11y.game_plan_basic_prompt_active = true
    a11y.game_plan_title_widgets = {}
    a11y.game_plan_last_focus_text = nil
    a11y.game_plan_announced_context = nil
    set_upvalue(probe, "frame", 103)
    set_upvalue(probe, "ui_focus_widgets", {
        cycling={text="Plano de jogo normal", address=0x30000,
            last_seen=100},
    })
    a11y.game_plan_menu_probe_due_frame = 103
    probe()
    assert(not a11y.game_plan_basic_prompt_active)
    assert(a11y.game_plan_last_menu_focus == "Plano de jogo normal")
    local texts = speech_texts()
    assert(#texts > 0 and texts[#texts]:find(
        "Plano de jogo normal", 1, true))
    set_upvalue(probe, "frame", 123)
    set_upvalue(probe, "ui_focus_widgets", {
        cycling={text="Escalação/Editar posição", address=0x30000,
            last_seen=120},
    })
    a11y.game_plan_menu_probe_due_frame = 123
    probe()
    assert(a11y.game_plan_last_menu_focus == "Escalação/Editar posição")
    texts = speech_texts()
    assert(texts[#texts]:find("Escalação/Editar posição", 1, true))
    a11y.widget_internal_name = old_name
    a11y.diagnostic_mode = old_diag
    set_upvalue(probe, "frame", old_frame)
    set_upvalue(probe, "ui_focus_widgets", old_widgets)
end)

check("redrawn pre-match notice does not requeue over navigation", function()
    local notice = "A partida começará quando os dois times estiverem prontos. Aguarde."
    remember_message(notice, "first-notice")
    assert(upvalue(module.display_frame, "pending_message_text") == notice)
    remember_message(notice, "redrawn-notice")
    assert(#a11y.modal_message_backlog == 0)
end)

check("pending dialog blocks every early speech route", function()
    local message = "A configuração atual será substituída quando esta mensagem terminar. Confirme depois de ouvir todas as opções."
    remember_message(message, "dialog-text")
    speak("Cancelar, item selecionado")
    assert(a11y.native_speech_last == 0)
    assert(a11y.deferred_modal_announcement ==
        "Cancelar, item selecionado")
end)

check("modal OK is not spoken twice while paragraph is active", function()
    local message = "Escolha o clube em que você quer começar a carreira de treinador."
    remember_message(message, "club-intro")
    speak("OK, item selecionado")
    assert(a11y.native_speech_last == 0)
    with_render_harness(function(output)
        a11y.pending_modal_button_text = "OK"
        set_upvalue(module.display_frame, "pending_message_due_ms", 0)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 2)
        assert(output[1][1] == message)
        assert(output[2][1] == "Avançar, botão selecionado")
        speak("OK, item selecionado")
        assert(a11y.native_speech_last == 0)
    end)
end)

check("fast focus navigation can revisit a row without going silent", function()
    local scan = upvalue(module.display_frame, "scan_current_ui_focus")
    local names = {"frame", "ui_focus_widgets", "ui_focus_widget_count",
        "readable", "startup_complete", "startup_completed_frame"}
    local originals = {}
    for _, name in ipairs(names) do originals[name] = upvalue(scan, name) end
    local old_read, old_unpack = host.memory.read, host.memory.unpack
    local bytes = string.rep("\0", 20) .. "\1\0\0\0" ..
        string.rep("\0", 24)
    host.memory.read = function() return bytes end
    host.memory.unpack = function(_, data)
        return data == "\1\0\0\0" and 1 or 0
    end
    set_upvalue(scan, "readable", function() return true end)
    set_upvalue(scan, "startup_complete", true)
    set_upvalue(scan, "startup_completed_frame", 0)
    set_upvalue(scan, "ui_focus_widget_count", 1)
    local widgets = {row={address=0x100000,
        text="Configurações gerais", last_seen=100}}
    set_upvalue(scan, "ui_focus_widgets", widgets)
    for index, label in ipairs({"Configurações gerais",
            "Configurações de câmera", "Configurações gerais"}) do
        local tick = 98 + index * 2
        widgets.row.text = label
        widgets.row.last_seen = tick
        a11y.navigation_frame = tick
        set_upvalue(scan, "frame", tick)
        scan(false, false)
        set_upvalue(scan, "frame", tick + 1)
        widgets.row.last_seen = tick + 1
        scan(false, false)
    end
    local texts = speech_texts()
    assert(#texts == 3)
    assert(texts[1] == "Configurações gerais, item selecionado")
    assert(texts[2] == "Configurações de câmera, item selecionado")
    assert(texts[3] == "Configurações gerais, item selecionado")
    host.memory.read, host.memory.unpack = old_read, old_unpack
    for _, name in ipairs(names) do set_upvalue(scan, name, originals[name]) end
end)

check("new dialog displaces focus captured in same render slice", function()
    speak("OK, item selecionado")
    assert(a11y.native_speech_last == 1)
    remember_message(
        "Os agrupamentos da Fase de grupos podem ser definidos livremente.",
        "cup-message")
    assert(a11y.native_speech_last == 0)
    assert(upvalue(module.display_frame, "pending_message_text") ~= nil)
end)

check("split confirmation replaces pending prefix", function()
    local queue_message = upvalue(remember_message, "queue_recent_message")
    local first = "Se você voltar à tela anterior, suas configurações de Plano de jogo e Uniforme"
    local full = first .. " serão perdidas."
    remember_message(first, "confirmation-widget")
    queue_message()
    assert(upvalue(module.display_frame, "pending_message_text") == first)
    remember_message("serão perdidas.", "confirmation-widget")
    assert(upvalue(module.display_frame, "pending_message_text") == full)
    assert(#a11y.modal_message_backlog == 0)
end)

check("native output receives message before queued button", function()
    local output = {}
    local old_init, old_refresh = a11y.initialize_native_prism,
        a11y.refresh_native_prism
    a11y.initialize_native_prism = function() return true end
    a11y.refresh_native_prism = function() return true end
    a11y.prism_backend = {}
    a11y.prism_backend_name = "test"
    a11y.prism_functions = {backend_speak=function(_, text, interrupt)
        output[#output + 1] = {text=ffi.string(text), interrupt=interrupt}
        return 0
    end}
    speak("Leia todo o aviso antes do controle")
    speak("OK, botão selecionado", false)
    a11y.flush_native_speech(0)
    assert(#output == 2)
    assert(output[1].text == "Leia todo o aviso antes do controle")
    assert(output[1].interrupt == true)
    assert(output[2].text == "OK, botão selecionado")
    assert(output[2].interrupt == false)
    assert(a11y.native_speech_last == 0)
    a11y.initialize_native_prism = old_init
    a11y.refresh_native_prism = old_refresh
end)

check("captured dialog reaches render frame and Prism in order", function()
    with_render_harness(function(output)
        local message = "Você quer continuar? Confirme somente depois que todo este aviso for lido por completo. As escolhas desta tela serão descartadas."
        remember_message(message, "dialog-text-widget")
        a11y.pending_modal_button_text = "Cancelar"
        set_upvalue(module.display_frame, "pending_message_due_ms", 0)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 2 and output[1][1] == message and output[1][2])
        assert(output[2][1] == "Cancelar, botão selecionado")
        assert(output[2][2] == false)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 2)
    end)
end)

check("two rapid dialog pages reach Prism in sequence", function()
    with_render_harness(function(output)
        local first = "Enquanto segura o botão A, escolha a posição desejada."
        local second = "Enquanto segura o botão A, mova para outra posição."
        remember_message(first, "tutorial-widget")
        remember_message(second, "tutorial-widget")
        assert(#a11y.modal_message_backlog == 1)
        set_upvalue(module.display_frame, "pending_message_due_ms", 0)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 1 and output[1][1] == first)
        local first_hold = upvalue(module.display_frame,
            "modal_focus_hold_until_ms")
        assert(upvalue(module.display_frame, "pending_message_text") == second)
        set_upvalue(module.display_frame, "pending_message_due_ms", 0)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 2 and output[2][1] == second)
        assert(output[2][2] == false)
        assert(upvalue(module.display_frame,
            "modal_focus_hold_until_ms") > first_hold)
    end)
end)

check("multiple dialog paragraphs speak before one advance button", function()
    with_render_harness(function(output)
        local first = "Escolha o clube em que você quer começar a carreira de treinador."
        local second = "O seu contrato será renovado anualmente e ofertas de outros clubes podem chegar na mesma época, dando a chance de se transferir."
        local queue_message = upvalue(remember_message, "queue_recent_message")
        remember_message(first, "club-intro")
        queue_message()
        remember_message(second, "club-contract")
        queue_message()
        a11y.pending_modal_button_text = "OK"
        set_upvalue(module.display_frame, "pending_message_due_ms", 0)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 1 and output[1][1] == first)
        assert(a11y.pending_modal_button_text == "OK")
        set_upvalue(module.display_frame, "pending_message_due_ms", 0)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 3)
        assert(output[2][1] == second)
        assert(output[3][1] == "Avançar, botão selecionado")
        assert(output[3][2] == false)
    end)
end)

check("Cup grid OK stays silent after introduction", function()
    with_render_harness(function(output)
        local message = "Os agrupamentos da Fase de grupos podem ser definidos livremente."
        speak("OK, item selecionado")
        assert(a11y.native_speech_last == 1)
        remember_message(message, "cup-message")
        assert(a11y.native_speech_last == 0)
        a11y.pending_modal_button_text = "OK"
        set_upvalue(module.display_frame, "pending_message_due_ms", 0)
        module.display_frame({sider_dir=sider_dir})
        assert(#output == 1 and output[1][1] == message)
        speak("OK, item selecionado")
        assert(a11y.native_speech_last == 0)
    end)
end)

check("new screen drops pending speech from previous screen", function()
    speak("Texto da tela antiga")
    assert(a11y.native_speech_last == 1)
    module.context_reset({})
    assert(a11y.native_speech_last == 0)
end)

check("confirming advance quarantines old screen focus", function()
    local record = a11y.record_game_plan_input
    local old_selected = upvalue(record, "last_selected_ui_entry")
    local old_widgets = upvalue(record, "ui_focus_widgets")
    set_upvalue(record, "last_selected_ui_entry", {text="Avançar"})
    set_upvalue(record, "ui_focus_widgets", {
        advance={text="Avançar"}, old={text="Dific. da negociação"},
    })
    speak("Dific. da negociação, item selecionado")
    record("A", "test")
    assert(a11y.transition_old_focus_texts["Dific. da negociação"])
    assert(a11y.native_speech_last == 0)
    set_upvalue(record, "last_selected_ui_entry", old_selected)
    set_upvalue(record, "ui_focus_widgets", old_widgets)
    remember_message("Que tal se focarmos em vencer o campeonato?",
        "new-screen-question")
    assert(a11y.transition_old_focus_texts == nil)
end)

check("message stage ignores technical and modal controls", function()
    remember_message("Carregando a bola", "status-widget")
    remember_message("Cancelar", "button-widget")
    local pending = upvalue(module.display_frame, "pending_message_text")
    assert(pending == nil)
end)

check("paged instructions remain independently queued", function()
    local first = "Enquanto segura o botão A, escolha a posição desejada."
    local second = "Enquanto segura o botão A, mova para outra posição."
    remember_message(first, "tutorial-widget")
    assert(upvalue(module.display_frame, "pending_message_text") == first)
    remember_message(second, "tutorial-widget")
    assert(upvalue(module.display_frame, "pending_message_text") == first)
    assert(#a11y.modal_message_backlog == 1)
    assert(a11y.modal_message_backlog[1].text == second)
    remember_message(second, "tutorial-widget")
    assert(#a11y.modal_message_backlog == 1)
end)

check("tutorial direct mutation replaces page without stale text", function()
    local first = "Enquanto segura o botão A, escolha a posição desejada."
    local second = "Enquanto segura o botão A, mova para outra posição."
    remember_message(first, "tutorial-widget")
    a11y.ui_string_object_by_widget["tutorial-widget"] = 1234
    local original_reader = a11y.read_msvc_string
    a11y.read_msvc_string = function() return second end
    a11y.poll_direct_message_update()
    assert(upvalue(module.display_frame, "pending_message_text") == first)
    assert(#a11y.modal_message_backlog == 1)
    assert(a11y.modal_message_backlog[1].text == second)
    a11y.read_msvc_string = original_reader
end)

check("overlay flow opens, updates, closes without repeating full panel", function()
    local first = "---> Audio <---\nMusic: 4\nKeys: arrows"
    local second = "Audio\n---> Music: 5 <---\nKeys: arrows"
    module.on_sider_overlay_content({}, "other.lua", first, true)
    local speech = speech_texts()
    assert(#speech == 1 and speech[1]:find("Audio", 1, true))
    module.on_sider_overlay_content({}, "other.lua", second, true)
    speech = speech_texts()
    assert(#speech == 2 and speech[2] == "Music: 5")
    module.on_sider_overlay_content({}, "other.lua", second, true)
    assert(#speech_texts() == 2)
    module.on_sider_overlay_content({}, "other.lua", second, false)
    assert(#speech_texts() == 3)
end)

check("panel navigation wraps and tooltip toggle persists", function()
    a11y.selected_option = 1
    module.key_down({}, a11y.previous_option_key)
    assert(a11y.selected_option == 2)
    module.key_down({}, a11y.next_option_key)
    assert(a11y.selected_option == 1)
    local previous_path = a11y.config_path
    a11y.config_path = nil
    module.key_down({}, a11y.next_value_key)
    assert(not a11y.read_tooltips)
    module.key_down({}, a11y.restore_key)
    assert(a11y.read_tooltips)
    a11y.config_path = previous_path
end)

check("disabling tooltips cancels delayed old speech", function()
    set_upvalue(a11y.clear_pending_tooltips,
        "pending_controller_tooltip", "Old tooltip")
    set_upvalue(a11y.clear_pending_tooltips,
        "main_menu_tooltip", "Old menu help")
    set_upvalue(a11y.clear_pending_tooltips,
        "controller_tooltip_due_ms", 1)
    set_upvalue(a11y.clear_pending_tooltips,
        "main_menu_tooltip_due_ms", 1)
    a11y.read_tooltips = true
    a11y.selected_option = 1
    local previous_path = a11y.config_path
    a11y.config_path = nil
    module.key_down({}, a11y.next_value_key)
    assert(not a11y.read_tooltips)
    assert(upvalue(a11y.clear_pending_tooltips,
        "pending_controller_tooltip") == nil)
    assert(upvalue(a11y.clear_pending_tooltips,
        "main_menu_tooltip") == nil)
    assert(upvalue(a11y.clear_pending_tooltips,
        "controller_tooltip_due_ms") == nil)
    assert(upvalue(a11y.clear_pending_tooltips,
        "main_menu_tooltip_due_ms") == nil)
    a11y.config_path = previous_path
end)

check("rapid Game Plan navigation tracks latest direction", function()
    a11y.record_game_plan_input("up", "keyboard")
    assert(a11y.navigation_action == "up")
    a11y.record_game_plan_input("right", "gamepad")
    assert(a11y.navigation_action == "right")
    a11y.game_plan_active = true
    a11y.game_plan_last_menu_focus = "Alterar formação"
    a11y.record_game_plan_input("A", "gamepad")
    assert(a11y.game_plan_context == "Alterar formação")
    a11y.record_game_plan_input("B", "gamepad")
    assert(a11y.game_plan_context == "Menu de configuração básica")
end)

check("formation speech uses effective value and avoids repeat", function()
    a11y.game_plan_active = true
    a11y.game_plan_context = "Alterar formação"
    local first = a11y.game_plan_focus_speech(
        "4-4-2 (4-3-3) Padrão", "formation-widget")
    assert(first:find("Formação 4-3-3", 1, true))
    assert(not first:find("4-4-2", 1, true))
    assert(a11y.game_plan_focus_speech(
        "4-4-2 (4-3-3) Padrão", "formation-widget") == nil)
end)

check("cup cells announce group only at boundary", function()
    a11y.cup_group_table_active = true
    local old_frame = upvalue(a11y.cup_group_team_speech, "frame")
    set_upvalue(a11y.cup_group_team_speech, "frame", 100)
    local first = a11y.cup_group_team_speech("Time A", "cell-a")
    assert(first:find("Grupo A.", 1, true))
    set_upvalue(a11y.cup_group_team_speech, "frame", 101)
    a11y.navigation_frame = 101
    a11y.navigation_action = "down"
    local second = a11y.cup_group_team_speech("Time B", "cell-b")
    assert(not second:find("Grupo A.", 1, true))
    set_upvalue(a11y.cup_group_team_speech, "frame", 102)
    a11y.navigation_frame = 102
    a11y.navigation_action = "right"
    local third = a11y.cup_group_team_speech("Time C", "cell-c")
    assert(third:find("Grupo B.", 1, true))
    assert(a11y.cup_group_team_speech("Cancelar", "button") == nil)
    assert(a11y.ignore_cup_group_focus("OK"))
    assert(not a11y.ignore_cup_group_focus("Cancelar"))
    set_upvalue(a11y.cup_group_team_speech, "frame", old_frame)
end)

check("Prism chooses reader then explicit SAPI fallback", function()
    local old_create, old_replace = a11y.create_prism_backend,
        a11y.replace_prism_backend
    a11y.prism_functions = {}
    a11y.prism_screen_readers = {{name="NVDA", id=1, priority=100}}
    a11y.prism_sapi_id = 2
    a11y.prism_uia_id = nil
    local available = {[1]=true, [2]=true}
    local selected
    a11y.create_prism_backend = function(id)
        return available[id] and {id=id} or nil
    end
    a11y.replace_prism_backend = function(backend)
        selected = backend.id
        return true
    end
    assert(a11y.select_prism_backend() and selected == 1)
    available[1] = false
    assert(a11y.select_prism_backend() and selected == 2)
    a11y.create_prism_backend = old_create
    a11y.replace_prism_backend = old_replace
end)

check("stale dialog expires on new screen activity", function()
    local options = upvalue(a11y.dismiss_dialog_for_focus, "dialog_options")
    options.Sim = {last_seen=10}
    options["Não"] = {last_seen=10}
    local active, blocked, dismissed = a11y.dismiss_dialog_for_focus(
        true, true, {text="Estádio"}, 11)
    assert(active and blocked and not dismissed)
    active, blocked, dismissed = a11y.dismiss_dialog_for_focus(
        true, true, {text="Estádio"}, 15)
    assert(not active and not blocked and dismissed)
    assert(a11y.confirmation_dialog_until_frame == 0)
end)

check("repeated resets discard old context and stale speech", function()
    a11y.game_plan_active = true
    a11y.pre_match_active = true
    a11y.pre_match_notice_text = "Old notice"
    speak("Old notice")
    module.context_reset({})
    module.context_reset({})
    assert(not a11y.game_plan_active and not a11y.pre_match_active)
    assert(a11y.pre_match_notice_text == nil)
    assert(a11y.native_speech_last == 0)
    speak("Old notice")
    assert(a11y.native_speech_last == 1)
end)

print("FLACCESS_OFFLINE_TESTS_OK checks=" .. checks ..
    " pt=" .. a11y.text_asset_counts.pt ..
    " en=" .. a11y.text_asset_counts.en)
