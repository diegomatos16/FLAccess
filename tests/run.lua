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
    hex=function(value) return tostring(tonumber(value)) end,
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
a11y.begin_focus_trace = function() end
a11y.ui_owner_link = function() return nil end
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

check("a user caption alone cannot invent a side and unchanged selection stays silent", function()
    local first=assert(a11y.selection_result({text="Usuário 1",identity="user",source="component"}))
    assert(not first.assignment and a11y.deliver_selection_result(first))
    assert(a11y.deliver_selection_result(assert(a11y.selection_result({text="Usuário 1",identity="user",source="component"}))))
    assert(#speech_texts()==1 and a11y.output_speech_text(speech_texts()[1])=="Usuário 1")
end)

check("legacy paragraph helper remains callable but is not visibility evidence", function()
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
    local announce = upvalue(a11y.on_observed_ui_text, "announce_screen_title")
    local is_title = upvalue(announce, "is_screen_title")
    assert(is_title("Escolha sua aparência"))
    assert(not is_title("Nome do treinador"))
    assert(not is_title("Escolha a frequência das transferências dos times do COMP. Quando \"Muito alta\", haverá uma grande quantidade de transferências."))
end)

check("structural title needs no imperative wording", function()
    local announce = upvalue(a11y.on_observed_ui_text, "announce_screen_title")
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
    local announce = upvalue(a11y.on_observed_ui_text, "announce_screen_title")
    announce("Escolha sua aparência", "appearance-title")
    speak("Luis Figo, item selecionado")
    assert(a11y.native_speech_last == 2)
    assert(a11y.native_speech_queue[1].text == "Escolha sua aparência")
    assert(a11y.native_speech_queue[1].interrupt)
    assert(a11y.native_speech_queue[2].text == "Luis Figo, item selecionado")
    assert(not a11y.native_speech_queue[2].interrupt)
end)

check("dialog capture preserves queued title but drops old focus", function()
    local announce = upvalue(a11y.on_observed_ui_text, "announce_screen_title")
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
    assert(a11y.announce_skip_hint("Options <Pular>"))
    assert(a11y.native_speech_last == 1)
    assert(a11y.native_speech_queue[1].text ==
        "Options Pular")
    assert(not a11y.announce_skip_hint("Options <Pular>"))
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
    a11y.widget_internal_name = function(widget) return names[tonumber(widget)] end
    local register = upvalue(module.on_resolved_text,
        "register_control_label")
    local attach = upvalue(a11y.on_observed_ui_text,
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
        assert(output[2][1] == "OK")
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
    assert(output[2].text == "OK")
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
        assert(output[2][1] == "Cancelar")
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
        assert(output[3][1] == "OK")
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

check("tutorial updates use copied widget text instead of a recycled setter argument", function()
    local first = "Enquanto segura o botão A, escolha a posição desejada."
    local second = "Enquanto segura o botão A, mova para outra posição."
    remember_message(first, "tutorial-widget")
    local original_reader = a11y.read_msvc_string
    a11y.read_msvc_string = function(address)
        assert(address>=0x10000,"temporary setter arguments must never be polled")
        return nil
    end
    a11y.poll_direct_message_update()
    assert(#a11y.modal_message_backlog == 0)
    a11y.ui_model.nodes["tutorial-widget"]={key="tutorial-widget",address=0x110000,text=second}
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

local function with_widget_names(names, fn)
    local original = a11y.widget_internal_name
    a11y.widget_internal_name = function(widget) return names[widget] end
    fn()
    a11y.widget_internal_name = original
end

local function emit_ui_text(widget, text)
    local old_unpack, old_string = host.memory.unpack, a11y.read_msvc_string
    host.memory.unpack = function(kind, value)
        if type(value) == "number" then return value end
        return old_unpack(kind, value)
    end
    a11y.read_msvc_string = function() return text end
    module.on_ui_text_set({}, 0, {rcx=widget, rdx=0x900000, rsp=0})
    host.memory.unpack, a11y.read_msvc_string = old_unpack, old_string
end

check("unknown structural fields pair when value arrives first", function()
    with_widget_names({[0x110000]="newField_item", [0x120000]="newField_value"}, function()
        emit_ui_text(0x120000, "Valor novo")
        emit_ui_text(0x110000, "Campo inédito")
        local row = a11y.structural_control_row(0x120000)
        assert(row and row.label == "Campo inédito" and row.value == "Valor novo")
        assert(row.structural and row.is_control)
        assert(a11y.native_speech_last == 0, "capture must not speak unfocused controls")
    end)
end)

check("structural pairs ignore unrelated render order", function()
    with_widget_names({[0x110000]="first_item", [0x120000]="second_item",
            [0x130000]="first_value", [0x140000]="second_value"}, function()
        emit_ui_text(0x110000, "Primeiro campo")
        emit_ui_text(0x120000, "Segundo campo")
        emit_ui_text(0x130000, "Primeiro valor")
        emit_ui_text(0x140000, "Segundo valor")
        assert(a11y.structural_control_row(0x130000).value == "Primeiro valor")
        assert(a11y.structural_control_row(0x140000).value == "Segundo valor")
    end)
end)

check("duplicate structural labels are unresolved, never guessed", function()
    with_widget_names({[0x110000]="field_item", [0x120000]="field_item",
            [0x130000]="field_value"}, function()
        emit_ui_text(0x110000, "Campo de fundo")
        emit_ui_text(0x120000, "Campo sobreposto")
        emit_ui_text(0x130000, "Valor")
        assert(a11y.structural_control_row(0x130000) == nil)
        a11y.forget_ui_widget(tostring(0x110000))
        emit_ui_text(0x130000, "Valor confirmado")
        assert(a11y.structural_control_row(0x130000).label == "Campo sobreposto")
    end)
end)

check("structural capture preserves native slider role and range", function()
    with_widget_names({[0x110000]="volume_item", [0x120000]="volume_value"}, function()
        local register = upvalue(module.on_resolved_text, "register_control_label")
        local row = register("Volume", 0x110000, "controle deslizante", true)
        row.native_slider, row.minimum, row.maximum = true, 0, 15
        row.value = "7 de 15"
        emit_ui_text(0x110000, "Volume")
        emit_ui_text(0x120000, "7")
        assert(row.role == "controle deslizante" and row.value == "7 de 15")
    end)
end)

check("duplicate structural values are unresolved", function()
    with_widget_names({[0x110000]="field_item", [0x120000]="field_value",
            [0x130000]="field_value"}, function()
        emit_ui_text(0x110000, "Campo")
        emit_ui_text(0x120000, "Valor A")
        local row = a11y.structural_control_row(0x120000)
        emit_ui_text(0x130000, "Valor B")
        assert(row.value == nil, "ambiguous pair must discard its former value")
        assert(a11y.structural_control_row(0x120000) == nil)
        assert(a11y.structural_control_row(0x130000) == nil)
    end)
end)

check("recycled widget clears old field ownership", function()
    local names = {[0x110000]="field_item", [0x120000]="field_value"}
    with_widget_names(names, function()
        emit_ui_text(0x110000, "Campo")
        emit_ui_text(0x120000, "Valor")
        local row = a11y.structural_control_row(0x120000)
        local identity = a11y.ui_focus_identity(tostring(0x120000), "Valor")
        names[0x120000] = "teamName"
        emit_ui_text(0x120000, "Clube novo")
        assert(row.value == nil and row.value_widget == nil)
        assert(identity ~= a11y.ui_focus_identity(tostring(0x120000), "Valor"))
    end)
end)

check("empty widget text invalidates its old value and focus", function()
    with_widget_names({[0x110000]="field_item", [0x120000]="field_value"}, function()
        emit_ui_text(0x110000, "Campo")
        emit_ui_text(0x120000, "Valor")
        local row = a11y.structural_control_row(0x120000)
        emit_ui_text(0x120000, "")
        assert(row.value == nil and row.value_widget == nil)
        assert(a11y.ui_model.nodes[tostring(0x120000)] == nil)
    end)
end)

check("UI observations and name index stay bounded", function()
    local old_name = a11y.widget_internal_name
    a11y.widget_internal_name = function(widget) return "node_" .. tostring(widget) end
    for index = 1, 1100 do a11y.observe_ui_widget(0x100000 + index * 32, "Texto") end
    local names = 0
    for _ in pairs(a11y.ui_model.names) do names = names + 1 end
    assert(a11y.ui_model.count == 1024 and names == 1024)
    a11y.widget_internal_name = old_name
end)

check("selection edges outrank a redrawn background widget", function()
    local focused, reason = a11y.resolve_primary_focus({
        {key="background", edge=10, last_seen=100},
        {key="selected", edge=90, last_seen=90},
    })
    assert(focused.key == "selected" and reason == "selection-edge")
    focused, reason = a11y.resolve_primary_focus({
        {key="selected", edge=90, last_seen=90},
        {key="background", edge=10, last_seen=200},
    })
    assert(focused.key == "selected" and reason == "selection-edge")
end)

check("tied selection edges remain ambiguous in either order", function()
    local candidates = {{key="one", edge=10}, {key="two", edge=10}}
    local focused, reason = a11y.resolve_primary_focus(candidates)
    assert(focused == nil and reason == "ambiguous-selection")
    focused, reason = a11y.resolve_primary_focus({candidates[2], candidates[1]})
    assert(focused == nil and reason == "ambiguous-selection")
    focused, reason = a11y.resolve_primary_focus({})
    assert(focused == nil and reason == "no-selection")
end)

check("same caption on different controls is spoken for each identity", function()
    speak("Opção, item selecionado", nil, nil, "one")
    speak("Opção, item selecionado", nil, nil, "one")
    speak("Opção, item selecionado", nil, nil, "two")
    assert(a11y.native_speech_last == 2)
end)

check("surface transition drops old observations but keeps current batch", function()
    local original_frame = upvalue(a11y.observe_ui_widget, "frame")
    with_widget_names({[0x110000]="old_item", [0x120000]="old_value",
            [0x130000]="new_item", [0x140000]="new_value"}, function()
        set_upvalue(a11y.observe_ui_widget, "frame", 100)
        emit_ui_text(0x110000, "Campo antigo")
        emit_ui_text(0x120000, "Valor antigo")
        set_upvalue(a11y.observe_ui_widget, "frame", 101)
        emit_ui_text(0x140000, "Valor novo")
        emit_ui_text(0x130000, "Campo novo")
        local generation = a11y.ui_model.generation
        assert(a11y.begin_ui_surface("Tela nova"))
        assert(a11y.ui_model.generation > generation)
        assert(a11y.ui_model.nodes[tostring(0x110000)] == nil)
        assert(a11y.structural_control_row(0x120000) == nil)
        local row = a11y.structural_control_row(0x140000)
        assert(row and row.value == "Valor novo")
        assert(not a11y.begin_ui_surface("Tela nova"))
    end)
    set_upvalue(a11y.observe_ui_widget, "frame", original_frame)
end)

check("return after transition has a fresh focus identity", function()
    with_widget_names({[0x110000]="field_item"}, function()
        a11y.observe_ui_widget(0x110000, "Campo")
        local first = a11y.ui_focus_identity(tostring(0x110000), "Campo")
        module.context_reset({})
        a11y.observe_ui_widget(0x110000, "Campo")
        assert(first ~= a11y.ui_focus_identity(tostring(0x110000), "Campo"))
    end)
end)

local function with_focus_memory(objects, fn)
    local scan = upvalue(module.display_frame, "scan_current_ui_focus")
    local names = {"frame", "readable", "startup_complete", "startup_completed_frame",
        "ui_focus_widgets", "ui_focus_widget_count", "ui_focus_state", "ui_focus_activated"}
    local saved = {}
    for _, name in ipairs(names) do saved[name] = upvalue(scan, name) end
    local old_read, old_unpack = host.memory.read, host.memory.unpack
    host.memory.read = function(address, size)
        if size == 0x30 then
            local object = objects[address - 0xf0]
            if object then
                local offset = (object.offset or 0x104) - 0xf0
                return string.rep("\0", offset) .. (object.focused and "\1" or "\0") ..
                    string.rep("\0", 47 - offset)
            end
        end
        return old_read(address, size)
    end
    host.memory.unpack = function(kind, bytes)
        if kind == "u32" then return string.byte(bytes, 1) or 0 end
        return old_unpack(kind, bytes)
    end
    set_upvalue(scan, "readable", function() return true end)
    set_upvalue(scan, "startup_complete", true)
    set_upvalue(scan, "startup_completed_frame", 0)
    set_upvalue(scan, "ui_focus_widgets", {})
    set_upvalue(scan, "ui_focus_widget_count", 0)
    set_upvalue(scan, "ui_focus_state", {})
    set_upvalue(scan, "ui_focus_activated", {})
    local function tick(frame_number)
        set_upvalue(scan, "frame", frame_number)
        a11y.navigation_frame = frame_number
        scan(false, false)
    end
    set_upvalue(scan, "frame", 120)
    fn(tick, scan)
    host.memory.read, host.memory.unpack = old_read, old_unpack
    for _, name in ipairs(names) do set_upvalue(scan, name, saved[name]) end
end

check("new control speaks name and value through the focus pipeline", function()
    with_widget_names({[0x110000]="novel_item", [0x120000]="novel_value"}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=false}}, function(tick)
            emit_ui_text(0x120000, "Valor inicial")
            emit_ui_text(0x110000, "Campo nunca catalogado")
            tick(120)
            tick(121)
            local output = speech_texts()
            assert(#output == 1)
            assert(output[1] == "Campo nunca catalogado, seletor, Valor inicial")
            emit_ui_text(0x120000, "Valor alterado")
            output = speech_texts()
            assert(#output == 2 and output[2] == "Valor alterado")
            tick(122)
            assert(#speech_texts() == 2, "stationary focus must not repeat")
        end)
    end)
end)

check("structural labels over fifty characters still enter focus tracking", function()
    local label = "Campo estrutural inédito com nome maior que cinquenta caracteres"
    assert(#label > 50)
    with_widget_names({[0x110000]="long_item", [0x120000]="long_value"}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=false}}, function(tick)
            emit_ui_text(0x110000, label)
            emit_ui_text(0x120000, "Valor")
            tick(120)
            tick(121)
            local output = speech_texts()
            assert(#output == 1 and output[1] == label .. ", seletor, Valor")
        end)
    end)
end)

check("real scan ignores redrawn text while selected edge stays newer", function()
    with_widget_names({}, function()
        local objects = {[0x110000]={focused=true}, [0x120000]={focused=false}}
        with_focus_memory(objects, function(tick)
            emit_ui_text(0x110000, "Opção anterior")
            emit_ui_text(0x120000, "Opção atual")
            tick(120)
            tick(121)
            objects[0x120000].focused = true
            tick(122)
            tick(123)
            emit_ui_text(0x110000, "Opção anterior")
            tick(124)
            local output = speech_texts()
            assert(#output == 2)
            assert(output[2] == "Opção atual, item selecionado")
        end)
    end)
end)

check("real scan stays silent when simultaneous focus is ambiguous", function()
    with_widget_names({}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=true}}, function(tick)
            emit_ui_text(0x110000, "Primeira opção")
            emit_ui_text(0x120000, "Segunda opção")
            tick(120)
            tick(121)
            assert(#speech_texts() == 0)
            assert(a11y.ui_model.focus_reason == "ambiguous-selection")
        end)
    end)
end)

check("known settings label remains eligible for real focus", function()
    with_widget_names({[0x110000]="duration_item", [0x120000]="duration_value"}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=false}}, function(tick)
            emit_ui_text(0x110000, "Duração da partida")
            emit_ui_text(0x120000, "10 min.")
            tick(120)
            tick(125)
            assert(speech_texts()[1] == "Duração da partida, seletor, 10 min.")
        end)
    end)
end)

check("option explanation does not lock or replace field speech", function()
    with_widget_names({[0x110000]="duration_item", [0x120000]="duration_value"}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=false}}, function(tick)
            emit_ui_text(0x110000, "Duração da partida")
            emit_ui_text(0x120000, "10 min.")
            local help = "Escolha a duração aproximada para cada partida, do início ao apito final."
            assert(a11y.is_control_help(help))
            assert(not a11y.capture_resolved_dialog(help, 999, 123))
            emit_ui_text(0x130000, help)
            assert(upvalue(module.display_frame, "pending_message_text") == nil)
            tick(120)
            tick(125)
            assert(speech_texts()[1] == "Duração da partida, seletor, 10 min.")
        end)
    end)
end)

check("title retains catalog and native controls from current batch", function()
    with_widget_names({[0x110000]="volume_item"}, function()
        local register = upvalue(a11y.capture_structural_control, "register_control_label")
        local row = register("Volume", 0x110000, "controle deslizante", true)
        row.native_slider, row.minimum, row.maximum, row.value = true, 0, 15, "5 de 15"
        assert(a11y.begin_ui_surface("Configurações de som"))
        local rows = upvalue(register, "control_rows_by_label_widget")
        assert(rows[host.memory.hex(0x110000)] == row)
        assert(row.native_slider and row.role == "controle deslizante" and row.value == "5 de 15")
        assert(row.generation == a11y.ui_model.generation)
    end)
end)

check("construction placeholder keeps other controls and stays silent", function()
    with_widget_names({[0x110000]="volume_item"}, function()
        emit_ui_text(0x110000, "Volume")
        local before = a11y.ui_model.generation
        emit_ui_text(0x120000, "No String")
        assert(a11y.ui_model.generation == before)
        assert(a11y.ui_model.nodes[host.memory.hex(0x110000)])
        speak("No String")
        assert(#speech_texts() == 0)
    end)
end)

check("secondary overlay bank cannot grant arbitrary artist focus", function()
    with_widget_names({}, function()
        with_focus_memory({[0x110000]={focused=true, offset=0x114}}, function(tick)
            emit_ui_text(0x110000, "Artista desconhecido")
            tick(120)
            tick(140)
            assert(#speech_texts() == 0)
        end)
    end)
end)

check("active yes-no dialog cannot enter group reader", function()
    with_widget_names({}, function()
        with_focus_memory({[0x110000]={focused=true}}, function(_, scan)
            a11y.activate_cup_group_table(false)
            emit_ui_text(0x110000, "Sim")
            scan(false, true)
            set_upvalue(scan, "frame", 140)
            scan(false, true)
            assert(#speech_texts() == 0)
        end)
    end)
end)

check("new question reads a free-text answer and subsequent choices", function()
    with_widget_names({}, function()
        local objects = {[0x110000]={focused=true}, [0x120000]={focused=false}}
        with_focus_memory(objects, function(tick)
            with_render_harness(function(output)
                emit_ui_text(0x130000, "Qual será a prioridade para a próxima temporada?")
                assert(a11y.read_context.kind == "dialog")
                emit_ui_text(0x110000, "Desenvolver jogadores")
                emit_ui_text(0x120000, "Buscar o campeonato")
                tick(120)
                assert(a11y.read_context.selection == nil)
                set_upvalue(module.display_frame, "pending_message_due_ms", 0)
                module.display_frame({sider_dir=sider_dir})
                assert(output[1][1] == "Qual será a prioridade para a próxima temporada?")
                tick(150)
                tick(155)
                assert(a11y.read_context.selection.text == "Desenvolver jogadores, opção selecionada")
                objects[0x110000].focused, objects[0x120000].focused = false, true
                tick(156)
                tick(160)
                assert(a11y.read_context.selection.text == "Buscar o campeonato, opção selecionada")
                local queued = speech_texts()
                assert(#queued == 2)
                assert(queued[1] == "Desenvolver jogadores, opção selecionada")
                assert(queued[2] == "Buscar o campeonato, opção selecionada")
                assert((a11y.read_context.question or a11y.read_context.title) == "Qual será a prioridade para a próxima temporada?")
                assert(a11y.read_context.selection.text == queued[2])
                a11y.record_game_plan_input("A", "test")
                assert(a11y.read_context.question == nil)
                assert(a11y.read_context.selection == nil)
            end)
        end)
    end)
end)

check("dialog ignores refreshed background whose selection edge is old", function()
    with_widget_names({}, function()
        with_focus_memory({[0x110000]={focused=true}}, function(tick)
            emit_ui_text(0x110000, "Menu anterior")
            tick(120)
            tick(125)
            a11y.open_read_dialog("Qual opção você prefere?", "question")
            emit_ui_text(0x110000, "Menu anterior")
            tick(130)
            tick(140)
            assert(a11y.read_context.selection == nil)
            assert(a11y.read_context.selection == nil)
        end)
    end)
end)

check("new dialog page resets answer identity and buffer", function()
    a11y.open_read_dialog("Primeira pergunta?", "question")
    a11y.commit_read_selection("Resposta A", "same-widget", "dialog-answer")
    local generation = a11y.read_context.generation
    a11y.open_read_dialog("Segunda pergunta?", "question")
    assert(a11y.read_context.generation > generation)
    assert(a11y.read_context.selection == nil)
    assert((a11y.read_context.question or a11y.read_context.title) == "Segunda pergunta?")
    assert(a11y.read_context.selection == nil)
end)

check("split question updates context without losing accepted identity", function()
    a11y.open_read_dialog("Uma pergunta", "question")
    local generation = a11y.read_context.generation
    a11y.open_read_dialog("Uma pergunta completa?", "question")
    assert(a11y.read_context.generation == generation)
    assert(a11y.read_context.question == "Uma pergunta completa?")
    assert(a11y.read_context.kind == "dialog")
end)

check("dialog owns selection and rejects control or carousel output", function()
    a11y.open_read_dialog("Escolha sua resposta?", "question")
    assert(not a11y.commit_read_selection("Controle do fundo", "old", "control"))
    assert(not a11y.commit_read_selection("Clube do fundo", "old", "native-list"))
    assert(a11y.read_context.selection == nil)
end)

check("buffer does not promote raw text or music to screen information", function()
    emit_ui_text(0x110000, "Música desconhecida")
    emit_ui_text(0x120000, "Texto do fundo")
    assert(#a11y.buffer_entries() == 0)
end)

check("buffer follows confirmed field value and clears unrelated help", function()
    a11y.commit_read_selection("Duração, seletor, 10 min.", "field", "control", "Duração")
    a11y.set_read_help("Ajuda da duração", "Duração")
    assert(a11y.read_context.help.text == "Ajuda da duração")
    a11y.commit_read_selection("Duração, seletor, 9 min.", "field", "control", "Duração")
    assert(a11y.read_context.selection.text == "Duração, seletor, 9 min.")
    assert(a11y.read_context.selection.text == "Duração, seletor, 9 min.")
    a11y.commit_read_selection("Lesões, seletor, Lig.", "other", "control", "Lesões")
    assert(a11y.read_context.help == nil)
end)

check("buffer is one sequence with repeat first and wrap without moving selection", function()
    a11y.set_read_title("Tela confirmada")
    a11y.commit_read_selection("Opção confirmada", "focus", "primary-focus")
    a11y.set_read_help("Ajuda confirmada")
    local selected = a11y.read_context.selection
    assert(#a11y.buffer_entries() == 3)
    assert(a11y.read_buffer("repeat"))
    assert(a11y.read_buffer("next"))
    assert(a11y.read_context.selection == selected)
    local text = speech_texts()
    assert(text[1] == "Tela confirmada")
    assert(text[2] == "Opção confirmada")
    assert(a11y.read_buffer("previous"))
    assert(a11y.read_context.cursor == 1)
    assert(a11y.read_buffer("previous"))
    assert(a11y.read_context.cursor == 3)
    assert(a11y.read_buffer("first"))
    assert(a11y.read_context.cursor == 1)
end)

check("reset and new title remove old question, selection and help", function()
    a11y.open_read_dialog("Pergunta antiga?", "question")
    a11y.commit_read_selection("Resposta", "focus", "dialog-answer")
    a11y.set_read_title("Outra tela")
    assert(a11y.read_context.kind == "menu")
    assert(a11y.read_context.question == nil and a11y.read_context.selection == nil)
    a11y.reset_ui_model()
    assert(#a11y.buffer_entries() == 0)
end)

check("ambiguous answers remain unresolved instead of guessing", function()
    with_widget_names({}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=true}}, function(tick)
            a11y.open_read_dialog("Qual resposta?", "question")
            emit_ui_text(0x110000, "Primeira resposta")
            emit_ui_text(0x120000, "Segunda resposta")
            tick(120)
            tick(140)
            assert(a11y.read_context.selection == nil)
            assert(a11y.read_context.unresolved_reason == "ambiguous-selection")
        end)
    end)
end)

check("unknown title waits for real selection instead of reading song caption", function()
    with_widget_names({[0x110000]="title"}, function()
        emit_ui_text(0x110000, "Faixa inédita XYZ")
        assert(#speech_texts() == 0)
        assert((not a11y.read_context.title and not a11y.read_context.question))
        a11y.commit_read_selection("Primeira opção", "verified", "primary-focus")
        assert((a11y.read_context.question or a11y.read_context.title) == "Faixa inédita XYZ")
        assert(speech_texts()[1] == "Faixa inédita XYZ")
    end)
end)

check("unknown overlay title cannot clear an established control context", function()
    a11y.set_read_title("Configurações gerais")
    a11y.commit_read_selection("Nível, seletor, Normal", "field", "control", "Nível")
    local generation = a11y.read_context.generation
    with_widget_names({[0x110000]="title"}, function()
        emit_ui_text(0x110000, "Faixa inédita XYZ")
        assert(#speech_texts() == 0)
        assert(a11y.read_context.generation == generation)
        assert((a11y.read_context.question or a11y.read_context.title) == "Configurações gerais")
        assert(a11y.read_context.selection.text == "Nível, seletor, Normal")
    end)
end)

check("confirmed control pipeline also updates buffer on lateral change", function()
    with_widget_names({[0x110000]="option_item", [0x120000]="option_value"}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=false}}, function(tick)
            emit_ui_text(0x110000, "Campo genérico")
            emit_ui_text(0x120000, "Primeiro valor")
            tick(120)
            tick(125)
            assert(a11y.read_context.selection.text == "Campo genérico, seletor, Primeiro valor")
            emit_ui_text(0x120000, "Outro valor")
            assert(a11y.read_context.selection.text == "Campo genérico, seletor, Outro valor")
        end)
    end)
end)

check("successive questions can reuse answer widget and unchanged focus bit", function()
    with_widget_names({}, function()
        with_focus_memory({[0x110000]={focused=true}}, function(tick)
            a11y.open_read_dialog("Primeira pergunta?", "question")
            emit_ui_text(0x110000, "Mesma resposta")
            tick(120)
            tick(125)
            assert(a11y.read_context.selection)
            a11y.record_game_plan_input("A", "test")
            assert(a11y.answer_chain)
            a11y.open_read_dialog("Segunda pergunta?", "question")
            tick(130)
            tick(135)
            assert(a11y.read_context.selection.text == "Mesma resposta, opção selecionada")
            assert(#speech_texts() == 2)
        end)
    end)
end)

check("answer ownership does not follow another dialog or a recycled node", function()
    with_widget_names({[0x110000]="answer"}, function()
        with_focus_memory({[0x110000]={focused=true}}, function(tick)
            a11y.open_read_dialog("Primeira pergunta?", "question")
            emit_ui_text(0x110000, "Resposta")
            tick(120)
            tick(125)
            a11y.record_game_plan_input("A", "test")
            a11y.open_read_dialog("Outra pergunta?", "different-widget")
            tick(130)
            tick(140)
            assert(a11y.read_context.selection == nil)
        end)
    end)
end)

check("independent transition discards chained dialog ownership", function()
    a11y.answer_chain = {message_key="old", owners={}}
    a11y.reset_ui_model()
    assert(a11y.answer_chain == nil)
    assert((not a11y.read_context.title and not a11y.read_context.question))
end)

check("dialog cancels delayed background help even after navigation releases hold", function()
    local delayed = upvalue(module.display_frame, "process_delayed_speech")
    a11y.open_read_dialog("Pergunta atual?", "question")
    set_upvalue(delayed, "pending_controller_tooltip", "Ajuda do fundo")
    set_upvalue(delayed, "pending_controller_tooltip_label", "Campo antigo")
    set_upvalue(delayed, "active_controller_label", "Campo antigo")
    set_upvalue(delayed, "controller_tooltip_due_ms", 1)
    delayed(5000, false)
    assert(#speech_texts() == 0)
    assert(upvalue(delayed, "controller_tooltip_due_ms") == nil)
end)

check("cleared focused widget invalidates the buffer selection", function()
    with_widget_names({[0x110000]="option_item", [0x120000]="option_value"}, function()
        with_focus_memory({[0x110000]={focused=true}, [0x120000]={focused=false}}, function(tick)
            emit_ui_text(0x110000, "Campo genérico")
            emit_ui_text(0x120000, "Valor")
            tick(120)
            tick(125)
            assert(a11y.read_context.selection ~= nil)
            emit_ui_text(0x110000, "")
            assert(a11y.read_context.selection == nil)
        end)
    end)
end)

check("letter review works without Control and leaves ordinary arrows free", function()
    local original = upvalue(a11y.poll_diagnostic_keyboard, "user32")
    local keys = {}
    set_upvalue(a11y.poll_diagnostic_keyboard, "user32", {GetAsyncKeyState=function(key) return keys[key] and -1 or 0 end})
    a11y.set_read_title("Pergunta")
    a11y.commit_read_selection("Resposta", "focus", "primary-focus")
    assert(not a11y.buffer_key(0x28))
    a11y.buffer_last_key = nil
    assert(a11y.buffer_key(0x4b))
    assert(a11y.read_context.cursor == 2)
    assert(not a11y.buffer_key(0x77))
    keys[0x28] = true
    a11y.poll_diagnostic_keyboard()
    assert(a11y.diagnostic_last_input_action == "down")
    assert(a11y.buffer_key(0x4a))
    assert(a11y.read_context.cursor == 1)
    set_upvalue(a11y.poll_diagnostic_keyboard, "user32", original)
end)

check("right stick review stays inside recognized player attributes", function()
    a11y.set_read_title("Plano de jogo")
    a11y.game_plan_active = false
    a11y.game_plan_attribute_items = {{label="Velocidade", value="90"}}
    a11y.game_plan_attribute_panel_until_ms = tonumber(ffi.C.GetTickCount64()) + 10000
    assert(not a11y.review_right_stick(1))
    a11y.game_plan_active = true
    a11y.review_stick_direction = nil
    assert(a11y.review_right_stick(1))
    assert(speech_texts()[1] == "Velocidade, 90")
    a11y.open_read_dialog("Confirmar?", "question")
    assert(not a11y.review_right_stick(-1))
    assert(#a11y.buffer_entries() == 1)
end)

check("notice never queues a retained old OK based on redraw alone", function()
    local widgets = upvalue(a11y.open_read_dialog, "ui_focus_widgets")
    set_upvalue(a11y.open_read_dialog, "ui_focus_widgets", {old={text="OK",last_seen=0}})
    a11y.open_read_dialog("Insira os detalhes do treinador.", "notice")
    local start = a11y.read_context.started_frame
    assert(not a11y.capture_pending_modal_button("old", {text="OK",last_seen=start},0x104,start-383))
    assert(a11y.pending_modal_button_text == nil)
    assert(a11y.capture_pending_modal_button("old", {text="OK",last_seen=start},0x104,start))
    assert(a11y.pending_modal_button_text == "OK")
    assert(not a11y.capture_pending_modal_button("other", {text="OK",last_seen=start},0x100,start))
    set_upvalue(a11y.open_read_dialog, "ui_focus_widgets", widgets)
end)

check("transition quarantine follows objects and fresh focus rather than captions", function()
    a11y.transition_old_focus_texts = {["Nome do treinador"]=true}
    a11y.transition_old_focus_nodes = {old={text="Nome do treinador"}}
    a11y.transition_started_frame = 100
    a11y.transition_guard_until_ms = 10000
    assert(a11y.transition_focus_blocked("old",{text="Nome do treinador"},0x104,99,500))
    assert(not a11y.transition_focus_blocked("new",{text="Nome do treinador"},0x104,99,500))
    a11y.transition_old_focus_texts = {["Nome do treinador"]=true}
    assert(not a11y.transition_focus_blocked("old",{text="Nome do treinador"},0x104,101,500))
end)

check("same field reads again after leaving for an ordinary item", function()
    local objects = {[0x110000]={focused=true}, [0x120000]={focused=false}, [0x130000]={focused=false}}
    with_widget_names({[0x110000]="arbitrary_item",[0x120000]="arbitrary_value"}, function()
        with_focus_memory(objects, function(tick)
            emit_ui_text(0x110000,"Campo independente da tela")
            emit_ui_text(0x120000,"Valor igual")
            emit_ui_text(0x130000,"Outro item")
            tick(120); tick(125)
            objects[0x110000].focused, objects[0x130000].focused = false,true
            tick(130); tick(135)
            objects[0x110000].focused, objects[0x130000].focused = true,false
            tick(140); tick(145)
            local texts = speech_texts()
            assert(#texts == 3)
            assert(texts[1] == texts[3])
            tick(150)
            assert(#speech_texts() == 3)
        end)
    end)
end)

check("same field reads again after primary focus disappears", function()
    local objects = {[0x110000]={focused=true},[0x120000]={focused=false}}
    with_widget_names({[0x110000]="independent_item",[0x120000]="independent_value"}, function()
        with_focus_memory(objects, function(tick)
            emit_ui_text(0x110000,"Campo")
            emit_ui_text(0x120000,"Mesmo valor")
            tick(120); tick(125)
            objects[0x110000].focused=false
            tick(130)
            objects[0x110000].focused=true
            set_upvalue(speak, "last_spoken_ms", 0)
            tick(140); tick(145)
            assert(#speech_texts() == 2)
        end)
    end)
end)

check("old secondary control cannot inherit authority when primary focus is lost", function()
    local objects = {[0x110000]={focused=true},[0x120000]={focused=false},
        [0x130000]={focused=true,offset=0x100},[0x140000]={focused=false}}
    with_widget_names({[0x110000]="new_item",[0x120000]="new_value",
            [0x130000]="old_item",[0x140000]="old_value"}, function()
        with_focus_memory(objects, function(tick)
            emit_ui_text(0x130000,"Campo antigo"); emit_ui_text(0x140000,"Valor antigo")
            objects[0x110000].focused=false
            tick(120); tick(125)
            emit_ui_text(0x110000,"Campo novo"); emit_ui_text(0x120000,"Valor novo")
            objects[0x110000].focused=true
            tick(130); tick(135)
            local before=#speech_texts()
            objects[0x110000].focused=false
            tick(140); tick(145)
            assert(#speech_texts() == before)
            assert(a11y.ui_model.focus_reason == "stale-secondary-focus")
            objects[0x130000].focused=false; tick(150)
            objects[0x130000].focused=true; tick(160);tick(165)
            assert(#speech_texts() == before+1)
        end)
    end)
end)

check("focus investigation logs field changes including zero without affecting speech", function()
    local old_io, old_read, old_unpack = host.io, host.memory.read, host.memory.unpack
    local old_readable = upvalue(a11y.capture_focus_trace,"readable")
    local old_model, old_trace = a11y.ui_model, a11y.focus_trace
    local writes, flag = {},1
    host.io = {open=function() return {
        write=function(_,text) writes[#writes+1]=text end, close=function() end,
    } end}
    host.memory.read = function(_,size)
        local relative=0x104
        return string.rep("\0",relative)..string.char(flag)..string.rep("\0",size-relative-1)
    end
    host.memory.unpack = function(_,bytes) return string.byte(bytes,1) or 0 end
    set_upvalue(a11y.capture_focus_trace,"readable",function() return true end)
    a11y.ui_model = {generation=1, nodes={test={key="test",address=0x110000,identity="test",sequence=1,
        text="Campo de investigação",name="arbitrary_item",last_seen=120}}}
    a11y.focus_trace = {sequence=1,action="down",bytes=0}
    local before=#speech_texts()
    a11y.capture_focus_trace("input")
    assert(writes[1]:find("104=1",1,true))
    flag=0
    a11y.capture_focus_trace("after-4")
    assert(writes[2]:find("104=0",1,true))
    a11y.capture_focus_trace("after-12")
    assert(not writes[3]:find("node=",1,true))
    assert(#speech_texts()==before)
    a11y.focus_trace.bytes=2097152
    a11y.capture_focus_trace("limit")
    assert(#writes==3)
    host.io,host.memory.read,host.memory.unpack=old_io,old_read,old_unpack
    set_upvalue(a11y.capture_focus_trace,"readable",old_readable)
    a11y.ui_model,a11y.focus_trace=old_model,old_trace
end)

check("simultaneous primary label and value are one selected control", function()
    local objects = {[0x110000]={focused=true},[0x120000]={focused=true}}
    with_widget_names({[0x110000]="unseen_item",[0x120000]="unseen_value"}, function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Campo sem adaptador")
            emit_ui_text(0x120000,"Valor compartilhado")
            tick(120);tick(125)
            assert(a11y.ui_model.focus_reason=="control-label-value")
            assert(speech_texts()[1]=="Campo sem adaptador, seletor, Valor compartilhado")
            tick(130)
            assert(#speech_texts()==1)
        end)
    end)
end)

check("captured setName and text layout reads every coach field on revisit", function()
    local objects={}
    for _,address in ipairs({0x110000,0x120000,0x130000,0x140000,0x150000,0x160000}) do
        objects[address]={focused=false}
    end
    with_widget_names({[0x110000]="setName",[0x120000]="textWord",
            [0x130000]="setName",[0x140000]="text",[0x150000]="setName",[0x160000]="text"},function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Nome do treinador");emit_ui_text(0x120000,"Luis Figo")
            emit_ui_text(0x130000,"Nacional./Região");emit_ui_text(0x140000,"PORTUGAL")
            emit_ui_text(0x150000,"Roupa em jogos");emit_ui_text(0x160000,"Terno")
            local register=upvalue(module.on_resolved_text,"register_control_label")
            local attach=upvalue(a11y.on_observed_ui_text,"attach_control_value")
            assert(attach(register("Nome do treinador",0x110000),0x120000,"Luis Figo"))
            assert(attach(register("Nacional./Região",0x130000),0x140000,"PORTUGAL"))
            assert(attach(register("Roupa em jogos",0x150000),0x160000,"Terno"))
            objects[0x110000].focused,objects[0x120000].focused=true,true
            tick(120);tick(125)
            objects[0x110000].focused,objects[0x120000].focused=false,false
            objects[0x130000].focused,objects[0x140000].focused=true,true
            tick(130);tick(135)
            objects[0x130000].focused,objects[0x140000].focused=false,false
            objects[0x150000].focused,objects[0x160000].focused=true,true
            tick(140);tick(145)
            objects[0x150000].focused,objects[0x160000].focused=false,false
            objects[0x110000].focused,objects[0x120000].focused=true,true
            tick(150);tick(155)
            local texts=speech_texts()
            assert(#texts==4, "coach output: "..table.concat(texts," | "))
            assert(texts[1]=="Nome do treinador, ativar para editar, Luis Figo")
            assert(texts[2]=="Nacional./Região, seletor, PORTUGAL")
            assert(texts[3]=="Roupa em jogos, seletor, Terno")
            assert(texts[4]==texts[1])
        end)
    end)
end)

check("two distinct paired controls with simultaneous focus remain ambiguous",function()
    local objects={}
    for _,address in ipairs({0x110000,0x120000,0x130000,0x140000}) do objects[address]={focused=true} end
    with_widget_names({[0x110000]="a_item",[0x120000]="a_value",[0x130000]="b_item",[0x140000]="b_value"},function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Campo A");emit_ui_text(0x120000,"Valor A")
            emit_ui_text(0x130000,"Campo B");emit_ui_text(0x140000,"Valor B")
            tick(120);tick(125)
            assert(a11y.ui_model.focus_reason=="ambiguous-selection")
            assert(#speech_texts()==0)
        end)
    end)
end)

check("command footer Voltar cannot become secondary selection",function()
    local objects={[0x110000]={focused=true,offset=0x100},[0x120000]={focused=false}}
    with_widget_names({[0x110000]="text",[0x120000]="padIcon"},function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Voltar");emit_ui_text(0x120000,"botão A")
            local label=a11y.ui_model.nodes[tostring(0x110000)]
            local icon=a11y.ui_model.nodes[tostring(0x120000)]
            label.owner_link,icon.owner_link=0x220000,0x220000
            tick(120);tick(135)
            assert(#speech_texts()==0)
            assert(a11y.is_command_legend(label.key,false,a11y.command_icon_owners()))
            objects[0x110000].offset=0x104
            tick(140);tick(155)
            assert(speech_texts()[1]=="Voltar, botão selecionado" or speech_texts()[1]=="Voltar, item selecionado")
        end)
    end)
end)

check("captured question layout speaks only prompt then each selected response",function()
    local owner_reader=a11y.ui_owner_link
    a11y.ui_owner_link=function(address) return address>=0x130000 and 0x330000 or 0x220000 end
    local objects={[0x110000]={focused=true},[0x120000]={focused=false},
        [0x130000]={focused=false},[0x140000]={focused=true},[0x150000]={focused=false},[0x160000]={focused=false}}
    with_widget_names({[0x110000]="old_item",[0x120000]="old_value",[0x130000]="question",
            [0x140000]="text",[0x150000]="text",[0x160000]="text"},function()
        with_focus_memory(objects,function(tick,scan)
            emit_ui_text(0x110000,"Unidade monetária");emit_ui_text(0x120000,"Real brasileiro")
            tick(120);tick(125)
            emit_ui_text(0x140000,"Concordo.")
            emit_ui_text(0x150000,"Deveríamos focar em conseguir uma vaga na UEFA Champions League.")
            emit_ui_text(0x160000,"Podemos terminar na metade de cima da tabela do campeonato.")
            a11y.navigation_frame=0
            emit_ui_text(0x130000,"Que tal se focarmos em vencer o campeonato?")
            assert(a11y.read_context.structural_question)
            assert(#a11y.modal_message_backlog==0)
            with_render_harness(function(output)
                set_upvalue(module.display_frame,"pending_message_due_ms",0)
                module.display_frame({sider_dir=sider_dir})
                assert(#output==1 and output[1][1]=="Pergunta: Que tal se focarmos em vencer o campeonato?")
            end)
            local function sample(number)
                set_upvalue(scan,"frame",number);scan(false,false)
            end
            sample(130);sample(135)
            assert(#speech_texts()==0,"initial response must wait for navigation")
            objects[0x140000].focused=false;objects[0x150000].focused=true
            a11y.navigation_frame=140
            sample(140);sample(145)
            objects[0x150000].focused=false;objects[0x160000].focused=true
            a11y.navigation_frame=150
            sample(150);sample(155)
            local texts=speech_texts()
            assert(#texts==2)
            assert(texts[1]=="Deveríamos focar em conseguir uma vaga na UEFA Champions League., opção selecionada")
            assert(texts[2]=="Podemos terminar na metade de cima da tabela do campeonato., opção selecionada")
            assert(not texts[1]:find("Unidade monetária",1,true))
            set_upvalue(scan,"frame",160)
            a11y.record_game_plan_input("A","test")
            assert(a11y.read_context.kind=="dialog" and a11y.read_context.question==nil)
            objects[0x160000].focused=false
            sample(165);sample(170)
            assert(#speech_texts()==2,"confirmation must not release old settings")
            a11y.set_read_title("Nova tela")
            assert(not a11y.read_context.structural_question)
        end)
    end)
    a11y.ui_owner_link=owner_reader
end)

check("clearing an unrelated icon does not repeat a stationary control",function()
    local objects={[0x110000]={focused=true},[0x120000]={focused=false},[0x130000]={focused=false}}
    with_widget_names({[0x110000]="field_item",[0x120000]="field_value",[0x130000]="padIcon"},function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Campo");emit_ui_text(0x120000,"Valor")
            emit_ui_text(0x130000,"botão A")
            tick(120);tick(125)
            emit_ui_text(0x130000,"")
            tick(130);tick(135)
            assert(#speech_texts()==1)
        end)
    end)
end)

check("event message blocks retained settings before question widgets arrive",function()
    local owner_reader=a11y.ui_owner_link
    a11y.ui_owner_link=function(address) return address>=0x130000 and 0x330000 or 0x220000 end
    local objects={[0x110000]={focused=true},[0x120000]={focused=false},[0x130000]={focused=false},[0x140000]={focused=false}}
    with_widget_names({[0x110000]="old_item",[0x120000]="old_value",[0x130000]="eventMsg",[0x140000]="text"},function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Unidade monetária");emit_ui_text(0x120000,"Real brasileiro")
            tick(120);tick(125)
            emit_ui_text(0x130000,"Luis Figo, quero conversar sobre os objetivos da temporada.")
            assert(a11y.read_context.structural_event and a11y.read_context.kind=="dialog")
            emit_ui_text(0x140000,"Deveríamos focar em conseguir uma vaga na UEFA Champions League.")
            assert(#a11y.modal_message_backlog==0)
            tick(130);tick(135)
            assert(#speech_texts()==0)
        end)
    end)
    a11y.ui_owner_link=owner_reader
end)

local function with_native_windows(fn)
    local saved_read, saved_snapshot, saved_cache = a11y.menu_read, a11y.native_windows, a11y.native_tree_cache
    local base, manager = 0x140000000, 0x1000000
    local values = {[base+0x36f9c10]=manager,[manager]=base+0x27c1568}
    for slot=0,7 do
        values[manager+8+slot*24],values[manager+16+slot*24]=0,0
        values[manager+0xc8+slot*16],values[manager+0xd0+slot*16]=0,0
    end
    values[manager+8],values[manager+16]=0x700000,0x700020
    values[0x700000],values[0x700010]=0x1100000,0x1110000
    values[manager+0xc8],values[manager+0xd0]=0x1110000,2
    values[0x1100088],values[0x1110088]=0x1200000,0x1210000
    values[0x1200009],values[0x1210009]=0,1
    values[0x1200098],values[0x1210098]=0x300000,0x310000
    values[0x300000],values[0x310000]=base+0x27bae88,base+0x27bae88
    values[0x300170],values[0x300178]=0x600000,0x600008
    values[0x310170],values[0x310178]=0x610000,0x610008
    values[0x600000],values[0x610000]=0x500000,0x510000
    values[0x500000],values[0x510000]=base+0x27b5260,base+0x27b5260
    a11y.menu_read=function(address) return values[address] end
    a11y.native_tree_cache=nil
    fn(values,base,manager)
    a11y.menu_read,a11y.native_windows,a11y.native_tree_cache=saved_read,saved_snapshot,saved_cache
end

check("native registry includes disabled windows absent from active slots",function()
    with_native_windows(function(_,base)
        local snapshot=assert(a11y.read_native_windows(base))
        assert(#snapshot.windows==2 and #snapshot.active==1)
        a11y.native_windows=snapshot
        assert(not a11y.native_widget_allowed(0x500000))
        assert(a11y.native_widget_allowed(0x510000))
        assert(a11y.native_widget_allowed(0x520000),"unknown membership must remain available")
    end)
end)

check("returning window regains reading without a new text setter",function()
    with_native_windows(function(values,base)
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_widget_allowed(0x500000))
        values[0x1200009],values[0x1210009]=1,0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_widget_allowed(0x500000))
        assert(not a11y.native_widget_allowed(0x510000))
    end)
end)

check("shared text remains readable through an enabled owner",function()
    with_native_windows(function(values,base)
        values[0x610000]=0x500000
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_widget_allowed(0x500000))
    end)
end)

check("incomplete registry and unrecognized executable grant no authority",function()
    with_native_windows(function(values,base,manager)
        values[manager]=0
        assert(a11y.read_native_windows(base)==nil)
        values[manager]=base+0x27c1568
        values[manager+16]=0x700003
        assert(a11y.read_native_windows(base)==nil)
        a11y.native_windows=nil
        assert(a11y.native_widget_allowed(0x500000))
    end)
end)

check("transition without enabled owner cannot speak retained old widgets",function()
    with_native_windows(function(values,base)
        values[0x1210009]=0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(#a11y.native_windows.active==0)
        assert(not a11y.native_widget_allowed(0x500000))
        assert(a11y.native_widget_allowed(0x520000))
    end)
end)

check("native tree traversal handles cycles and invalid lengths",function()
    with_native_windows(function(values,base)
        values[0x300178]=0x600010
        values[0x600008]=0x300000
        assert(a11y.menu_tree(0x300000,base)[0x500000])
        values[0x300178]=0x600001
        assert(not a11y.menu_tree(0x300000,base)[0x500000])
    end)
end)

check("native cursor follows indices even when sticky text flags never change",function()
    with_native_windows(function(values,base)
        values[0x310190]=0x800000
        values[0x800000]=base+0x27c1ac0
        values[0x800088],values[0x800090],values[0x800094]=0x310000,0,1
        values[0x610000]=0x320000
        values[0x320000]=base+0x27cb508
        values[0x320170],values[0x320178]=0x620000,0x620010
        values[0x620000],values[0x620008]=0x510000,0x520000
        values[0x520000]=base+0x27b5260
        local snapshot=assert(a11y.read_native_windows(base))
        assert(snapshot.selected_members[0x520000] and not snapshot.selected_members[0x510000])
        assert(snapshot.cursor_members[0x510000] and snapshot.cursor_members[0x520000])
        values[0x800094]=0
        snapshot=assert(a11y.read_native_windows(base))
        assert(snapshot.selected_members[0x510000] and not snapshot.selected_members[0x520000])
        values[0x800094]=256
        snapshot=assert(a11y.read_native_windows(base))
        assert(not snapshot.cursor_members[0x510000])
    end)
end)

check("proven inactive ownership stays rejected while a new tree is incomplete",function()
    with_native_windows(function(values,base)
        values[0x310000]=base+0x1234
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_windows.active_text_count==0)
        assert(not a11y.native_widget_allowed(0x500000))
        assert(a11y.native_widget_allowed(0x520000))
    end)
end)

check("native window closure releases old dialog ownership and reading hold",function()
    local old_read,old_enabled,old_snapshot,old_frame=a11y.read_native_windows,
        a11y.native_windows_enabled,a11y.native_windows,a11y.native_windows_frame
    a11y.ui_model.nodes[host.memory.hex(0x110000)]={address=0x110000,text="Pergunta antiga"}
    a11y.open_read_dialog("Pergunta antiga",host.memory.hex(0x110000))
    local hold=upvalue(speak,"modal_focus_hold_until_ms")
    set_upvalue(speak,"modal_focus_hold_until_ms",tonumber(ffi.C.GetTickCount64())+10000)
    a11y.native_windows={signature="old",active_identity="old"}
    a11y.native_windows_enabled,a11y.native_windows_frame=true,nil
    a11y.read_native_windows=function() return {signature="new",active_identity="new",windows={},
        active={"new"},members={[0x110000]={active=false}},selected_members={}} end
    a11y.poll_native_windows()
    assert(a11y.read_context.question==nil and a11y.read_context.reason=="native-window-closed")
    assert(upvalue(speak,"modal_focus_hold_until_ms")==0)
    set_upvalue(speak,"modal_focus_hold_until_ms",hold)
    a11y.read_native_windows,a11y.native_windows_enabled,a11y.native_windows,a11y.native_windows_frame=
        old_read,old_enabled,old_snapshot,old_frame
end)

check("engine cursor reads a selected text whose old focus flag is unset",function()
    local saved=a11y.native_windows
    local objects={[0x110000]={focused=true},[0x120000]={focused=false}}
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Escolha anterior");emit_ui_text(0x120000,"Escolha do cursor")
            a11y.native_windows={active={"menu"},members={},
                cursor_members={[0x110000]=true,[0x120000]=true},selected_members={[0x120000]=true}}
            tick(120);tick(125)
            local output=speech_texts()
            assert(#output==1 and output[1]:find("Escolha do cursor",1,true))
        end)
    end)
    a11y.native_windows=saved
end)

check("native ownership defeats sticky background selection in speech",function()
    local saved=a11y.native_windows
    local objects={[0x110000]={focused=true},[0x120000]={focused=true}}
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory(objects,function(tick)
            emit_ui_text(0x110000,"Menu antigo");emit_ui_text(0x120000,"Resposta atual")
            a11y.native_windows={active={"dialog"},members={[0x110000]={active=false},[0x120000]={active=true}}}
            tick(120);tick(125)
            local output=speech_texts()
            assert(#output==1 and output[1]:find("Resposta atual",1,true))
            a11y.native_windows={active={"menu"},members={[0x110000]={active=true},[0x120000]={active=false}}}
            a11y.reset_focus_reuse_state()
            tick(130);tick(135)
            output=speech_texts()
            assert(#output==2 and output[2]:find("Menu antigo",1,true))
        end)
    end)
    a11y.native_windows=saved
end)

check("inactive and recycled text cannot retain selection authority",function()
    local old=a11y.menu_read
    local base,address=0x140000000,0x110000
    local values={[address]=base+0x27b5260,[address+0x0c]=0x107}
    a11y.menu_read=function(ptr) return values[ptr] end
    assert(a11y.menu_node_active(address,base)==true)
    values[address+0x0c]=7
    assert(a11y.menu_node_active(address,base)==false)
    values[address+0x0c]=0
    assert(a11y.menu_node_active(address,base)==false)
    values[address]=base+0x1234
    assert(a11y.menu_node_active(address,base)==false)
    values[address]=nil
    assert(a11y.menu_node_active(address,base)==nil)
    a11y.menu_read=old
end)

check("home metadata retains details in one review sequence without making a dialog",function()
    assert(a11y.apply_menu_flow('{"data":{"type":"menu","mark":"home"}}','home.json'))
    a11y.record_dashboard_text({address=0x110000,name="date",text="15 de agosto"})
    a11y.record_dashboard_text({address=0x120000,name="followers",text="Torcedores: 1200"})
    remember_message("Bem-vindo ao clube. Confira as informações do calendário.","news")
    assert(upvalue(remember_message,"recent_message_text")==nil)
    local entries=a11y.buffer_entries()
    assert(#entries==2 and entries[1]=="15 de agosto" and entries[2]=="Torcedores: 1200")
    a11y.record_dashboard_text({address=0x110000,name="date",text="16 de agosto"})
    assert(#a11y.buffer_entries()==2 and a11y.buffer_entries()[1]=="16 de agosto")
    assert(a11y.apply_menu_flow('{"data":{"type":"menu"}}','settings.json'))
    assert(not a11y.dashboard_review and #a11y.dashboard_texts==0)
end)

check("skip speech uses the rendered button and never guesses Options",function()
    local old=a11y.game_is_foreground
    a11y.game_is_foreground=function() return true end
    a11y.skip_hint_last_frame=-10000
    assert(a11y.announce_skip_hint("Pressione botão Y para pular"))
    assert(speech_texts()[1]=="Pressione botão Y para pular")
    a11y.skip_hint_last_frame=-10000
    assert(a11y.announce_skip_hint("<Pular>"))
    assert(speech_texts()[2]=="Pular")
    assert(not speech_texts()[2]:find("Options",1,true))
    a11y.game_is_foreground=old
end)

check("unrelated calendar text cannot be appended to a news paragraph",function()
    set_upvalue(remember_message,"recent_message_text","Uma notícia do clube sem pontuação")
    set_upvalue(remember_message,"recent_message_widget_key","article")
    set_upvalue(remember_message,"recent_message_frame",upvalue(module.display_frame,"frame"))
    remember_message("15 de agosto","calendar")
    assert(upvalue(remember_message,"recent_message_text")=="Uma notícia do clube sem pontuação")
    remember_message("continuação","article")
    assert(upvalue(remember_message,"recent_message_text")=="Uma notícia do clube sem pontuação continuação")
end)

check("split skip footer pairs its caption with the current icon",function()
    local old=a11y.game_is_foreground
    a11y.game_is_foreground=function() return true end
    a11y.skip_hint_last_frame=-10000
    a11y.ui_model.nodes.icon={address=0x120000,name="padIcon",owner_link=123,text="botão A"}
    assert(a11y.announce_skip_hint("Pular",{key="caption",owner_link=123}))
    with_widget_names({[0x120000]="padIcon"},function() a11y.poll_skip_hint() end)
    assert(speech_texts()[1]=="Pular, botão A")
    assert(a11y.pending_skip_hint==nil)
    a11y.game_is_foreground=old
end)

check("keyboard feedback reads additions and deleting the entire name",function()
    a11y.keyboard_echo_insertions=true
    a11y.keyboard_window=0x130000
    assert(a11y.read_keyboard_text({address=0x110000,name="textWord",text="José"}))
    assert(#speech_texts()==0)
    assert(a11y.read_keyboard_text({address=0x110000,name="textWord",text="José Luís"}))
    assert(speech_texts()[1]==" Luís")
    assert(a11y.read_keyboard_text({address=0x110000,name="textWord",text=""}))
    assert(speech_texts()[2]=="José Luís")
    assert(not a11y.read_keyboard_text({address=0x120000,name="title",text="Teclado"}))
    a11y.keyboard_echo_insertions=false
end)

check("native window cursor parent supplies ownership when the flat root has no children",function()
    with_native_windows(function(values,base)
        values[0x310000]=base+0x27b6490
        values[0x310170],values[0x310178]=0,0
        values[0x310190]=0x800000
        values[0x800000]=base+0x27c1ac0
        values[0x800088],values[0x800090],values[0x800094]=0x320000,0,0
        values[0x320000]=base+0x27bae88
        values[0x320170],values[0x320178]=0x620000,0x620008
        values[0x620000]=0x330000
        values[0x330000]=base+0x27cb508
        values[0x330170],values[0x330178]=0x630000,0x630008
        values[0x630000]=0x510000
        local snapshot=assert(a11y.read_native_windows(base))
        assert(snapshot.members[0x510000].active and snapshot.selected_members[0x510000])
        values[0x510000]=base+0x27c3a38
        assert(a11y.menu_tree(0x310000,base)[0x510000])
    end)
end)

check("integrated title waits for activation then reaches Prism once",function()
    local original=a11y.native_widget_allowed
    local active=false
    a11y.native_widget_allowed=function() return active end
    with_widget_names({[0x110000]="title"},function()
        with_render_harness(function(output)
            emit_ui_text(0x110000,"Escolha sua aparência")
            module.display_frame({})
            assert(#output==0 and a11y.pending_surface_texts[host.memory.hex(0x110000)])
            active=true
            module.display_frame({})
            assert(#output==1 and output[1][1]=="Escolha sua aparência")
            module.display_frame({})
            assert(#output==1)
        end)
    end)
    a11y.native_widget_allowed=original
end)

check("integrated hidden next-screen OK waits for its window to accept input",function()
    local snapshot=a11y.native_windows
    local objects={[0x110000]={focused=true},[0x120000]={focused=false}}
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory(objects,function(tick)
            a11y.native_windows={active={"club"},members={[0x110000]={active=false}}}
            emit_ui_text(0x110000,"OK")
            emit_ui_text(0x120000,"Liverpool FC")
            tick(120);tick(125)
            assert(#speech_texts()==0)
            a11y.native_windows={active={"dialog"},members={[0x110000]={active=true}}}
            tick(130);tick(142)
            assert(#speech_texts()==1 and speech_texts()[1]:find("OK",1,true),table.concat(speech_texts()," | ") .. " reason=" .. tostring(a11y.ui_model.focus_reason))
        end)
    end)
    a11y.native_windows=snapshot
end)

check("integrated team-context reset retains a title that just became active",function()
    local original=a11y.native_widget_allowed
    local active=false
    a11y.native_widget_allowed=function() return active end
    with_widget_names({[0x110000]="title"},function()
        with_render_harness(function(output)
            emit_ui_text(0x110000,"Escolha sua aparência")
            active=true
            module.context_reset({})
            module.display_frame({})
            assert(#output==1 and output[1][1]=="Escolha sua aparência")
            module.display_frame({})
            assert(#output==1)
        end)
    end)
    a11y.native_widget_allowed=original
end)

check("integrated native input setter polling and Prism report deleting accented text",function()
    a11y.keyboard_echo_insertions=true
    local old_read,old_string,old_unpack=a11y.menu_read,a11y.read_msvc_string,host.memory.unpack
    local old_base=upvalue(module.init,"process_base_u64")
    local address,base=0x130000,0x140000000
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    a11y.menu_read=function(ptr)
        if ptr==address then return base+0x27c3a38 end
        if ptr==address+0xc then return 0x107 end
    end
    host.memory.unpack=function(kind,value) if type(value)=="number" then return value end; return old_unpack(kind,value) end
    local value="José"
    a11y.read_msvc_string=function(ptr) assert(ptr==address+0x118); return value end
    a11y.keyboard_window=0x140000
    with_render_harness(function(output)
        module.on_keyboard_input_set({},0,{rcx=address})
        module.display_frame({})
        assert(#output==0)
        value="Jos"
        module.display_frame({})
        assert(#output==1 and output[1][1]=="é")
        module.display_frame({})
        assert(#output==1)
        value=""
        module.display_frame({})
        assert(#output==2 and output[2][1]=="Jos")
        value="di"
        module.display_frame({})
        assert(#output==3 and output[3][1]=="di")
        assert(not a11y.buffer_key(0x49))
    end)
    a11y.menu_read,a11y.read_msvc_string,host.memory.unpack=old_read,old_string,old_unpack
    set_upvalue(module.init,"process_base_u64",old_base)
    a11y.keyboard_echo_insertions=false
end)

check("integrated automatic instructions wait for activation without being discarded",function()
    local original=a11y.native_widget_allowed
    local original_string=a11y.read_msvc_string
    a11y.read_msvc_string=function() return "Enquanto segura o botão A, mova o jogador." end
    local active=false
    a11y.native_widget_allowed=function() return active end
    with_widget_names({[0x110000]="text"},function()
        with_render_harness(function(output)
            emit_ui_text(0x110000,"Enquanto segura o botão A, mova o jogador.")
            module.display_frame({})
            assert(#output==0)
            assert(a11y.pending_surface_texts[host.memory.hex(0x110000)])
            active=true
            module.display_frame({})
            assert(upvalue(module.display_frame,"pending_message_text")=="Enquanto segura o botão A, mova o jogador.")
            set_upvalue(module.display_frame,"pending_message_due_ms",0)
            module.display_frame({})
            module.display_frame({})
            assert(#output==1 and output[1][1]:find("Enquanto segura",1,true))
            module.display_frame({})
            assert(#output==1)
        end)
    end)
    a11y.native_widget_allowed=original
    a11y.read_msvc_string=original_string
end)

check("keyboard blocks background focus and resumes after closing",function()
    with_widget_names({[0x110000]="text"},function()
        with_focus_memory({[0x110000]={focused=true}},function(tick)
            emit_ui_text(0x110000,"Nome do treinador")
            a11y.keyboard_window=0x130000
            tick(120);tick(125)
            assert(#speech_texts()==0)
            a11y.keyboard_window=nil
            tick(130);tick(135)
            assert(#speech_texts()==1)
        end)
    end)
end)

check("production MSVC reader accepts empty strings and preserves accented bytes",function()
    local old_read,old_unpack=host.memory.read,host.memory.unpack
    local old_readable=upvalue(a11y.read_msvc_string,"readable")
    local address=0x110000
    local text="José"
    local function packed(value)
        local pointer=ffi.new("uint64_t[1]",value)
        return ffi.string(pointer,8)
    end
    host.memory.read=function(ptr,size)
        if ptr==address+0x10 then return packed(#text) end
        if ptr==address+0x18 then return packed(15) end
        if ptr==address then return text:sub(1,size) end
        error("unexpected memory read")
    end
    host.memory.unpack=function(kind,bytes)
        if kind=="u64" then local pointer=ffi.new("uint64_t[1]");ffi.copy(pointer,bytes,8);return pointer[0] end
        return old_unpack(kind,bytes)
    end
    set_upvalue(a11y.read_msvc_string,"readable",function() return true end)
    assert(a11y.read_msvc_string(address)=="José")
    text="Jos"
    assert(a11y.read_msvc_string(address)=="Jos")
    text=""
    assert(a11y.read_msvc_string(address)=="")
    text=string.rep("a",16)
    assert(a11y.read_msvc_string(address)==nil)
    host.memory.read,host.memory.unpack=old_read,old_unpack
    set_upvalue(a11y.read_msvc_string,"readable",old_readable)
end)

check("late guidance keeps existing generic field pairs",function()
    local old=a11y.native_widget_allowed
    local active=false
    a11y.native_widget_allowed=function(address) return address~=0x130000 or active end
    with_widget_names({[0x110000]="generic_item",[0x120000]="generic_value",[0x130000]="title"},function()
        emit_ui_text(0x110000,"Opção genérica");emit_ui_text(0x120000,"Valor atual")
        emit_ui_text(0x130000,"Escolha sua aparência")
        active=true
        a11y.poll_surface_texts()
        assert(a11y.ui_model.nodes[host.memory.hex(0x110000)])
        assert(a11y.ui_model.nodes[host.memory.hex(0x120000)])
        assert(a11y.unique_ui_name("generic_item"))
    end)
    a11y.native_widget_allowed=old
end)

check("queued native caption is discarded when its active owner changes",function()
    local old=a11y.native_windows
    with_render_harness(function(output)
        a11y.native_windows={windows={{address=1,enabled=true}},active={"one"},members={}}
        speak("Confirmar, item selecionado",nil,nil,nil,0x110000)
        a11y.native_windows={windows={{address=2,enabled=true}},active={"two"},members={}}
        module.display_frame({})
        assert(#output==0)
        speak("Cancelar, item selecionado",nil,nil,nil,0x120000)
        module.display_frame({})
        assert(#output==1 and output[1][1]=="Cancelar")
    end)
    a11y.native_windows=old
end)

check("queued text cannot survive widget reuse in the same owner",function()
    local key=host.memory.hex(0x110000)
    a11y.ui_model.nodes[key]={identity="first",text="Legenda antiga",address=0x110000}
    with_render_harness(function(output)
        speak("Legenda antiga",nil,nil,nil,0x110000)
        a11y.ui_model.nodes[key].identity="second"
        a11y.ui_model.nodes[key].text="Legenda nova"
        module.display_frame({})
        assert(#output==0)
    end)
end)

check("pending old-screen heading cannot reset the next owner's reading context",function()
    local original,snapshot=a11y.native_widget_allowed,a11y.native_windows
    local active=false
    a11y.native_widget_allowed=function() return active end
    a11y.native_windows={windows={{address=1,enabled=true}},active={"one"},members={}}
    with_widget_names({[0x110000]="title"},function()
        emit_ui_text(0x110000,"Escolha sua aparência")
        a11y.native_windows={windows={{address=2,enabled=true}},active={"two"},members={}}
        active=true
        a11y.read_context_state().title="Tela atual"
        a11y.poll_surface_texts()
        assert(a11y.read_context.title=="Tela atual" and #speech_texts()==0)
    end)
    a11y.native_widget_allowed,a11y.native_windows=original,snapshot
end)

check("production localization callback cannot announce an unbound future paragraph",function()
    local old_read,old_unpack=host.memory.read,host.memory.unpack
    local old_base=upvalue(module.init,"process_base_u64")
    local base,address,stack=0x140000000,0x110000,0x120000
    local text="Há muitas escolhas na carreira de um jogador de futebol. Talvez você prefira ser o defensor leal das cores do seu time de infância, ou então buscar novos ares e novas conquistas em um grande clube. Qual caminho você vai seguir?"
    local function packed(value) return ffi.string(ffi.new("uint64_t[1]",value),8) end
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    host.memory.read=function(ptr,size)
        if tonumber(ptr)==address then return text end
        if tonumber(ptr)==stack+64 then return packed(base+0x123456) end
        error("unexpected resolver memory read")
    end
    host.memory.unpack=function(kind,bytes)
        if kind=="u64" then local pointer=ffi.new("uint64_t[1]");ffi.copy(pointer,bytes,8);return pointer[0] end
        return old_unpack(kind,bytes)
    end
    module.on_resolved_text({},0,{rax=packed(address),r8=packed(#text),rsp=packed(stack),rdi=packed(8094)})
    assert(upvalue(module.display_frame,"pending_message_text")==nil and #speech_texts()==0)
    host.memory.read,host.memory.unpack=old_read,old_unpack
    set_upvalue(module.init,"process_base_u64",old_base)
end)

check("base release version and local development build remain separate",function()
    assert(upvalue(a11y.start_diagnostic,"VERSION")=="0.1.7")
    assert(a11y.build==21 and a11y.runtime_version=="0.1.7")
    assert(a11y.overlay_text():find("0.1.7",1,true))
end)

local function holder_map(values, node, secondary, head, record, child)
    values[node+0x98+(secondary and 0x88 or 8)]=head
    values[head+0x19],values[head+8]=1,record
    values[record+0x19]=0
    values[record],values[record+0x10]=head,head
    values[record+(secondary and 0x40 or 0x30)]=child
end

check("native shared compositions expose both holder maps without indexed children",function()
    with_native_windows(function(values,base)
        values[0x310170],values[0x310178]=0,0
        values[0x320000]=base+0x27cbc08 -- NodeNormal
        values[0x330000]=base+0x27cbe98 -- NodeDuplicate
        holder_map(values,0x310000,false,0x900000,0x901000,0x320000)
        holder_map(values,0x320000,true,0x902000,0x903000,0x330000)
        holder_map(values,0x330000,false,0x904000,0x905000,0x510000)
        local snapshot=assert(a11y.read_native_windows(base))
        assert(snapshot.members[0x510000] and snapshot.members[0x510000].active)
    end)
end)

check("native cursor resolves a composition label through holder ownership",function()
    with_native_windows(function(values,base)
        values[0x310190]=0x800000
        values[0x800000]=base+0x27c1ac0
        values[0x800088],values[0x800090],values[0x800094]=0x310000,0,0
        values[0x610000]=0x320000
        values[0x320000]=base+0x27cb508
        values[0x320170],values[0x320178]=0x620000,0x620008
        values[0x620000]=0x330000
        values[0x330000]=base+0x27cbc08
        holder_map(values,0x330000,false,0x900000,0x901000,0x510000)
        local snapshot=assert(a11y.read_native_windows(base))
        assert(snapshot.selected_members[0x510000] and snapshot.cursor_members[0x510000])
        local _,detail=a11y.menu_cursor_texts(0x310000,base)
        assert(detail.status=="resolved" and detail.selected==0x330000)
        values[0x800094]=1
        _,detail=a11y.menu_cursor_texts(0x310000,base)
        assert(detail.status=="missing-item" and detail.group==0x320000)
    end)
end)

check("native holder maps reject invalid sentinels and contain cycles",function()
    with_native_windows(function(values,base)
        values[0x310170],values[0x310178]=0,0
        holder_map(values,0x310000,false,0x900000,0x901000,0x510000)
        values[0x901000],values[0x901010]=0x901000,0x901000
        assert(a11y.menu_tree(0x310000,base)[0x510000])
        values[0x900019]=0
        assert(not a11y.menu_tree(0x310000,base)[0x510000])
    end)
end)

check("text nodes never acquire a holder by accidental matching bytes",function()
    with_native_windows(function(values,base)
        values[0x520000]=base+0x27b5260
        holder_map(values,0x510000,false,0x900000,0x901000,0x520000)
        local tree=a11y.menu_tree(0x510000,base)
        assert(tree[0x510000] and not tree[0x520000])
    end)
end)

check("holder label ownership changes on return without receiving new text",function()
    with_native_windows(function(values,base)
        values[0x300170],values[0x300178]=0,0
        holder_map(values,0x300000,true,0x900000,0x901000,0x500000)
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_widget_allowed(0x500000))
        values[0x1200009],values[0x1210009]=1,0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_widget_allowed(0x500000))
    end)
end)

check("holder cursor selection drives real focus speech once per movement",function()
    with_native_windows(function(values,base)
        values[0x310190]=0x800000
        values[0x800000]=base+0x27c1ac0
        values[0x800088],values[0x800090],values[0x800094]=0x310000,0,0
        values[0x610000]=0x320000
        values[0x320000]=base+0x27cb508
        values[0x320170],values[0x320178]=0x620000,0x620010
        values[0x620000],values[0x620008]=0x330000,0x340000
        values[0x330000],values[0x340000]=base+0x27cbc08,base+0x27cbe98
        values[0x520000]=base+0x27b5260
        holder_map(values,0x330000,false,0x900000,0x901000,0x510000)
        holder_map(values,0x340000,true,0x902000,0x903000,0x520000)
        with_widget_names({[0x510000]="text",[0x520000]="text"},function()
            with_focus_memory({[0x510000]={focused=true},[0x520000]={focused=true}},function(tick)
                emit_ui_text(0x510000,"Primeiro destino")
                emit_ui_text(0x520000,"Segundo destino")
                a11y.native_windows=assert(a11y.read_native_windows(base))
                tick(120);tick(125)
                assert(#speech_texts()==1 and speech_texts()[1]:find("Primeiro destino",1,true),table.concat(speech_texts()," | "))
                values[0x800094]=1
                a11y.native_windows=assert(a11y.read_native_windows(base))
                tick(130);tick(135)
                assert(#speech_texts()==2 and speech_texts()[2]:find("Segundo destino",1,true),table.concat(speech_texts()," | "))
                values[0x800094]=0
                a11y.native_windows=assert(a11y.read_native_windows(base))
                tick(140);tick(145)
                assert(#speech_texts()==3 and speech_texts()[3]:find("Primeiro destino",1,true),table.concat(speech_texts()," | "))
            end)
        end)
    end)
end)

local native_memory_codec
check("production native traversal reads actual allocated memory and Sider codecs",function()
    local old_read,old_unpack=host.memory.read,host.memory.unpack
    local actual_memory=dofile(sider_dir .. "/../FLAccess/reference/sider7/memory.lua")
    native_memory_codec=actual_memory
    local node=ffi.new("uint64_t[64]")
    local base=0x140000000
    node[0]=base+0x27b5260
    local address=tonumber(ffi.cast("uint64_t",node))
    host.memory.read,host.memory.unpack=actual_memory.read,actual_memory.unpack
    local members=a11y.menu_tree(address,base)
    host.memory.read,host.memory.unpack=old_read,old_unpack
    assert(members[address],"real allocated text node must be recognized")
end)

check("loaded home flow does not silence an observed explicit dialog",function()
    local original=a11y.native_widget_allowed
    local text="Esta seleção não pode ser alterada depois. Quer mesmo continuar?"
    a11y.native_widget_allowed=function() return true end
    a11y.dashboard_review=true
    with_widget_names({[0x110000]="message"},function()
        a11y.observe_ui_widget(0x110000,text)
        remember_message(text,host.memory.hex(0x110000))
    end)
    assert(upvalue(remember_message,"recent_message_text")==text)
    a11y.native_widget_allowed=original
end)

check("loaded home flow still excludes an unbound explicit dialog",function()
    local text="Esta seleção não pode ser alterada depois. Quer mesmo continuar?"
    a11y.dashboard_review=true
    remember_message(text,"unbound-dialog")
    assert(upvalue(remember_message,"recent_message_text")==nil)
end)

check("cursor diagnostic records type of unresolved selected object",function()
    with_native_windows(function(values,base)
        values[0x310190]=0x800000
        values[0x800000]=base+0x27c1ac0
        values[0x800088],values[0x800090],values[0x800094]=0x310000,0,0
        values[0x610000]=0x320000
        values[0x320000]=base+0x27cb508
        values[0x320170],values[0x320178]=0x620000,0x620008
        values[0x620000]=0x330000
        values[0x330000]=base+0x123456
        local members,detail=a11y.menu_cursor_texts(0x310000,base)
        assert(not members and detail.status=="no-text")
        assert(detail.selected_type==base+0x123456)
        assert(a11y.native_node_summary(detail.selected):find("0=",1,true))
    end)
end)

check("production bound localization preserves a dialog until its widget activates",function()
    jit.flush() -- Previous case used real pointers; this case supplies mock addresses.
    local old_read,old_unpack,old_allowed=host.memory.read,host.memory.unpack,a11y.native_widget_allowed
    local old_base=upvalue(module.init,"process_base_u64")
    local base,address,stack,widget=0x140000000,0x210000,0x220000,0x230000
    local text="Esta seleção não pode ser alterada depois. Quer mesmo continuar?"
    local function packed(value) return ffi.string(ffi.new("uint64_t[1]",value),8) end
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    host.memory.read=function(ptr,size)
        local at=tonumber(ptr)
        if at==address then return text end
        if at==stack+64 then return packed(base+0xe4901d) end
        if at==stack+72 then return packed(widget) end
        return string.rep("\0",size)
    end
    host.memory.unpack=function(kind,bytes)
        if not bytes then return 0 end
        if kind=="u64" then return ffi.cast("uint64_t*",bytes)[0] end
        return old_unpack(kind,bytes)
    end
    a11y.native_widget_allowed=function() return false end
    with_widget_names({[widget]="message"},function()
        module.on_resolved_text({},0,setmetatable({rax=packed(address),r8=packed(#text),rsp=packed(stack),rdi=packed(1)},
            {__index=function() return packed(0) end}))
        local key=host.memory.hex(widget)
        assert(a11y.pending_surface_texts[key] and a11y.ui_model.nodes[key].text==text,
            tostring(key) .. " " .. tostring(logs[#logs]) .. " nodes=" .. tostring(a11y.ui_model.count))
        assert(#speech_texts()==0,"inactive dialog cannot speak during construction")
        a11y.native_widget_allowed=function() return true end
        a11y.dashboard_review=true
        a11y.poll_surface_texts()
        assert(not a11y.pending_surface_texts[key])
        assert(upvalue(remember_message,"recent_message_text")==text)
        assert(a11y.read_context_state().kind=="dialog")
    end)
    host.memory.read,host.memory.unpack,a11y.native_widget_allowed=old_read,old_unpack,old_allowed
    set_upvalue(module.init,"process_base_u64",old_base)
end)

check("shared engine events select arbitrary labels without a native tree or sticky flags",function()
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Alvo comum A"); emit_ui_text(0x120000,"Alvo comum B")
            a11y.record_engine_focus(0x110000,true)
            tick(120); assert(#speech_texts()==0,"hook must wait for the next frame")
            tick(121); tick(125)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Alvo comum A",1,true))
            a11y.record_engine_focus(0x110000,false)
            a11y.record_engine_focus(0x120000,true)
            tick(126);tick(130)
            assert(#speech_texts()==2 and speech_texts()[2]:find("Alvo comum B",1,true))
            a11y.record_engine_focus(0x120000,false)
            a11y.record_engine_focus(0x110000,true)
            tick(131);tick(135)
            assert(#speech_texts()==3 and speech_texts()[3]:find("Alvo comum A",1,true))
        end)
    end)
end)

check("engine event burst coalesces generic label and value into one control",function()
    with_widget_names({[0x110000]="new_item",[0x120000]="new_value"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            emit_ui_text(0x120000,"Valor inicial");emit_ui_text(0x110000,"Campo compartilhado")
            a11y.record_engine_focus(0x110000,true);a11y.record_engine_focus(0x120000,true)
            tick(121);tick(125)
            assert(#speech_texts()==1 and speech_texts()[1]=="Campo compartilhado, seletor, Valor inicial")
        end)
    end)
end)

check("engine selection waits for a late label rather than inventing a caption",function()
    with_widget_names({[0x110000]="text"},function()
        with_focus_memory({[0x110000]={focused=false}},function(tick)
            a11y.record_engine_focus(0x110000,true)
            tick(121);assert(#speech_texts()==0)
            emit_ui_text(0x110000,"Legenda tardia")
            tick(122);tick(127)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Legenda tardia",1,true))
        end)
    end)
end)

check("engine focus from the previous native owner cannot arbitrate a new window",function()
    local old=a11y.native_windows
    a11y.native_windows={windows={{address=0x210000,enabled=true}}}
    a11y.record_engine_focus(0x110000,true)
    a11y.native_windows={windows={{address=0x220000,enabled=true}}}
    assert(a11y.engine_focus_candidates()==nil and not a11y.engine_focus)
    a11y.native_windows=old
end)

check("production engine event callback decodes identifiers and only records focus",function()
    local old_read=a11y.menu_read
    local old_unpack=host.memory.unpack
    local old_base=upvalue(module.init,"process_base_u64")
    local base,widget,event,array=0x140000000,0x110000,0x120000,0x130000
    local values={[base+0x36f9c28]=array,[base+0x36f9c30]=array+32*8,
        [widget]=base+0x27b5260,[event]=0x200000,[array+15*8]=0x200000,[array+14*8]=0x210000}
    a11y.menu_read=function(at) return values[at] end
    host.memory.unpack=function(_,bytes) return ffi.cast("uint64_t*",bytes)[0] end
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    local function packed(value) return ffi.string(ffi.new("uint64_t[1]",value),8) end
    local registers={rcx=packed(widget),rdx=packed(event)}
    module.on_ui_focus_event({},0,registers)
    assert(a11y.engine_focus.nodes[host.memory.hex(widget)] and #speech_texts()==0)
    values[event]=0x210000
    module.on_ui_focus_event({},0,registers)
    assert(not a11y.engine_focus.nodes[host.memory.hex(widget)])
    values[event]=0x300000
    module.on_ui_focus_event({},0,registers)
    assert(a11y.engine_focus.count==0,"unrelated native events must not select anything")
    a11y.menu_read,host.memory.unpack=old_read,old_unpack
    set_upvalue(module.init,"process_base_u64",old_base)
end)

check("a focus exit alone does not take authority away from existing readers",function()
    a11y.record_engine_focus(0x110000,false)
    assert(a11y.engine_focus==nil and a11y.engine_focus_candidates()==nil)
end)

check("same caption on separate engine targets remains two movements",function()
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Destino igual");emit_ui_text(0x120000,"Destino igual")
            a11y.record_engine_focus(0x110000,true);tick(121)
            a11y.record_engine_focus(0x110000,false)
            a11y.record_engine_focus(0x120000,true);tick(122)
            assert(#speech_texts()==2)
            assert(a11y.native_speech_queue[1].identity~=a11y.native_speech_queue[2].identity)
        end)
    end)
end)

check("queued engine focus is discarded after a newer movement before Prism flush",function()
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            with_render_harness(function(output)
                emit_ui_text(0x110000,"Destino anterior");emit_ui_text(0x120000,"Destino atual")
                a11y.record_engine_focus(0x110000,true);tick(121)
                a11y.record_engine_focus(0x110000,false)
                a11y.record_engine_focus(0x120000,true);tick(122)
                a11y.flush_native_speech(1000)
                assert(#output==1 and output[1][1]:find("Destino atual",1,true))
            end)
        end)
    end)
end)

check("paragraph events alone cannot take menu focus authority",function()
    with_widget_names({[0x110000]="message"},function()
        a11y.observe_ui_widget(0x110000,"Esta seleção não pode ser alterada depois. Quer mesmo continuar?")
        a11y.record_engine_focus(0x110000,true)
        assert(a11y.engine_focus_candidates()==nil)
    end)
end)

check("captured training compound focuses its main field rather than its result counter",function()
    -- dev 7 frame 13294: these three NodeRectText receivers share +0x38.
    local nodes={
        [0x43a2fdf0]={name="text_item",text="Drible"},
        [0x5cf20860]={name="infoText_item",text="Resultado"},
        [0x82ae8ab0]={name="infoText_value",text="0"},
    }
    local names,objects={},{}
    for at,node in pairs(nodes) do names[at]=node.name;objects[at]={focused=false} end
    local original=a11y.ui_owner_link
    a11y.ui_owner_link=function() return 0x660e6970 end
    with_widget_names(names,function()
        with_focus_memory(objects,function(tick)
            for at,node in pairs(nodes) do emit_ui_text(at,node.text) end
            for at in pairs(nodes) do a11y.record_engine_focus(at,true) end
            tick(121);tick(126)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Drible",1,true))
            assert(not speech_texts()[1]:find("Resultado",1,true))
            assert(a11y.ui_model.nodes[host.memory.hex(0x5cf20860)],"auxiliary data must remain recorded")
        end)
    end)
    a11y.ui_owner_link=original
end)

check("captured settings compound keeps its label and value but excludes bare decorative text",function()
    -- dev 7 frame 15001: label/value plus abilityNumber all receive focus.
    local names={[0x5cf03520]="setName",[0x660e62f0]="text",[0x660e41f0]="abilityNumber",[0x110000]="padIcon"}
    with_widget_names(names,function()
        with_focus_memory({[0x5cf03520]={focused=false},[0x660e62f0]={focused=false},[0x660e41f0]={focused=false},[0x110000]={focused=false}},function(tick)
            emit_ui_text(0x5cf03520,"Duração da partida")
            -- This label also went through bound localization in the capture.
            upvalue(module.on_resolved_text,"register_control_label")(
                "Duração da partida",0x5cf03520,"seletor",true)
            emit_ui_text(0x660e62f0,"10 min.")
            emit_ui_text(0x660e41f0,"0")
            emit_ui_text(0x110000,"botão A")
            for at in pairs(names) do a11y.record_engine_focus(at,true) end
            tick(121);tick(127)
            assert(#speech_texts()==1 and speech_texts()[1]=="Duração da partida, seletor, 10 min.",
                table.concat(speech_texts()," | ") .. " reason=" .. tostring(a11y.ui_model.focus_reason))
        end)
    end)
end)

check("information slot from another native resource cannot be merged into a primary field",function()
    local original=a11y.ui_owner_link
    a11y.ui_owner_link=function(at) return tonumber(at)==0x110000 and 0x310000 or 0x320000 end
    with_widget_names({[0x110000]="text_item",[0x120000]="infoText_item"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Escolha independente");emit_ui_text(0x120000,"Informação de outro objeto")
            a11y.record_engine_focus(0x110000,true);a11y.record_engine_focus(0x120000,true)
            tick(121);tick(126)
            assert(#speech_texts()==0,"unrelated simultaneous targets remain ambiguous")
        end)
    end)
    a11y.ui_owner_link=original
end)

check("recycled resource link invalidates an old caption before focus arbitration",function()
    local original=a11y.ui_owner_link
    local reused=false
    a11y.ui_owner_link=function(at)
        if tonumber(at)==0x120000 then return reused and 0x330000 or 0x320000 end
        return 0x310000
    end
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Alvo válido");emit_ui_text(0x120000,"Legenda antiga")
            reused=true
            a11y.record_engine_focus(0x110000,true);a11y.record_engine_focus(0x120000,true)
            tick(121);tick(126)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Alvo válido",1,true))
            assert(not a11y.ui_model.nodes[host.memory.hex(0x120000)])
        end)
    end)
    a11y.ui_owner_link=original
end)

check("numeric zero stays selectable when it is a linked control value",function()
    with_widget_names({[0x110000]="amount_item",[0x120000]="amount_value"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Quantidade atual");emit_ui_text(0x120000,"0")
            a11y.record_engine_focus(0x110000,true);a11y.record_engine_focus(0x120000,true)
            tick(121);tick(126)
            assert(#speech_texts()==1 and speech_texts()[1]=="Quantidade atual, seletor, 0")
        end)
    end)
end)

check("focus propagation redraws do not repeat a committed item",function()
    with_widget_names({[0x110000]="text"},function()
        with_focus_memory({[0x110000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Mesmo destino")
            a11y.record_engine_focus(0x110000,true);tick(121)
            for f=122,142,2 do
                a11y.record_engine_focus(0x110000,false);tick(f)
                a11y.record_engine_focus(0x110000,true);tick(f+1)
            end
            assert(#speech_texts()==1,"redraw is not navigation")
        end)
    end)
end)

check("temporary focus ambiguity cannot reannounce the same surviving target",function()
    local original=a11y.native_widget_allowed
    local secondary=false
    a11y.native_widget_allowed=function(at) return tonumber(at)~=0x120000 or secondary end
    with_widget_names({[0x110000]="text",[0x120000]="text"},function()
        with_focus_memory({[0x110000]={focused=false},[0x120000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Destino estável");emit_ui_text(0x120000,"Outro destino")
            a11y.record_engine_focus(0x110000,true);a11y.record_engine_focus(0x120000,true)
            tick(121);assert(#speech_texts()==1)
            secondary=true;tick(122)
            secondary=false;tick(123)
            assert(#speech_texts()==1)
        end)
    end)
    a11y.native_widget_allowed=original
end)

check("preallocated dialog option accepts a fresh engine focus in the same native window",function()
    local snapshot=a11y.native_windows
    a11y.native_windows={windows={{address=0x310000,enabled=true}},members={}}
    with_widget_names({[0x110000]="text"},function()
        with_focus_memory({[0x110000]={focused=false}},function(tick)
            emit_ui_text(0x110000,"Usar")
            tick(300)
            a11y.open_read_dialog("Quer mesmo continuar?","prompt")
            a11y.record_engine_focus(0x110000,true)
            tick(301);tick(305)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Usar",1,true))
        end)
    end)
    a11y.native_windows=snapshot
end)

check("dialog ownership change clears stale reading hold even for an unknown message widget",function()
    with_native_windows(function(values,base)
        local old_enabled,old_frame=a11y.native_windows_enabled,a11y.native_windows_frame
        a11y.native_windows=assert(a11y.read_native_windows(base))
        a11y.open_read_dialog("Quer mesmo continuar?","unobserved-message")
        set_upvalue(speak,"modal_focus_hold_until_ms",999999999999)
        values[0x1200009],values[0x1210009]=1,0
        a11y.native_windows_enabled=true;a11y.native_windows_frame=nil
        local old_base=upvalue(module.init,"process_base_u64")
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        a11y.poll_native_windows()
        assert(a11y.read_context_state().kind=="unknown")
        assert(upvalue(speak,"modal_focus_hold_until_ms")==0)
        a11y.native_windows_enabled,a11y.native_windows_frame=old_enabled,old_frame
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end)

check("review retains text written before activation but rejects a previous owner",function()
    local snapshot,allowed=a11y.native_windows,a11y.native_widget_allowed
    local active=false
    a11y.native_windows={windows={{address=0x310000,enabled=true}}}
    a11y.native_widget_allowed=function() return active end
    a11y.dashboard_review=true
    with_widget_names({[0x110000]="date"},function()
        local node=a11y.observe_ui_widget(0x110000,"15 de agosto")
        a11y.record_dashboard_text(node)
        assert(#a11y.buffer_entries()==0)
        active=true;assert(#a11y.buffer_entries()==1)
        a11y.native_windows={windows={{address=0x320000,enabled=true}}}
        assert(#a11y.buffer_entries()==0)
    end)
    a11y.native_windows,a11y.native_widget_allowed=snapshot,allowed
end)

check("guidance waits for native window construction before speaking its title",function()
    with_native_windows(function(values,base)
        local enabled,old_base=a11y.native_windows_enabled,upvalue(module.init,"process_base_u64")
        a11y.native_windows_enabled=true
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        values[0x1210098]=0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        with_widget_names({[0x510000]="title"},function()
            a11y.observe_ui_widget(0x510000,"Escolha sua aparência")
            a11y.defer_bound_guidance(0x510000,"Escolha sua aparência")
            a11y.poll_surface_texts();assert(#speech_texts()==0)
            values[0x1210098]=0x310000
            a11y.native_windows=assert(a11y.read_native_windows(base))
            a11y.poll_surface_texts()
            assert(#speech_texts()==1 and speech_texts()[1]=="Escolha sua aparência")
        end)
        a11y.native_windows_enabled=enabled
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end)

check("skip caption never guesses between conflicting icons and can use a late confirmed icon",function()
    local foreground=a11y.game_is_foreground
    a11y.game_is_foreground=function() return true end
    a11y.skip_hint_last_frame=-10000
    with_widget_names({[0x110000]="skipCaption",[0x120000]="padIcon",[0x130000]="padIcon"},function()
        with_focus_memory({},function(tick)
            local caption=a11y.observe_ui_widget(0x110000,"Pular")
            caption.owner_link=123
            local first=a11y.observe_ui_widget(0x120000,"botão A");first.owner_link=123
            local second=a11y.observe_ui_widget(0x130000,"botão B");second.owner_link=123
            a11y.announce_skip_hint("Pular",caption)
            tick(133);a11y.poll_skip_hint()
            assert(#speech_texts()==1 and speech_texts()[1]=="Pular")
            second.text="botão A"
            tick(134);a11y.poll_skip_hint()
            assert(#speech_texts()==2 and speech_texts()[2]=="Pular, botão A")
        end)
    end)
    a11y.game_is_foreground=foreground
end)

check("a partial player-name match cannot establish squad status",function()
    with_widget_names({[0x110000]="subPlayerName"},function()
        with_focus_memory({[0x110000]={focused=false}},function()
            emit_ui_text(0x110000,"João Silva Filho")
            local original=host.memory.read
            host.memory.read=function(at,size)
                if at==0x110000+0x18 and size==24 then return "subPlayerName" .. string.rep("\0",11) end
                return original(at,size)
            end
            assert(a11y.game_plan_player_section("João Silva",nil)==nil)
            host.memory.read=original
        end)
    end)
end)

check("retained yes/no option cannot remain active in a different native owner",function()
    local snapshot=a11y.native_windows
    a11y.native_windows={windows={{address=0x310000,enabled=true}},members={}}
    local option={address=0x110000,native_owner=a11y.native_owner_token()}
    assert(a11y.dialog_option_allowed(option))
    a11y.native_windows={windows={{address=0x320000,enabled=true}},members={}}
    assert(not a11y.dialog_option_allowed(option))
    a11y.native_windows=snapshot
end)


local function with_components(entries,fn)
    local old=a11y.native_windows
    local names,parents={},{}
    for address,item in pairs(entries) do names[address]=item.name;parents[address]=item.parent end
    local owner={address=0x800000,root=0x900000,enabled=true,parents=parents}
    local snapshot={windows={{address=owner.address,root=owner.root,enabled=true}},
        members={},selected_members={},cursor_members={}}
    for address in pairs(entries) do snapshot.members[address]={active=true,owners={owner}} end
    with_widget_names(names,function()
        a11y.native_windows=snapshot
        for address,item in pairs(entries) do a11y.observe_ui_widget(address,item.text) end
        fn(snapshot,parents,owner)
    end)
    a11y.native_windows=old
end

check("third native holder map reaches labels and proves inactive ownership",function()
    with_native_windows(function(values,base)
        values[0x300170],values[0x300178]=0,0
        values[0x300098+0x78]=0x900000
        values[0x900019],values[0x900008]=1,0x901000
        values[0x901019],values[0x901000],values[0x901010]=0,0x900000,0x900000
        values[0x901040]=0x500000
        local tree,parents=a11y.menu_tree(0x300000,base)
        assert(tree[0x500000] and parents[0x500000]==0x300000)
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_widget_allowed(0x500000))
        values[0x1200009],values[0x1210009]=1,0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_widget_allowed(0x500000))
    end)
end)

check("cursor polling supersedes old engine events and reads commands without new writes",function()
    with_components({[0x110000]={name="text",text="Avançar",parent=0x210000},
            [0x120000]={name="text",text="Destino seguinte",parent=0x220000}},function(snapshot)
        with_focus_memory({},function(tick)
            snapshot.selected_members[0x110000]=true
            snapshot.cursor_members[0x110000],snapshot.cursor_members[0x120000]=true,true
            a11y.record_engine_focus(0x120000,true)
            tick(120);tick(123)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Avançar",1,true))
            snapshot.selected_members={[0x120000]=true}
            tick(130);tick(133)
            assert(#speech_texts()==2 and speech_texts()[2]:find("Destino seguinte",1,true))
            tick(135);assert(#speech_texts()==2)
            snapshot.selected_members={[0x110000]=true}
            tick(140);tick(143)
            assert(#speech_texts()==3 and speech_texts()[3]==speech_texts()[1])
        end)
    end)
end)

check("cursor waits for an unobserved label instead of falling back to stale focus",function()
    with_components({[0x110000]={name="text",text="Fundo antigo",parent=0x210000},
            [0x120000]={name="text",text="País de destino",parent=0x220000}},function(snapshot)
        local key=host.memory.hex(0x120000)
        a11y.forget_ui_widget(key)
        with_focus_memory({[0x110000]={focused=true}},function(tick)
            snapshot.selected_members={[0x120000]=true}
            snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
            tick(120);tick(125);assert(#speech_texts()==0)
            a11y.observe_ui_widget(0x120000,"País de destino")
            tick(130);tick(135)
            assert(#speech_texts()==1 and speech_texts()[1]:find("País de destino",1,true))
        end)
    end)
end)

check("repeated field names pair by native component rather than global uniqueness",function()
    local entries={[0x110000]={name="field_item",text="Ajuste A",parent=0x210000},
        [0x120000]={name="field_value",text="10",parent=0x210000},
        [0x130000]={name="field_item",text="Ajuste B",parent=0x220000},
        [0x140000]={name="field_value",text="20",parent=0x220000}}
    with_components(entries,function(snapshot)
        with_focus_memory({},function(tick)
            for _,address in ipairs({0x110000,0x120000,0x130000,0x140000}) do
                emit_ui_text(address,entries[address].text)
            end
            a11y.rebind_presented_control(a11y.ui_model.nodes[host.memory.hex(0x120000)])
            a11y.rebind_presented_control(a11y.ui_model.nodes[host.memory.hex(0x140000)])
            assert(a11y.structural_control_row(0x120000).value=="10")
            assert(a11y.structural_control_row(0x140000).value=="20")
            snapshot.cursor_members={[0x110000]=true,[0x120000]=true,[0x130000]=true,[0x140000]=true}
            snapshot.selected_members={[0x110000]=true,[0x120000]=true}
            tick(120);tick(123)
            assert(#speech_texts()==1 and speech_texts()[1]=="Ajuste A, seletor, 10")
            snapshot.selected_members={[0x130000]=true,[0x140000]=true}
            tick(130);tick(133)
            assert(#speech_texts()==2 and speech_texts()[2]=="Ajuste B, seletor, 20")
        end)
    end)
end)

check("native current tree supplies review details without home metadata",function()
    with_components({[0x110000]={name="date",text="15 de agosto",parent=0x210000},
            [0x120000]={name="news",text="Notícia apresentada",parent=0x220000},
            [0x130000]={name="text",text="Fundo oculto",parent=0x230000}},function(snapshot)
        snapshot.members[0x130000].active=false
        assert(not a11y.dashboard_review)
        local entries=a11y.buffer_entries()
        assert(#entries==2 and not table.concat(entries," "):find("Fundo oculto",1,true))
        snapshot.members[0x120000].active=false
        assert(#a11y.buffer_entries()==1)
    end)
end)

check("preallocated dialog is discovered on presentation instead of needing a new write",function()
    with_components({[0x110000]={name="message",text="Esta seleção não pode ser alterada depois. Quer mesmo continuar?",parent=0x210000}},function()
        assert(upvalue(module.display_frame,"pending_message_text")==nil)
        a11y.poll_presented_texts()
        assert(upvalue(module.display_frame,"pending_message_text"):find("Quer mesmo continuar?",1,true))
        assert(a11y.read_context.kind=="dialog")
        local before=#a11y.modal_message_backlog
        a11y.poll_presented_texts()
        assert(#a11y.modal_message_backlog==before)
        assert(#a11y.buffer_entries()==1,"dialog review must exclude unrelated menu content")
    end)
end)

check("same window address with a new root invalidates queued old text",function()
    local snapshot=a11y.native_windows
    with_render_harness(function(output)
        a11y.native_windows={windows={{address=1,root=0x210000,enabled=true}},members={}}
        speak("Texto do conteúdo antigo",nil,nil,nil,0x110000)
        a11y.native_windows={windows={{address=1,root=0x220000,enabled=true}},members={}}
        module.display_frame({})
        assert(#output==0)
    end)
    a11y.native_windows=snapshot
end)

check("skip chooses only the observed icon in its own native component",function()
    with_components({[0x110000]={name="skipCaption",text="Pular",parent=0x210000},
        [0x120000]={name="padIcon",text="botão X",parent=0x210000},
        [0x130000]={name="padIcon",text="botão Y",parent=0x220000}},function()
        local before=a11y.game_is_foreground
        a11y.game_is_foreground=function() return true end
        for _,node in pairs(a11y.ui_model.nodes) do node.owner_link=123 end
        a11y.skip_hint_last_frame=-10000
        a11y.announce_skip_hint("Pular",a11y.ui_model.nodes[host.memory.hex(0x110000)])
        a11y.poll_skip_hint()
        assert(speech_texts()[1]=="Pular, botão X")
        a11y.game_is_foreground=before
    end)
end)

check("roster status follows three native list sections and never goalkeeper position",function()
    local entries={[0x110000]={name="heading",text="Titulares",parent=0x210000},
        [0x120000]={name="playerName",text="Jogador Um",parent=0x210000},
        [0x130000]={name="heading",text="Reservas",parent=0x220000},
        [0x140000]={name="playerName",text="Jogador Dois",parent=0x220000},
        [0x150000]={name="heading",text="Não relacionados",parent=0x230000},
        [0x160000]={name="subPlayerName",text="Jogador Três",parent=0x230000}}
    with_components(entries,function(_,parents)
        parents[0x210000],parents[0x220000],parents[0x230000]=0x900000,0x900000,0x900000
        assert(a11y.game_plan_player_section("Jogador Um",nil)=="starter")
        assert(a11y.game_plan_player_section("Jogador Dois",nil)=="reserve")
        assert(a11y.game_plan_player_section("Jogador Três",nil)=="unselected")
        a11y.forget_ui_widget(host.memory.hex(0x150000))
        assert(a11y.game_plan_player_section("Jogador Três",nil)==nil,
            "subPlayerName alone does not distinguish bench from not selected")
    end)
end)

check("conflicting roster headings in a shared component cannot classify a player",function()
    with_components({[0x110000]={name="heading",text="Reservas",parent=0x210000},
        [0x120000]={name="heading",text="Não relacionados",parent=0x210000},
        [0x130000]={name="subPlayerName",text="Jogador Um",parent=0x210000}},function()
        assert(a11y.game_plan_player_section("Jogador Um",nil)==nil)
    end)
end)

check("queued answer cannot survive a newer selection in the same dialog",function()
    a11y.open_read_dialog("Qual alternativa?","question")
    a11y.commit_read_selection("Primeira resposta","first","dialog-answer")
    local stamp={generation=a11y.read_context.generation,identity="first"}
    assert(a11y.reading_selection_delivery_allowed(stamp))
    a11y.commit_read_selection("Segunda resposta","second","dialog-answer")
    assert(not a11y.reading_selection_delivery_allowed(stamp))
    a11y.reset_read_context("return")
    assert(not a11y.reading_selection_delivery_allowed(stamp))
end)

check("the text probe targets the final native setter with a complete relocatable prologue",function()
    local install=upvalue(module.init,"install_selector_probes")
    assert(upvalue(install,"UI_TEXT_SET_RVA")==0xe49070)
end)


check("blocked speech does not permanently consume an engine selection",function()
    with_components({[0x110000]={name="text",text="OK",parent=0x210000}},function(snapshot)
        with_focus_memory({},function(tick)
            snapshot.selected_members={[0x110000]=true}
            snapshot.cursor_members={[0x110000]=true}
            set_upvalue(speak,"pending_message_text","Mensagem em preparação")
            tick(120);tick(123)
            assert(#speech_texts()==0 and not a11y.engine_focus.last_identity)
            set_upvalue(speak,"pending_message_text",nil)
            tick(130);tick(133)
            assert(#speech_texts()==1 and speech_texts()[1]:find("OK",1,true))
        end)
    end)
end)

check("changing native roots clears old menu review and pending dialog before rediscovery",function()
    with_native_windows(function(values,base)
        local enabled,old_frame=a11y.native_windows_enabled,a11y.native_windows_frame
        local old_base=upvalue(module.init,"process_base_u64")
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        a11y.native_windows_enabled,a11y.native_windows_frame=true,nil
        a11y.native_windows=assert(a11y.read_native_windows(base))
        a11y.set_read_title("Título anterior")
        a11y.commit_read_selection("Seleção anterior","old","test")
        values[0x1210098]=0x320000
        values[0x320000]=base+0x27cb508
        values[0x320170],values[0x320178]=0,0
        a11y.poll_native_windows()
        assert(not a11y.read_context.title and not a11y.read_context.selection)
        assert(#a11y.buffer_entries()==0)
        local text="Esta seleção não pode ser alterada depois. Quer mesmo continuar?"
        with_widget_names({[0x510000]="message"},function()
            a11y.observe_ui_widget(0x510000,text)
            remember_message(text,host.memory.hex(0x510000))
            assert(upvalue(module.display_frame,"pending_message_text")==text)
            values[0x1210098]=0x330000
            values[0x330000]=base+0x27cb508
            values[0x330170],values[0x330178]=0,0
            a11y.native_windows_frame=nil
            a11y.poll_native_windows()
            assert(upvalue(module.display_frame,"pending_message_text")==nil)
            assert(not a11y.read_context.question)
        end)
        a11y.native_windows_enabled,a11y.native_windows_frame=enabled,old_frame
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end)

check("third-map cursor reaches Prism through moves and return with stale flags fixed",function()
    with_native_windows(function(values,base)
        values[0x310190]=0x800000
        values[0x800000]=base+0x27c1ac0
        values[0x800088],values[0x800090],values[0x800094]=0x310000,0,0
        values[0x610000]=0x320000
        values[0x320000]=base+0x27cb508
        values[0x320170],values[0x320178]=0x620000,0x620010
        values[0x620000],values[0x620008]=0x330000,0x340000
        values[0x330000],values[0x340000]=base+0x27cb508,base+0x27cb508
        for index,node in ipairs({0x330000,0x340000}) do
            local head,record=0x900000+index*0x2000,0x901000+index*0x2000
            values[node+0x98+0x78]=head
            values[head+0x19],values[head+8]=1,record
            values[record+0x19],values[record],values[record+0x10]=0,head,head
            values[record+0x40]=index==1 and 0x510000 or 0x520000
        end
        values[0x520000]=base+0x27b5260
        with_widget_names({[0x510000]="text",[0x520000]="text"},function()
            with_focus_memory({},function(tick)
                with_render_harness(function(output)
                    a11y.observe_ui_widget(0x510000,"Item independente A")
                    a11y.observe_ui_widget(0x520000,"Item independente B")
                    a11y.native_windows=assert(a11y.read_native_windows(base))
                    tick(120);tick(123);module.display_frame({})
                    assert(#output==1 and output[1][1]:find("Item independente A",1,true))
                    values[0x800094]=1
                    a11y.native_windows=assert(a11y.read_native_windows(base))
                    tick(130);tick(133);module.display_frame({})
                    assert(#output==2 and output[2][1]:find("Item independente B",1,true))
                    values[0x800094]=0
                    a11y.native_windows=assert(a11y.read_native_windows(base))
                    tick(140);tick(143);module.display_frame({})
                    assert(#output==3 and output[3][1]==output[1][1])
                end)
            end)
        end)
    end)
end)


check("structural question waits for a root instead of consuming its automatic announcement",function()
    with_native_windows(function(values,base)
        local enabled,old_base=a11y.native_windows_enabled,upvalue(module.init,"process_base_u64")
        a11y.native_windows_enabled=true
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        values[0x1210098]=0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        with_widget_names({[0x510000]="question"},function()
            local node=a11y.observe_ui_widget(0x510000,"Qual alternativa deseja usar?")
            node.owner_link=123
            assert(not a11y.capture_question_panel(node))
            assert(a11y.read_context.kind~="dialog")
            assert(a11y.pending_surface_texts[node.key].kind=="panel")
            values[0x1210098]=0x310000
            a11y.native_windows=assert(a11y.read_native_windows(base))
            a11y.poll_surface_texts()
            assert(a11y.read_context.structural_question and a11y.read_context.kind=="dialog")
            assert(upvalue(module.display_frame,"pending_message_text")==node.text)
        end)
        a11y.native_windows_enabled=enabled
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end)

check("every producer's queued speech is discarded on native presentation change",function()
    local snapshot=a11y.native_windows
    with_render_harness(function(output)
        a11y.native_windows={windows={{address=1,root=0x210000,enabled=true}},members={}}
        speak("Legenda de produtor sem widget")
        a11y.native_windows={windows={{address=1,root=0x220000,enabled=true}},members={}}
        module.display_frame({})
        assert(#output==0)
    end)
    a11y.native_windows=snapshot
end)

check("native player component adds the observed section without a screen-name adapter",function()
    with_components({[0x110000]={name="heading",text="Não relacionados",parent=0x210000},
        [0x120000]={name="playerName",text="Jogador Um",parent=0x210000}},function(snapshot)
        with_focus_memory({},function(tick)
            snapshot.selected_members={[0x120000]=true}
            snapshot.cursor_members={[0x120000]=true}
            tick(120);tick(123)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Não relacionado. Jogador Um",1,true))
        end)
    end)
end)


check("pending title binds to its proven inactive native owner when that owner opens",function()
    with_native_windows(function(values,base)
        a11y.native_windows=assert(a11y.read_native_windows(base))
        with_widget_names({[0x500000]="title"},function()
            local node=a11y.observe_ui_widget(0x500000,"Escolha sua aparência")
            a11y.defer_bound_guidance(node.address,node.text)
            local item=a11y.pending_surface_texts[node.key]
            assert(item and item.origin.target_windows[0x1100000])
            a11y.poll_surface_texts();assert(#speech_texts()==0)
            values[0x1200009],values[0x1210009]=1,0
            a11y.native_windows=assert(a11y.read_native_windows(base))
            a11y.poll_surface_texts()
            assert(#speech_texts()==1 and speech_texts()[1]==node.text)
        end)
    end)
end)


check("plain output removes synthetic roles for every producer but preserves actual values and states",function()
    with_render_harness(function(output)
        speak("Duração, seletor, 10 min.")
        speak("Confirmar, botão selecionado")
        speak("Nome do treinador, ativar para editar, José")
        speak("Concordo., opção selecionada")
        speak("Lesões, Marcado")
        module.display_frame({})
        assert(#output==5)
        assert(output[1][1]=="Duração, 10 min.")
        assert(output[2][1]=="Confirmar")
        assert(output[3][1]=="Nome do treinador, José")
        assert(output[4][1]=="Concordo.")
        assert(output[5][1]=="Lesões, Marcado")
    end)
end)

check("printf placeholders never become speech or review captions",function()
    assert(a11y.unresolved_format("%3$d|/%2$d|/%1$d|"))
    assert(a11y.unresolved_format("%d"))
    assert(not a11y.unresolved_format("100%"))
    speak("%d, item selecionado");assert(#speech_texts()==0)
    speak("100%");assert(speech_texts()[1]=="100%")
end)

check("native renderer getter follows the validated text setter into actual allocated memory",function()
    local old_read,old_unpack=host.memory.read,host.memory.unpack
    local old_base=upvalue(module.init,"process_base_u64")
    local actual=assert(native_memory_codec)
    local base=0x140000000
    local node,renderer,vt,raw=ffi.new("uint8_t[512]"),ffi.new("uint8_t[256]"),ffi.new("uint64_t[4]"),ffi.new("char[128]","PORTUGAL")
    local function ptr(value) return tonumber(ffi.cast("uint64_t",value)) end
    local function put(buffer,offset,value) ffi.cast("uint64_t*",buffer+offset)[0]=value end
    put(node,0,base+0x27b5260);put(node,0xa8,ptr(renderer))
    put(renderer,0,ptr(vt));put(renderer,0x38,ptr(raw));vt[2]=base+0xe29e40
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    host.memory.read,host.memory.unpack=actual.read,actual.unpack
    assert(a11y.read_native_rendered_text(ptr(node))=="PORTUGAL")
    ffi.copy(raw,"BRASIL\0",7)
    assert(a11y.read_native_rendered_text(ptr(node))=="BRASIL")
    vt[2]=base+0xe2fa60
    assert(a11y.read_native_rendered_text(ptr(node))=="BRASIL","default factory proxy retains the same native text")
    vt[2]=base+0x12345
    assert(a11y.read_native_rendered_text(ptr(node))==nil,"unknown renderer layout grants no text authority")
    ffi.fill(raw,128,65)
    assert(a11y.read_native_c_string(ptr(raw),64)==nil,"unterminated text cannot escape its limit")
    host.memory.read,host.memory.unpack=old_read,old_unpack
    set_upvalue(module.init,"process_base_u64",old_base)
end)

local function with_rendered_panel(entries,fn)
    local getter,reader,enabled,poll=a11y.read_native_rendered_text,a11y.menu_read,a11y.native_windows_enabled,a11y.poll_native_windows
    a11y.poll_native_windows=function() end -- fixed native snapshot supplied by this fixture
    local values={}
    for address,item in pairs(entries) do values[address]=item.text end
    a11y.read_native_rendered_text=function(address) return values[address],values[address],0 end
    a11y.menu_read=function() return nil end
    a11y.native_windows_enabled=true
    with_components(entries,function(snapshot,parents,owner) fn(values,snapshot,parents,owner) end)
    a11y.read_native_rendered_text,a11y.menu_read,a11y.native_windows_enabled,a11y.poll_native_windows=getter,reader,enabled,poll
end

check("render polling recovers an unobserved selected country without setter events",function()
    with_rendered_panel({[0x110000]={name="text",text="PORTUGAL",parent=0x210000}},function(values,snapshot)
        local key=host.memory.hex(0x110000)
        a11y.forget_ui_widget(key)
        snapshot.selected_members={[0x110000]=true};snapshot.cursor_members={[0x110000]=true}
        with_focus_memory({},function(tick)
            a11y.poll_native_texts();tick(120);tick(123)
            assert(#speech_texts()==1 and speech_texts()[1]:find("PORTUGAL",1,true))
            values[0x110000]="BRASIL"
            a11y.poll_native_texts();tick(130);tick(133)
            assert(#speech_texts()==2 and speech_texts()[2]:find("BRASIL",1,true))
        end)
    end)
end)

check("review recovers the selected club's shown player panel and replaces it on club change",function()
    with_rendered_panel({[0x110000]={name="teamName",text="Liverpool",parent=0x210000},
        [0x120000]={name="listHeader",text="Lista de jogadores",parent=0x220000},
        [0x130000]={name="playerName",text="Alisson",parent=0x220000},
        [0x140000]={name="playerName",text="Salah",parent=0x220000}},function(values)
        a11y.commit_read_selection("Liverpool","first","engine-focus",nil,0x110000)
        a11y.forget_ui_widget(host.memory.hex(0x130000));a11y.forget_ui_widget(host.memory.hex(0x140000))
        local first=table.concat(a11y.buffer_entries()," | ")
        assert(first:find("Liverpool",1,true) and first:find("Lista de jogadores",1,true)
            and first:find("Alisson",1,true) and first:find("Salah",1,true))
        values[0x110000],values[0x130000],values[0x140000]="Arsenal","Raya","Saka"
        local second=table.concat(a11y.buffer_entries()," | ")
        assert(second:find("Arsenal",1,true) and second:find("Raya",1,true) and second:find("Saka",1,true))
        assert(not second:find("Liverpool",1,true) and not second:find("Alisson",1,true) and not second:find("Salah",1,true))
    end)
end)

check("a descriptive sibling cannot hide the unique item label of the same native component",function()
    with_components({[0x110000]={name="item",text="Componente de escolha",parent=0x210000},
        [0x120000]={name="description_0",text="Detalhe do componente",parent=0x210000}},function(snapshot)
        with_focus_memory({},function(tick)
            snapshot.selected_members={[0x110000]=true,[0x120000]=true}
            snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
            tick(120);tick(123)
            assert(#speech_texts()==1 and speech_texts()[1]:find("Componente de escolha",1,true))
            assert(table.concat(a11y.buffer_entries()," | "):find("Detalhe do componente",1,true))
        end)
    end)
end)

check("description from a different native component cannot be silently merged",function()
    with_components({[0x110000]={name="item",text="Escolha A",parent=0x210000},
        [0x120000]={name="description_0",text="Escolha B",parent=0x220000}},function(snapshot)
        with_focus_memory({},function(tick)
            snapshot.selected_members={[0x110000]=true,[0x120000]=true}
            tick(120);tick(123)
            assert(#speech_texts()==0)
        end)
    end)
end)

check("keyboard popup state supersedes the last unrelated input and supplies real UTF8 caret movement",function()
    local reader,string_reader=a11y.menu_read,a11y.read_msvc_string
    local old_base=upvalue(module.init,"process_base_u64")
    local base,window=0x140000000,0x310000
    local value,caret="José",4
    a11y.menu_read=function(address)
        if address==window then return base+0x27c3eb0 end
        if address==window+0x110 then return caret end
        if address==window+0x90 then return 0x410000 end
        if address==0x510000 then return base+0x27c3a38 end
    end
    a11y.read_msvc_string=function(address)
        if address==window+0x118 then return value end
        error("unrelated last setter must not become the active edit buffer")
    end
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    a11y.keyboard_window,a11y.keyboard_input_address=window,0x510000
    with_render_harness(function(output)
        module.display_frame({});assert(#output==0)
        caret=3;module.display_frame({});assert(#output==1 and output[1][1]=="é")
        caret=2;module.display_frame({});assert(output[2][1]=="s")
        value="Joé";module.display_frame({});assert(output[3][1]=="s")
        caret=3;module.display_frame({});assert(output[4][1]=="Fim do texto.")
        value="";caret=0;module.display_frame({});assert(output[5][1]=="Joé")
    end)
    a11y.menu_read,a11y.read_msvc_string=reader,string_reader
    set_upvalue(module.init,"process_base_u64",old_base)
end)

check("keyboard caret outside actual text is rejected rather than predicted from arrows",function()
    local reader,string_reader=a11y.menu_read,a11y.read_msvc_string
    local old_base=upvalue(module.init,"process_base_u64")
    local base,window=0x140000000,0x310000
    a11y.keyboard_window=window
    a11y.menu_read=function(address) if address==window then return base+0x27c3eb0 elseif address==window+0x110 then return 900 end end
    a11y.read_msvc_string=function() return "José" end
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    assert(a11y.read_native_keyboard_state().caret==nil)
    a11y.menu_read,a11y.read_msvc_string=reader,string_reader
    set_upvalue(module.init,"process_base_u64",old_base)
end)

check("known installed controller font is recognized across chunks and changes actual glyph wording",function()
    local old_family,old_scan=a11y.control_font_family,a11y.control_font_scan
    local file=assert(io.open(sider_dir .. "/../FLAccess/tests/voice-evidence/controller-font.bin","rb"))
    local bytes=file:read("*a");file:close()
    a11y.observe_control_font(bytes:sub(1,1000),0,#bytes)
    assert(a11y.control_font_family==nil)
    a11y.observe_control_font(bytes:sub(1001),1000,#bytes)
    assert(a11y.control_font_family=="playstation")
    assert(clean_text("\238\128\136")=="botão Options")
    assert(clean_text("\238\128\129")=="botão Cruz")
    a11y.observe_control_font("unknown font",0,12)
    assert(a11y.control_font_family==nil)
    assert(a11y.control_symbol_text("8")=="8","numeric icon text alone proves no physical button")
    a11y.control_font_family,a11y.control_font_scan=old_family,old_scan
end)

check("actual skip glyph survives cleaning and reaches speech only when its font and component are proven",function()
    local family=a11y.control_font_family
    a11y.control_font_family="playstation"
    with_components({[0x110000]={name="skipCaption",text="Pular",parent=0x210000},
        [0x120000]={name="padIcon",text=clean_text("\238\128\136"),parent=0x210000}},function()
        local foreground=a11y.game_is_foreground
        a11y.game_is_foreground=function() return true end
        a11y.skip_hint_last_frame=-10000
        a11y.announce_skip_hint("Pular",a11y.ui_model.nodes[host.memory.hex(0x110000)])
        a11y.poll_skip_hint()
        assert(speech_texts()[1]=="Pular, botão Options")
        a11y.game_is_foreground=foreground
    end)
    a11y.control_font_family=family
end)

check("a proven initial heading waits for presentation then precedes its description",function()
    local active=false
    local allowed=a11y.native_widget_allowed
    a11y.native_widget_allowed=function() return active end
    with_widget_names({[0x110000]="text_item"},function()
        a11y.observe_ui_widget(0x110000,"Título real carregado")
        a11y.present_bound_heading(0x110000,"Título real carregado")
        assert(#speech_texts()==0)
        active=true;a11y.poll_surface_texts()
        speak("Descrição real carregada")
        assert(#speech_texts()==2 and speech_texts()[1]=="Título real carregado")
        assert(not a11y.native_speech_queue[a11y.native_speech_last].interrupt)
    end)
    a11y.native_widget_allowed=allowed
end)


check("the actual first featured-menu callback no longer suppresses its loaded title",function()
    jit.flush()
    local read,unpack_memory=host.memory.read,host.memory.unpack
    local old_base=upvalue(module.init,"process_base_u64")
    local base,address,stack,widget=0x140000000,0x210000,0x220000,0x230000
    local foreground=a11y.game_is_foreground
    a11y.game_is_foreground=function() return true end
    local text="Football Life 2026"
    local function packed(value) return ffi.string(ffi.new("uint64_t[1]",value),8) end
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    host.memory.read=function(ptr,size)
        local at=tonumber(ptr)
        if at==address then return text end
        if at==stack+64 then return packed(base+0xe4901d) end
        if at==stack+72 then return packed(widget) end
        return string.rep("\0",size)
    end
    host.memory.unpack=function(kind,bytes)
        if kind=="u64" and bytes then return ffi.cast("uint64_t*",bytes)[0] end
        return unpack_memory(kind,bytes)
    end
    with_widget_names({[widget]="text"},function()
        with_render_harness(function(output)
            module.on_resolved_text({},0,setmetatable({rax=packed(address),r8=packed(#text),rsp=packed(stack),rdi=packed(60948637)},
                {__index=function() return packed(0) end}))
            module.display_frame({})
            assert(#output>=1 and output[1][1]==text,"output=" .. tostring(#output) .. " queue=" .. table.concat(speech_texts()," | ") .. " logs=" .. table.concat(logs," | ",math.max(1,#logs-8)))
        end)
    end)
    host.memory.read,host.memory.unpack=read,unpack_memory
    a11y.game_is_foreground=foreground
    set_upvalue(module.init,"process_base_u64",old_base)
end)

check("bounded observation retention protects the current native selection under background churn",function()
    with_components({[0x110000]={name="text",text="Seleção estável",parent=0x210000}},function(snapshot)
        snapshot.selected_members={[0x110000]=true}
        local key=host.memory.hex(0x110000)
        local identity=a11y.ui_model.nodes[key].identity
        for index=1,1100 do a11y.observe_ui_widget(0x500000+index*64,"Texto secundário") end
        assert(a11y.ui_model.count==1024 and a11y.ui_model.nodes[key].identity==identity)
    end)
end)


check("render-only entry navigation reaches Prism once per real movement and return",function()
    with_rendered_panel({[0x110000]={name="itemName",text="Primeira entrada",parent=0x210000},
        [0x120000]={name="itemName",text="Outro destino",parent=0x220000},
        [0x130000]={name="description_0",text="Detalhe da primeira entrada",parent=0x210000}},function(_,snapshot)
        snapshot.selected_members={[0x110000]=true,[0x130000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true,[0x130000]=true}
        for key in pairs(a11y.ui_model.nodes) do a11y.forget_ui_widget(key) end
        with_focus_memory({},function(tick)
            with_render_harness(function(output)
                module.display_frame({});tick(122);tick(125);module.display_frame({})
                assert(#output==1 and output[1][1]=="Primeira entrada")
                snapshot.selected_members={[0x120000]=true}
                tick(130);tick(133);module.display_frame({})
                assert(#output==2 and output[2][1]=="Outro destino")
                snapshot.windows[1].root=0x990000
                snapshot.selected_members={[0x110000]=true,[0x130000]=true}
                tick(140);tick(143);module.display_frame({})
                assert(#output==3 and output[3][1]=="Primeira entrada")
            end)
        end)
    end)
end)

check("role suppression preserves an exact literal game caption containing the same words",function()
    with_widget_names({[0x110000]="message"},function()
        local text="O nome do recurso é Nome, seletor"
        a11y.observe_ui_widget(0x110000,text)
        with_render_harness(function(output)
            speak(text,nil,nil,nil,0x110000)
            module.display_frame({})
            assert(#output==1 and output[1][1]==text)
        end)
    end)
end)

check("native parts delegation reaches selectors LR switches and cards without treating arbitrary +98 as a child",function()
    with_native_windows(function(values,base)
        for _,kind in ipairs({0x27b84d0,0x27bb538,0x27c0338}) do
            values[0x600000]=0x400000;values[0x400000]=base+kind
            values[base+kind+0x88],values[base+kind+0x28]=base+0xe8ecd0,base+0xe8ecb0
            values[0x400098]=0x420000;values[0x420000]=base+0x27cb508
            values[0x420170],values[0x420178]=0x430000,0x430008;values[0x430000]=0x500000
            local tree,parents=a11y.menu_tree(0x300000,base)
            assert(tree[0x500000] and parents[0x420000]==0x400000 and parents[0x500000]==0x420000)
            values[base+kind+0x28]=0
            tree=a11y.menu_tree(0x300000,base)
            assert(not tree[0x500000],"one matching method must not prove the layout")
        end
    end)
end)

check("delegated native text inherits inactive ownership and recovers on return",function()
    with_native_windows(function(values,base)
        values[0x600000]=0x400000;values[0x400000]=base+0x27b84d0
        values[base+0x27b84d0+0x88],values[base+0x27b84d0+0x28]=base+0xe8ecd0,base+0xe8ecb0
        values[0x400098]=0x500000
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_widget_allowed(0x500000))
        values[0x1200009]=1
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_widget_allowed(0x500000))
        values[0x400098]=0x400000 -- cycle must terminate without inventing text
        assert(not a11y.menu_tree(0x300000,base)[0x500000])
    end)
end)

local function with_native_field(fn)
    local base=0x140000000
    local original=upvalue(module.init,"process_base_u64")
    local reader=a11y.menu_read
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    local kinds={[0x310000]=base+0x27b84d0,[0x210000]=base+0x27cb508}
    a11y.menu_read=function(address) return kinds[address] end
    with_components({[0x110000]={name="setName",text="Campo sem catálogo",parent=0x210000},
        [0x120000]={name="text",text="Primeiro valor",parent=0x410000}},function(snapshot,parents,owner)
        parents[0x410000],parents[0x310000],parents[0x210000]=0x310000,0x210000,owner.root
        fn(snapshot,parents,kinds,base)
    end)
    a11y.menu_read=reader
    set_upvalue(module.init,"process_base_u64",original)
end

check("native selector pairs its one shown value with its enclosing choice label",function()
    with_native_field(function()
        local label=a11y.native_field_label(0x120000)
        assert(label and label.address==0x110000)
        assert(a11y.structural_control_row(0x120000).label=="Campo sem catálogo")
    end)
end)

check("native field rejects a second visible value another choice and an unknown wrapper",function()
    with_native_field(function(snapshot,parents,kinds)
        a11y.observe_ui_widget(0x130000,"Outro valor")
        local name=a11y.widget_internal_name
        a11y.widget_internal_name=function(address) return address==0x130000 and "text" or name(address) end
        a11y.ui_model.nodes[host.memory.hex(0x130000)].name="text"
        parents[0x130000]=0x410000
        assert(not a11y.native_field_label(0x120000))
        a11y.forget_ui_widget(host.memory.hex(0x130000))
        parents[0x110000]=0x220000
        assert(not a11y.native_field_label(0x120000))
        parents[0x110000]=0x210000;kinds[0x310000]=0
        assert(not a11y.native_field_label(0x120000))
        a11y.widget_internal_name=name
    end)
end)

check("a focused native field announces a value change and delayed attachment without new focus events",function()
    with_native_field(function(snapshot)
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
        with_focus_memory({},function(tick)
            emit_ui_text(0x120000,"Primeiro valor")
            tick(120);tick(123)
            assert(speech_texts()[1]=="Campo sem catálogo, seletor, Primeiro valor")
            emit_ui_text(0x120000,"Valor atualizado")
            tick(126);tick(129)
            local output=speech_texts()
            assert(#output==2 and output[2]=="Valor atualizado")
            tick(132);assert(#speech_texts()==2)
        end)
    end)
end)

check("queued field speech is rejected when its value changes before focus is polled again",function()
    with_native_field(function(snapshot)
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
        with_focus_memory({},function(tick)
            emit_ui_text(0x120000,"Primeiro valor")
            tick(120);tick(123)
            local origin=a11y.native_speech_queue[a11y.native_speech_last].engine_focus
            assert(origin and a11y.engine_focus_delivery_allowed(origin))
            emit_ui_text(0x120000,"Novo valor")
            assert(not a11y.engine_focus_delivery_allowed(origin),"old full field must not speak after the new value")
        end)
    end)
end)

check("a unique presented heading needs no localization catalogue and keeps existing fields",function()
    with_components({[0x110000]={name="title",text="Nome fornecido pelo jogo",parent=0x210000},
        [0x120000]={name="novel_item",text="Campo preservado",parent=0x220000}},function()
        a11y.capture_structural_control(0x120000,"Campo preservado")
        a11y.poll_presented_texts()
        assert(speech_texts()[1]=="Nome fornecido pelo jogo")
        local rows=upvalue(a11y.structural_control_row,"control_rows_by_label_widget")
        assert(rows[host.memory.hex(0x120000)].label=="Campo preservado")
    end)
end)

check("multiple independent headings remain silent instead of choosing one by iteration",function()
    with_components({[0x110000]={name="title",text="Título A",parent=0x210000},
        [0x120000]={name="title",text="Título B",parent=0x220000}},function()
        a11y.poll_presented_texts()
        assert(#speech_texts()==0)
    end)
end)

check("the focused field value is refreshed outside the rotating text scan budget",function()
    with_rendered_panel({[0x110000]={name="new_item",text="Campo atual",parent=0x210000},
        [0x990000]={name="new_value",text="Valor antigo",parent=0x210000}},function(values,snapshot)
        a11y.capture_structural_control(0x110000,"Campo atual")
        snapshot.selected_members={[0x110000]=true}
        for index=1,100 do snapshot.members[0x200000+index*64]={active=true,owners=snapshot.members[0x110000].owners} end
        values[0x990000]="Valor novo"
        a11y.native_text_scan_cursor=0
        a11y.poll_native_texts(true)
        values[0x990000]="Mudança sem foco"
        a11y.native_text_scan_cursor=0
        a11y.poll_native_texts()
        assert(a11y.ui_model.nodes[host.memory.hex(0x990000)].text=="Mudança sem foco")
    end)
end)

check("insertions stay silent by default while deletion remains audible",function()
    a11y.keyboard_echo_insertions=false;a11y.keyboard_window=0x130000
    a11y.read_keyboard_text({address=0x110000,name="textWord",text="José"})
    a11y.read_keyboard_text({address=0x110000,name="textWord",text="José Luís"})
    assert(#speech_texts()==0)
    a11y.read_keyboard_text({address=0x110000,name="textWord",text="José Luí"})
    assert(speech_texts()[1]=="s")
end)

check("captured direct jump and setName siblings form one native choice without a selector wrapper",function()
    with_native_field(function(snapshot,parents,kinds)
        local names=a11y.widget_internal_name
        a11y.widget_internal_name=function(address) return address==0x120000 and "jump" or names(address) end
        a11y.ui_model.nodes[host.memory.hex(0x120000)].name="jump"
        parents[0x120000]=0x210000;kinds[0x310000]=nil
        local label=a11y.native_field_label(0x120000)
        assert(label and label.address==0x110000)
        a11y.observe_ui_widget(0x110000,"Modo offline (Normal)")
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
        with_focus_memory({},function(tick)
            emit_ui_text(0x120000,"Jogador")
            tick(120);tick(123)
            assert(#speech_texts()==1 and speech_texts()[1]=="Modo offline (Normal), seletor, Jogador")
        end)
        a11y.widget_internal_name=names
    end)
end)

check("placeholder dashes cannot become a new standalone engine selection",function()
    with_components({[0x110000]={name="teamName",text="-",parent=0x210000}},function(snapshot)
        snapshot.selected_members={[0x110000]=true}
        snapshot.cursor_members={[0x110000]=true}
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            assert(#speech_texts()==0)
        end)
    end)
end)

check("native carousel waits for its caption then speaks first entry and same entry after owner return",function()
    with_rendered_panel({[0x110000]={name="teamName",text="Clube atual",parent=0x210000}},function(values,snapshot)
        snapshot.selected_members={[0x110000]=true};snapshot.cursor_members={[0x110000]=true}
        with_focus_memory({},function(tick)
            a11y.observe_native_list_selection("Clube atual","record:1",0x110000)
            values[0x110000]="-"
            tick(120);tick(123);assert(#speech_texts()==0)
            values[0x110000]="Clube atual"
            tick(126);tick(129)
            assert(#speech_texts()==1 and speech_texts()[1]=="Clube atual, item selecionado")
            snapshot.windows[1].root=0x950000
            tick(132);tick(135)
            assert(#speech_texts()==2 and speech_texts()[2]=="Clube atual, item selecionado")
        end)
    end)
end)

check("native carousel cannot override an active dialog or a cursor in a different choice",function()
    with_rendered_panel({[0x110000]={name="teamName",text="Clube atual",parent=0x210000}},function(_,snapshot)
        a11y.observe_native_list_selection("Clube atual","record:1",0x110000)
        snapshot.cursor_members={[0x110000]=true};snapshot.selected_members={}
        assert(not a11y.process_native_list_focus(false))
        snapshot.selected_members={[0x110000]=true}
        a11y.read_context_state().kind="dialog"
        assert(not a11y.process_native_list_focus(false) and #speech_texts()==0)
    end)
end)

check("changing a native carousel record invalidates queued speech before the next focus poll",function()
    with_rendered_panel({[0x110000]={name="teamName",text="Clube A",parent=0x210000}},function(values,snapshot)
        a11y.observe_native_list_selection("Clube A","record:1",0x110000)
        snapshot.selected_members={[0x110000]=true};snapshot.cursor_members={[0x110000]=true}
        assert(a11y.process_native_list_focus(false))
        local origin=a11y.native_speech_queue[a11y.native_speech_last].native_list
        assert(origin and a11y.native_list_delivery_allowed(origin))
        values[0x110000]="Clube B"
        a11y.observe_native_list_selection("Clube B","record:2",0x110000)
        assert(not a11y.native_list_delivery_allowed(origin))
    end)
end)

check("both production carousel callbacks only record their actual text node",function()
    local unpack_memory,strings=host.memory.unpack,a11y.read_msvc_string
    local readable=upvalue(module.on_list_item_render,"readable")
    set_upvalue(module.on_list_item_render,"readable",function() return true end)
    a11y.game_plan_active=false
    host.memory.unpack=function(kind,value) if type(value)=="number" then return value end;return unpack_memory(kind,value) end
    a11y.read_msvc_string=function(address)
        if address==0x510020 then return "Liga capturada" end
        if address==0x610000-0x19 then return "Clube capturado" end
    end
    module.on_list_item_render({},0,{r13=4,r15=0x510000,r12=0x110000})
    assert(a11y.native_list_selection.widget==0x110000 and a11y.native_list_selection.text=="Liga capturada")
    module.on_team_item_text({},0,{r14=4,rbp=0x610000,rdi=0x120000})
    assert(a11y.native_list_selection.widget==0x120000 and a11y.native_list_selection.text=="Clube capturado")
    assert(#speech_texts()==0,"callbacks cannot deliver pre-commit text")
    host.memory.unpack,a11y.read_msvc_string=unpack_memory,strings
    set_upvalue(module.on_list_item_render,"readable",readable)
end)

check("default proxy renderer restores unchanged OK after the reading model is cleared",function()
    jit.flush()
    local read,unpack_memory=host.memory.read,host.memory.unpack
    local base_before=upvalue(module.init,"process_base_u64")
    local names,poll,enabled,snapshot=a11y.widget_internal_name,a11y.poll_native_windows,a11y.native_windows_enabled,a11y.native_windows
    local original_frame=upvalue(module.display_frame,"frame")
    local base=0x140000000
    local node,renderer,vt,raw=ffi.new("uint8_t[512]"),ffi.new("uint8_t[256]"),ffi.new("uint64_t[4]"),ffi.new("char[128]","OK")
    local function ptr(value) return tonumber(ffi.cast("uint64_t",value)) end
    local function put(buffer,offset,value) ffi.cast("uint64_t*",buffer+offset)[0]=value end
    local address=ptr(node)
    put(node,0,base+0x27b5260);put(node,0xc,0x107);put(node,0xa8,ptr(renderer))
    put(renderer,0,ptr(vt));put(renderer,0x38,ptr(raw));vt[2]=base+0xe2fa60
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    host.memory.read,host.memory.unpack=native_memory_codec.read,native_memory_codec.unpack
    a11y.widget_internal_name=function(at) return at==address and "ok_text" or nil end
    a11y.poll_native_windows=function() end;a11y.native_windows_enabled=true
    local owner={address=0x800000,root=0x900000,enabled=true,parents={[address]=0x210000}}
    a11y.native_windows={windows={owner},members={[address]={active=true,owners={owner}}},
        selected_members={[address]=true},cursor_members={[address]=true}}
    for round=1,2 do
        a11y.reset_ui_model();a11y.engine_focus=nil
        set_upvalue(module.display_frame,"frame",120+round*10)
        a11y.poll_native_texts();a11y.process_engine_focus(false)
        set_upvalue(module.display_frame,"frame",123+round*10)
        a11y.process_engine_focus(false)
        assert(#speech_texts()==round and speech_texts()[round]=="OK, item selecionado")
    end
    host.memory.read,host.memory.unpack=read,unpack_memory
    a11y.widget_internal_name,a11y.poll_native_windows,a11y.native_windows_enabled,a11y.native_windows=names,poll,enabled,snapshot
    set_upvalue(module.init,"process_base_u64",base_before)
    set_upvalue(module.display_frame,"frame",original_frame)
end)

check("selection commits into the new context when a pending title replaces a notice",function()
    local previous=a11y.read_context_state()
    previous.kind="notice"
    previous.question="Aviso anterior"
    previous.pending_title="Título atual"
    assert(a11y.commit_read_selection("Item atual","current-item","engine-focus"))
    local current=a11y.read_context_state()
    assert(current~=previous and current.title=="Título atual")
    assert(current.selection and current.selection.text=="Item atual")
    assert(current.question==nil)
end)

check("restoring diagnostics always disables it from either initial state",function()
    local setter=a11y.set_diagnostic
    a11y.selected_option=2
    a11y.set_diagnostic=function(enabled)
        assert(enabled==false,"restore must not toggle diagnostics on")
        a11y.diagnostic_mode=enabled
        return true
    end
    for _,enabled in ipairs({false,true}) do
        a11y.diagnostic_mode=enabled
        module.key_down({},a11y.restore_key)
        assert(not a11y.diagnostic_mode)
    end
    a11y.set_diagnostic=setter
    a11y.selected_option=1
end)

check("full context reset advances one generation and drops queued old work",function()
    local generation=a11y.ui_model.generation
    speak("Fala antiga")
    assert(#speech_texts()==1)
    module.context_reset({})
    assert(a11y.ui_model.generation==generation+1)
    assert(#speech_texts()==0)
    a11y.reset_control_tracking_state()
    assert(a11y.ui_model.generation==generation+2)
end)

check("queue takeover preserves only its supplied title and validates every origin",function()
    local title={text="Título",sequence=1}
    a11y.native_speech_queue={title,{text="Antigo",sequence=2}}
    a11y.native_speech_first,a11y.native_speech_last=1,2
    a11y.clear_speech_queue(title)
    assert(a11y.native_speech_queue[1]==title and a11y.native_speech_last==1)
    local validators={origin="speech_origin_allowed",engine_focus="engine_focus_delivery_allowed",
        native_list="native_list_delivery_allowed",reading_selection="reading_selection_delivery_allowed"}
    for field,method in pairs(validators) do
        local original=a11y[method]
        a11y[method]=function(value) return value=="live" end
        assert(a11y.speech_entry_allowed({[field]="live"}))
        assert(not a11y.speech_entry_allowed({[field]="stale"}))
        a11y[method]=original
    end
    assert(not a11y.speech_entry_allowed({presentation_owner="old-window"}))
    a11y.clear_speech_queue()
    assert(a11y.native_speech_first==1 and a11y.native_speech_last==0 and next(a11y.native_speech_queue)==nil)
end)

check("leaving a game plan cancels delayed work before returning to another component",function()
    a11y.game_plan_active=true
    a11y.game_plan_selected_heading="Cabeçalho antigo"
    a11y.game_plan_selected_heading_due_frame=-1
    a11y.game_plan_basic_menu_heading_due_frame=-1
    a11y.game_plan_lineup_due_ms=1
    a11y.game_plan_attribute_due_ms=1
    a11y.game_plan_menu_probe_due_frame=1
    remember_message("A partida começará quando os dois times estiverem prontos.","ready")
    assert(not a11y.game_plan_active and a11y.pre_match_active)
    assert(a11y.game_plan_selected_heading_due_frame==nil)
    assert(a11y.game_plan_basic_menu_heading_due_frame==nil)
    assert(a11y.game_plan_lineup_due_ms==nil and a11y.game_plan_attribute_due_ms==nil)
    assert(a11y.game_plan_menu_probe_due_frame==nil)
    a11y.game_plan_active=true
    assert(not a11y.process_game_plan_selected_heading(false),"old heading must not survive reentry")
end)

check("duplicate field names keep bindings proven in independent native components",function()
    with_components({[0x110000]={name="field_item",text="Campo A",parent=0x210000},
        [0x120000]={name="field_value",text="Valor A",parent=0x210000},
        [0x130000]={name="field_item",text="Campo B",parent=0x220000},
        [0x140000]={name="field_value",text="Valor B",parent=0x220000}},function()
        emit_ui_text(0x110000,"Campo A");emit_ui_text(0x120000,"Valor A")
        local first=assert(a11y.structural_control_row(0x120000))
        assert(first.value=="Valor A")
        emit_ui_text(0x130000,"Campo B");emit_ui_text(0x140000,"Valor B")
        assert(first.value=="Valor A" and first.value_widget==0x120000)
        local second=assert(a11y.structural_control_row(0x140000))
        assert(second~=first and second.value=="Valor B")
        emit_ui_text(0x140000,"Novo B")
        assert(first.value=="Valor A" and second.value=="Novo B")
    end)
end)

check("native field remains one choice when localization also registers its value as a label",function()
    with_native_field(function(snapshot)
        local register=upvalue(module.on_resolved_text,"register_control_label")
        register("Primeiro valor",0x120000)
        a11y.rebind_presented_control(a11y.ui_model.nodes[host.memory.hex(0x120000)])
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            assert(#speech_texts()==1,"a value cannot compete with its proven field")
            assert(speech_texts()[1]=="Campo sem catálogo, seletor, Primeiro valor")
        end)
    end)
end)

check("typed choice binds a direct text label to its selector without caption rules",function()
    with_native_field(function(snapshot,parents)
        local names=a11y.widget_internal_name
        a11y.widget_internal_name=function(at) return at==0x110000 and "text" or names(at) end
        a11y.ui_model.nodes[host.memory.hex(0x110000)].name="text"
        local register=upvalue(module.on_resolved_text,"register_control_label")
        register("Primeiro valor",0x120000)
        a11y.rebind_presented_control(a11y.ui_model.nodes[host.memory.hex(0x120000)])
        local row=assert(a11y.structural_control_row(0x120000))
        assert(row.label=="Campo sem catálogo" and row.value=="Primeiro valor")
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            emit_ui_text(0x120000,"Valor seguinte")
            register("Valor seguinte",0x120000)
            tick(126);tick(129)
            assert(#speech_texts()==2 and speech_texts()[2]=="Valor seguinte",table.concat(speech_texts()," | "))
            snapshot.selected_members={};tick(132)
            snapshot.selected_members={[0x110000]=true,[0x120000]=true}
            snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
            a11y.reset_control_tracking_state()
            a11y.observe_ui_widget(0x110000,"Outro título sem catálogo")
            emit_ui_text(0x120000,"Outro valor sem catálogo")
            tick(135);tick(138)
            assert(speech_texts()[3]=="Outro título sem catálogo, seletor, Outro valor sem catálogo")
        end)
        a11y.observe_ui_widget(0x130000,"Segundo título")
        local original=a11y.widget_internal_name
        a11y.widget_internal_name=function(at) return at==0x130000 and "text" or original(at) end
        a11y.ui_model.nodes[host.memory.hex(0x130000)].name="text"
        parents[0x130000]=0x210000
        assert(not a11y.native_field_label(0x120000),"two outer labels must remain ambiguous")
        a11y.widget_internal_name=names
    end)
end)

check("direct jump binding wins over a localized value with its own provisional control",function()
    with_native_field(function(snapshot,parents,kinds)
        local names=a11y.widget_internal_name
        a11y.widget_internal_name=function(at) return at==0x120000 and "jump" or names(at) end
        a11y.ui_model.nodes[host.memory.hex(0x120000)].name="jump"
        parents[0x120000]=0x210000;kinds[0x310000]=nil
        local register=upvalue(module.on_resolved_text,"register_control_label")
        register("Valor de exemplo",0x120000,nil,true)
        emit_ui_text(0x120000,"Valor de exemplo")
        local selected,reason=a11y.resolve_primary_focus({
            {key=host.memory.hex(0x110000),edge=10},{key=host.memory.hex(0x120000),edge=10}})
        assert(selected and selected.key==host.memory.hex(0x110000) and reason=="control-label-value")
        a11y.widget_internal_name=names
    end)
end)

check("an unknown native branch produces evidence without invented text ownership",function()
    with_native_windows(function(values,base)
        values[0x500000]=base+0x123450
        local members,_,evidence=a11y.menu_tree(0x300000,base)
        assert(not members[0x500000])
        local found=false
        for _,item in ipairs(evidence.frontier) do
            if item.address==0x500000 and item.rva==0x123450 then found=true end
        end
        assert(found and not evidence.at_capacity)
    end)
end)

check("structured capture distinguishes native ownership provisional labels and raw glyph bytes",function()
    with_native_field(function(snapshot)
        local old=a11y.component_capture
        local register=upvalue(module.on_resolved_text,"register_control_label")
        register("Primeiro valor",0x120000)
        a11y.rebind_presented_control(a11y.ui_model.nodes[host.memory.hex(0x120000)])
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        a11y.ui_model.nodes[host.memory.hex(0x120000)].raw_text="\17ka"
        a11y.observe_ui_widget(0x130000,"Texto apenas carregado")
        local capture={sequence=1,nodes={},parents={}}
        local lines=table.concat(a11y.component_capture_lines(capture),"\n")
        assert(lines:find('relation="native-field"',1,true))
        assert(lines:find('provisional="Primeiro valor"',1,true))
        assert(lines:find('member="unknown"',1,true))
        assert(lines:find('raw_hex="116b61"',1,true))
        local second=table.concat(a11y.component_capture_lines(capture),"\n")
        assert(not second:find("NODE ",1,true),"unchanged node records must not repeat")
        assert(#speech_texts()==0,"capture must not grant speech or selection")
        a11y.component_capture=old
    end)
end)

check("structured capture samples beyond input 120 and preserves its bounded output",function()
    local old,old_dir=a11y.component_capture,a11y.sider_dir
    local old_frame=upvalue(module.display_frame,"frame")
    local path=sider_dir .. "\\..\\FLAccess\\.test-temp\\components-test.log"
    assert(a11y.start_component_capture(path))
    local capture=a11y.component_capture
    for index=1,125 do
        set_upvalue(module.display_frame,"frame",index*40)
        a11y.component_capture_dirty_frame=index*40
        a11y.poll_component_capture()
    end
    assert(capture.sequence==125 and capture.active)
    local bytes=capture.bytes
    a11y.poll_component_capture()
    assert(capture.bytes==bytes)
    set_upvalue(module.display_frame,"frame",125*40+36)
    a11y.poll_component_capture()
    assert(capture.sequence==126,"late presentation gets one followup")
    capture.bytes=33554432
    set_upvalue(module.display_frame,"frame",126*40+36)
    a11y.component_capture_dirty_frame=126*40
    a11y.poll_component_capture()
    assert(not capture.active)
    local file=assert(io.open(path,"rt"));local output=file:read("*a");file:close()
    assert(output:find("SNAP sequence=125",1,true))
    os.remove(path)
    a11y.component_capture,a11y.sider_dir=old,old_dir
    set_upvalue(module.display_frame,"frame",old_frame)
end)

check("arming structured capture is consumed once and does not overwrite the session on restart",function()
    local old,old_dir=a11y.component_capture,a11y.sider_dir
    a11y.sider_dir=sider_dir .. "\\..\\FLAccess\\.test-temp"
    local marker=a11y.sider_dir .. "\\FLAccess-components.capture"
    local path=a11y.sider_dir .. "\\FLAccess-components.log"
    local file=assert(io.open(marker,"wt"));file:write("armed\n");file:close()
    assert(a11y.start_armed_component_capture())
    file=assert(io.open(path,"at"));file:write("PRESERVE\n");file:close()
    assert(not a11y.start_armed_component_capture())
    file=assert(io.open(path,"rt"));local output=file:read("*a");file:close()
    assert(output:find("PRESERVE",1,true))
    os.remove(marker);os.remove(path)
    a11y.component_capture,a11y.sider_dir=old,old_dir
end)

check("window resource roots gain ownership together and lose authority on close",function()
    with_native_windows(function(values,base)
        values[0x1210070],values[0x1210078]=0x800000,0x800050
        values[0x800040]=0x900000
        values[0x900000]=base+0x27bae88
        values[0x900170],values[0x900178]=0x910000,0x910008
        values[0x910000]=0x920000;values[0x920000]=base+0x27b5260
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_windows.members[0x920000].active)
        assert(a11y.native_windows.members[0x920000].owners[1].root==0x900000)
        values[0x1210098]=0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_windows.members[0x920000].active,"passive resource roots do not require a navigation root")
        values[0x1210009]=0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_widget_allowed(0x920000))
        values[0x1210009]=1
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_widget_allowed(0x920000))
        values[0x1210078]=0x800051
        assert(#a11y.window_owned_roots(0x1210000,0x310000,base)==1)
    end)
end)

check("typed editable value is part of the native field rather than a second choice",function()
    with_native_field(function(snapshot,parents,kinds,base)
        local names=a11y.widget_internal_name
        a11y.widget_internal_name=function(at) return at==0x120000 and "textWord" or names(at) end
        a11y.ui_model.nodes[host.memory.hex(0x120000)].name="textWord"
        kinds[0x310000]=base+0x27c3a38
        emit_ui_text(0x120000,"Nome já preenchido")
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            assert(speech_texts()[1]=="Campo sem catálogo, seletor, Nome já preenchido")
        end)
        a11y.widget_internal_name=names
    end)
end)

check("a native help field cannot keep selectors in generic dialog-answer mode",function()
    with_native_field(function(snapshot,parents,kinds,base)
        local names=a11y.widget_internal_name
        a11y.widget_internal_name=function(at) return at==0x130000 and "text" or names(at) end
        local owner=snapshot.members[0x110000].owners[1]
        snapshot.members[0x130000]={active=true,owners={owner}}
        parents[0x130000],parents[0x320000]=0x320000,owner.root
        kinds[0x320000]=base+0x27c17a0
        a11y.observe_ui_widget(0x130000,"Ajuda real de uma opção desconhecida.")
        a11y.rebind_presented_control(a11y.ui_model.nodes[host.memory.hex(0x120000)])
        local context=a11y.read_context_state()
        context.kind,context.question,context.expires_frame="dialog","Ajuda real de uma opção desconhecida.",10000
        snapshot.selected_members={[0x110000]=true,[0x120000]=true}
        snapshot.cursor_members={[0x110000]=true,[0x120000]=true}
        assert(not a11y.process_read_dialog_focus({}))
        assert(a11y.read_context.kind~="dialog")
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            assert(speech_texts()[1]=="Campo sem catálogo, seletor, Primeiro valor")
            emit_ui_text(0x120000,"Novo valor")
            tick(126);tick(129)
            assert(speech_texts()[2]=="Novo valor")
        end)
        a11y.read_context.kind="dialog";a11y.read_context.question="Ajuda real de uma opção desconhecida."
        a11y.read_context.structural_question=true;a11y.read_context.expires_frame=10000
        assert(a11y.process_read_dialog_focus({}),"real question panels retain authority")
        a11y.widget_internal_name=names
    end)
end)

check("selected reading panels announce later pages and survive a late heading",function()
    with_rendered_panel({[0x110000]={name="text_contents",text="Introdução apresentada.",parent=0x210000}},function(values,snapshot)
        snapshot.selected_members={[0x110000]=true}
        local node=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        assert(a11y.capture_reading_panel(node))
        assert(speech_texts()[1]=="Introdução apresentada.")
        a11y.set_read_title("Cabeçalho real")
        assert(a11y.read_context.question=="Introdução apresentada.")
        assert(a11y.capture_reading_panel(node) and #speech_texts()==1)
        values[0x110000]="Parágrafo seguinte."
        emit_ui_text(0x110000,"Parágrafo seguinte.")
        assert(speech_texts()[2]=="Parágrafo seguinte.")
        assert(a11y.native_speech_queue[a11y.native_speech_last].interrupt)
        snapshot.selected_members={}
        node.text="Texto de fundo."
        assert(not a11y.capture_reading_panel(node) and #speech_texts()==2)
        a11y.commit_read_selection("Novo comando","new-command","engine-focus")
        assert(a11y.read_context.question==nil,"closed paragraph must not remain in review")
    end)
end)

check("entity review contains the committed club and its owned roster only",function()
    with_rendered_panel({[0x110000]={name="teamName",text="Clube atual",parent=0x210000},
        [0x120000]={name="teamName",text="Clube vizinho",parent=0x220000},
        [0x130000]={name="playerName",text="Jogador um",parent=0x230000},
        [0x140000]={name="playerName",text="Jogador dois",parent=0x240000},
        [0x150000]={name="text_title",text="Cabeçalho da lista",parent=0x250000}},function(values,snapshot)
        a11y.native_list_selection={widget=0x110000,text="Clube atual",identity="record:1"}
        a11y.native_list_selection.committed=a11y.native_owner_token() .. ":record:1:Clube atual"
        local result=a11y.entity_review_entries(a11y.presented_nodes())
        assert(result and #result==4 and result[1]=="Clube atual" and result[2]=="Cabeçalho da lista")
        for _,text in ipairs(result) do assert(text~="Clube vizinho") end
        values[0x110000]="Novo clube"
        assert(not a11y.entity_review_entries(a11y.presented_nodes()),"old committed entity cannot own new captions")
    end)
end)

check("command captions and icons can share a compound ancestor without being direct siblings",function()
    with_components({[0x110000]={name="text",text="Legenda real",parent=0x210000},
        [0x120000]={name="padIcon",text="botão Options",parent=0x220000}},function(snapshot,parents,owner)
        parents[0x210000],parents[0x220000],parents[0x230000]=0x230000,0x230000,owner.root
        local node=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        assert(a11y.command_icon_for_node(node)=="botão Options")
        a11y.observe_ui_widget(0x130000,"Outro comando")
        parents[0x130000]=0x230000
        snapshot.members[0x130000]={active=true,owners={owner}}
        assert(not a11y.command_icon_for_node(node),"a shared footer cannot establish a unique command")
    end)
end)

check("an icon choice can present its unique owned companion caption without a localization id",function()
    with_rendered_panel({[0x110000]={name="text_item",text="Legenda inédita",parent=0x210000}},function(values,snapshot,parents,owner)
        local base=0x140000000
        local original=upvalue(module.init,"process_base_u64")
        local original_frame=upvalue(module.display_frame,"frame")
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        snapshot.windows={{address=owner.address,root=owner.root,enabled=true,
            cursor_detail={status="no-text",selected_type=base+0x27cb508}}}
        local nodes=a11y.presented_nodes()
        set_upvalue(module.display_frame,"frame",200)
        a11y.present_companion_heading(nodes)
        set_upvalue(module.display_frame,"frame",204)
        a11y.present_companion_heading(nodes)
        assert(speech_texts()[1]=="Legenda inédita")
        a11y.present_companion_heading(nodes);assert(#speech_texts()==1)
        local other={key="other",name="text_item",text="Outro",address=0x120000,identity="second"}
        snapshot.members[0x120000]={active=true,owners={owner}}
        a11y.companion_candidate=nil
        a11y.present_companion_heading({nodes[1],other})
        assert(a11y.companion_candidate==nil and #speech_texts()==1)
        set_upvalue(module.init,"process_base_u64",original)
        set_upvalue(module.display_frame,"frame",original_frame)
    end)
end)

check("a command loaded before its owner retries button association on presentation",function()
    with_rendered_panel({[0x110000]={name="text",text="Pular",parent=0x210000},
        [0x120000]={name="padIcon",text="Options",parent=0x210000}},function()
        local foreground=a11y.game_is_foreground
        a11y.game_is_foreground=function() return true end
        a11y.pending_skip_hint=nil
        a11y.skip_hint_last_frame=-10000
        a11y.presentation_seen_owner=nil
        a11y.poll_presented_texts()
        assert(a11y.pending_skip_hint,"presentation must recover the lost early hint")
        a11y.poll_skip_hint()
        assert(speech_texts()[1]=="Pular, Options")
        a11y.game_is_foreground=foreground
    end)
end)

local function with_native_pages(fn)
    with_rendered_panel({[0x110000]={name="text",text="Exercício comum",parent=0x210000},
        [0x120000]={name="tabText",text="Guia sem catálogo",parent=0x220000},
        [0x130000]={name="tabText",text="Outra guia",parent=0x230000}},function(values,snapshot,parents,owner)
        local base=0x140000000
        local old_base=upvalue(module.init,"process_base_u64")
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        local memory={[owner.address]=base+0x27d65c8,[base+0x27d65c8+0x2e0]=base+0xeb17f0,
            [base+0x27d65c8+0x2e8]=base+0xeb1b60,[owner.address+0x1d8]=0x400000,
            [owner.address+0x1e0]=0x400080,[owner.address+0x1d0]=0,
            [0x400000]=base+0x27d6590,[0x400040]=base+0x27d6590,
            [0x400020]=0x120000,[0x400060]=0x130000}
        for at in pairs(values) do memory[at]=base+0x27b5260;memory[at+0xc]=263 end
        a11y.menu_read=function(at) return memory[at] end
        snapshot.selected_members={[0x110000]=true};snapshot.cursor_members={[0x110000]=true}
        fn(memory,values,snapshot,owner)
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end

check("native pages announce their actual caption and follow index changes without new text",function()
    with_native_pages(function(memory,values,snapshot,owner)
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            assert(speech_texts()[1]:find("Guia sem catálogo. Exercício comum",1,true))
            tick(126);assert(#speech_texts()==1)
            local old=a11y.native_speech_queue[a11y.native_speech_first].page_context
            memory[owner.address+0x1d0]=1
            assert(not a11y.page_delivery_allowed(old),"previous page speech must be discarded")
            tick(130);tick(133)
            assert(speech_texts()[2]:find("Outra guia. Exercício comum",1,true))
            memory[owner.address+0x1d0]=0
            tick(140);tick(143)
            assert(speech_texts()[3]:find("Guia sem catálogo. Exercício comum",1,true))
        end)
    end)
end)

check("page bindings reject malformed records hidden captions and untyped windows",function()
    with_native_pages(function(memory,values,snapshot,owner)
        assert(a11y.native_page_context(0x110000))
        memory[owner.address+0x1d0]=2;assert(not a11y.native_page_context(0x110000))
        memory[owner.address+0x1d0]=0;memory[0x12000c]=7
        assert(not a11y.native_page_context(0x110000))
        memory[0x12000c]=263;memory[owner.address+0x1e0]=0x400081
        assert(not a11y.native_page_context(0x110000))
        memory[owner.address+0x1e0]=0x400080;memory[owner.address]=0
        assert(not a11y.native_page_context(0x110000))
    end)
end)

check("native command bar contributes its actual text pairs without becoming a selected menu",function()
    with_native_windows(function(memory,base)
        memory[base+0x36f98f0]=0xa00000;memory[0xa00000]=base+0x27b2668
        memory[0xa00070]=0xa10000;memory[0xa001b9]=0
        memory[0xa10000]=base+0x27bae88;memory[0xa1000c]=263
        memory[0xa10000+0x170],memory[0xa10000+0x178]=0xa20000,0xa20010
        memory[0xa20000],memory[0xa20008]=0xa30000,0xa40000
        memory[0xa00090],memory[0xa00098]=0xa30000,0xa40000
        memory[0xa30000],memory[0xa40000]=base+0x27b5260,base+0x27b5260
        local head=0xb00000
        memory[0xa10098+0x78]=head
        memory[head+0x19],memory[head+8]=1,0xb00100
        for index=0,13 do
            local record=0xb00100+index*0x100
            local text=index==0 and 0xa30000 or index==7 and 0xa40000 or 0xc00000+index*0x200
            memory[record],memory[record+0x19],memory[record+0x40]=head,0,text
            memory[record+0x10]=index==13 and head or record+0x100
            memory[text],memory[text+0x88]=base+0x27b5260,0x13
        end
        -- Constructor templates are deliberately unrelated to the shown pair.
        memory[0xa00090],memory[0xa00098]=0xd00000,0xd00200
        memory[0xd00000],memory[0xd00200]=base+0x27b5260,base+0x27b5260
        local snapshot=assert(a11y.read_native_windows(base))
        assert(snapshot.command_bar and snapshot.command_bar.pairs[1].caption==0xa40000)
        assert(#snapshot.command_bar.pairs==7 and snapshot.command_bar.pairs[1].icon==0xa30000)
        assert(snapshot.members[0xa40000].active and not snapshot.selected_members[0xa40000])
        memory[0xa001b9]=1
        assert(not a11y.read_native_windows(base).command_bar)
        memory[0xa001b9]=0;memory[0xa1000c]=3
        assert(not a11y.read_native_command_bar(base))
    end)
end)

check("presentation root belongs to the window without granting disabled input",function()
    with_native_windows(function(values,base)
        values[0x1210090]=0x900000;values[0x900000]=base+0x27bae88
        values[0x900170],values[0x900178]=0x910000,0x910008
        values[0x910000],values[0x920000]=0x920000,base+0x27b5260
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_windows.members[0x920000].active)
        assert(not a11y.native_windows.selected_members[0x920000])
        values[0x1210009]=0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_widget_allowed(0x920000))
        values[0x1210009]=1
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(a11y.native_widget_allowed(0x920000))
        values[0x1210090]=0x310000
        assert(#a11y.window_owned_roots(0x1210000,0x310000,base)==1)
    end)
end)

check("ordered native kind lookup rejects cycles and preserves filtered tree order",function()
    with_native_windows(function(values)
        local holder,head,left,root=0x900000,0x910000,0x920000,0x930000
        values[holder+0x78],values[head+0x19],values[head+8]=head,1,root
        values[root],values[root+0x10],values[root+0x19],values[root+0x40]=left,head,0,0x940000
        values[left],values[left+0x10],values[left+0x19],values[left+0x40]=head,head,0,0x950000
        values[0x940088],values[0x950088]=0x13,0x13
        local nodes=assert(a11y.holder_kind_nodes(holder,0x13))
        assert(nodes[1]==0x950000 and nodes[2]==0x940000)
        values[0x950088]=0x12
        assert(#a11y.holder_kind_nodes(holder,0x13)==1)
        values[root+0x10]=root
        assert(not a11y.holder_kind_nodes(holder,0x13))
    end)
end)

check("command bar supplies an explicit icon pair even when its nodes have unrelated parents",function()
    with_rendered_panel({[0x110000]={name="text",text="Pular",parent=0x210000},
        [0x120000]={name="text",text="botão Menu",parent=0x220000}},function(values,snapshot)
        snapshot.command_bar={pairs={{caption=0x110000,icon=0x120000,index=0}}}
        local source=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        assert(a11y.command_icon_for_node(source)=="botão Menu")
        values[0x120000]="3"
        assert(not a11y.command_icon_for_node(source),"bare digits do not prove buttons")
        values[0x120000]="botão Options";values[0x110000]="Outro comando"
        assert(not a11y.command_icon_for_node(source),"stale captions cannot reuse a pair")
    end)
end)

local function with_roster_slots(fn)
    with_rendered_panel({[0x110000]={name="playerName",text="Goleiro qualquer",parent=0x210000},
        [0x120000]={name="playerName",text="Outro goleiro",parent=0x220000}},function(values,snapshot,parents,owner)
        local base=0x140000000
        local old_base=upvalue(module.init,"process_base_u64")
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        local memory={[owner.address]=base+0x261eaa0,[owner.address+0xb8]=0x210000,
            [owner.address+0xc0]=0x220000,[owner.address+0x4e8]=0,
            [owner.address+0x88]=0x300000,[0x300098]=owner.root,[owner.address+0x98]=0}
        for at in pairs(values) do memory[at]=base+0x27b5260;memory[at+0xc]=263 end
        a11y.menu_read=function(at) return memory[at] end
        fn(memory,values,snapshot,owner,base)
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end

check("roster classification follows displayed card slots and the recorded match-rule boundary",function()
    with_roster_slots(function(memory,values,snapshot,owner,base)
        local node=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        assert(a11y.player_component_section(node)=="starter")
        memory[owner.address]=base+0x261f788
        assert(not a11y.player_component_section(node),"type alone cannot classify a reserve")
        a11y.roster_limits={[owner.address]={root=owner.root,impl=0x300000,side=0,limit=18}}
        assert(a11y.player_component_section(node)=="reserve")
        memory[owner.address+0x4e8]=7
        assert(a11y.player_component_section(node)=="unselected")
        memory[owner.address+0x4e8]=6
        assert(a11y.player_component_section(node)=="reserve")
        local second=a11y.ui_model.nodes[host.memory.hex(0x120000)]
        assert(a11y.player_component_section(second)=="unselected","same position, different native slot")
        memory[0x300098]=owner.root+8
        assert(not a11y.player_component_section(node),"a reused window cannot retain its old boundary")
    end)
end)

check("roster classification rejects shared cards and a changed side",function()
    with_roster_slots(function(memory,values,snapshot,owner,base)
        local node=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        memory[owner.address+0xc0]=0x210000
        assert(not a11y.player_component_section(node))
        memory[owner.address+0xc0]=0x220000;memory[owner.address]=base+0x261f788
        a11y.roster_limits={[owner.address]={root=owner.root,impl=0x300000,side=1,limit=23}}
        assert(not a11y.player_component_section(node))
    end)
end)

check("renderer command markers follow native glyph pointers and current confirm mapping",function()
    local reader,cstring=a11y.menu_read,a11y.read_native_c_string
    local family=a11y.control_font_family
    local old_base=upvalue(module.init,"process_base_u64")
    local base=0x140000000
    local memory={[base+0x36f9590]=base+0xe264b0,[base+0x36f9598]=base+0xe26960,
        [base+0x27ae3bc]=1,[base+0x34c0660+16+8]=0x110000,
        [base+0x27ae3f8]=32,[base+0x34c0660+32*16+8]=0,
        [base+0x34c08c0]=3,[base+0x34c0660+3*16+8]=0x120000}
    a11y.menu_read=function(at) return memory[at] end
    a11y.read_native_c_string=function(at) return at==0x110000 and "\238\128\136"
        or at==0x120000 and "\238\128\129" or nil end
    set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
    a11y.control_font_family="playstation"
    assert(clean_text("\17jb")=="botão Options")
    assert(clean_text("\17ka")=="botão Cruz")
    memory[base+0x34c08c0]=1
    assert(clean_text("\17ka")=="botão Options","confirm comes from the current mapping, not a fixed A")
    a11y.read_native_c_string=function() return "Space" end
    assert(clean_text("\17jb")=="tecla Space")
    memory[base+0x36f9590]=0
    assert(not a11y.native_control_marker("j","b"))
    a11y.menu_read,a11y.read_native_c_string,a11y.control_font_family=reader,cstring,family
    set_upvalue(module.init,"process_base_u64",old_base)
end)

check("native rule-boundary callback records data without speech and rejects a different component",function()
    with_roster_slots(function(memory,values,snapshot,owner,base)
        local unpack_memory=host.memory.unpack
        host.memory.unpack=function(kind,bytes)
            if kind=="u64" then return ffi.cast("const uint64_t*",bytes)[0] end
            return unpack_memory(kind,bytes)
        end
        local function packed(value) return ffi.string(ffi.new("uint64_t[1]",value),8) end
        local registers={rdi=packed(owner.address),rbx=packed(18)}
        module.on_roster_rule_boundary({},0,registers)
        assert(not a11y.roster_limits,"a pitch cannot masquerade as a substitute list")
        memory[owner.address]=base+0x261f788
        module.on_roster_rule_boundary({},0,registers)
        assert(a11y.roster_limits[owner.address].limit==18 and #speech_texts()==0)
        assert(a11y.player_component_section(a11y.ui_model.nodes[host.memory.hex(0x110000)])=="reserve")
        a11y.reset_selection_tracking_state()
        assert(not a11y.roster_limits)
        host.memory.unpack=unpack_memory
    end)
end)

check("integrated page change cancels stale speech and delivers the current guide with its item",function()
    with_native_pages(function(memory,values,snapshot,owner)
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            memory[owner.address+0x1d0]=1
            tick(130);tick(133)
            with_render_harness(function(output)
                a11y.flush_native_speech(100000)
                assert(#output==1 and output[1][1]:find("Outra guia. Exercício comum",1,true))
            end)
        end)
    end)
end)

check("integrated slot speech changes with native scroll and the actual rules boundary",function()
    with_roster_slots(function(memory,values,snapshot,owner,base)
        local node=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        memory[owner.address]=base+0x261f788
        a11y.roster_limits={[owner.address]={root=owner.root,impl=0x300000,side=0,limit=18}}
        with_render_harness(function(output)
            speak(a11y.engine_focus_speech(node.text,node),true,nil,nil,node.address)
            a11y.flush_native_speech(100000)
            memory[owner.address+0x4e8]=7
            speak(a11y.engine_focus_speech(node.text,node),true,nil,nil,node.address)
            a11y.flush_native_speech(100000)
            assert(#output==2 and output[1][1]:find("Reserva.",1,true)
                and output[2][1]:find("Não relacionado.",1,true))
        end)
    end)
end)

check("integrated native slot changes invalidate a queued roster announcement",function()
    with_roster_slots(function(memory,values,snapshot,owner,base)
        local node=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        memory[owner.address]=base+0x261f788
        a11y.roster_limits={[owner.address]={root=owner.root,impl=0x300000,side=0,limit=18}}
        snapshot.selected_members={[0x110000]=true};snapshot.cursor_members={[0x110000]=true}
        with_focus_memory({},function(tick)
            tick(120);tick(123)
            memory[owner.address+0x4e8]=7
            tick(130);tick(133)
            with_render_harness(function(output)
                a11y.flush_native_speech(100000)
                assert(#output==1 and output[1][1]:find("Não relacionado.",1,true))
            end)
        end)
    end)
end)

check("integrated command-bar pair delivers the decoded actual button to Prism",function()
    with_rendered_panel({[0x110000]={name="text",text="Pular",parent=0x210000},
        [0x120000]={name="text",text="botão Options",parent=0x220000}},function(values,snapshot)
        snapshot.command_bar={pairs={{caption=0x110000,icon=0x120000,index=0}}}
        local foreground=a11y.game_is_foreground
        a11y.game_is_foreground=function() return true end
        a11y.pending_skip_hint=nil;a11y.skip_hint_last_frame=-10000
        local source=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        a11y.announce_skip_hint(source.text,source)
        a11y.poll_skip_hint()
        with_render_harness(function(output)
            a11y.flush_native_speech(100000)
            assert(#output==1 and output[1][1]=="Pular, botão Options")
        end)
        a11y.game_is_foreground=foreground
    end)
end)

check("closed roster components cannot lend an old rule boundary to later windows",function()
    with_roster_slots(function(memory,values,snapshot,owner,base)
        local old_frame=upvalue(module.display_frame,"frame")
        set_upvalue(module.display_frame,"frame",100)
        a11y.roster_limits={[owner.address]={root=owner.root,impl=0x300000,side=0,limit=18,frame=100}}
        a11y.prune_roster_limits({windows={}})
        assert(a11y.roster_limits[owner.address],"allow constructor-to-registration handoff")
        set_upvalue(module.display_frame,"frame",104)
        memory[owner.root+0xc]=263
        snapshot.windows[1].impl=0x300000
        a11y.prune_roster_limits(snapshot)
        assert(a11y.roster_limits[owner.address])
        memory[owner.root+0xc]=259 -- shown bit cleared by Window::close
        a11y.prune_roster_limits(snapshot)
        assert(not a11y.roster_limits[owner.address])
        set_upvalue(module.display_frame,"frame",old_frame)
    end)
end)

check("common selection composes a late zero value and invalidates the incomplete queued result",function()
    with_rendered_panel({[0x110000]={name="setName",text="Quantidade",parent=0x210000}},function()
        local row={label="Quantidade",label_widget=0x110000,is_control=true,identity="shared-field"}
        local first=assert(a11y.selection_result({row=row,source="control"}))
        assert(first.value==nil and first.missing[1]=="value")
        assert(a11y.deliver_selection_result(first))
        row.value="0"
        local second=assert(a11y.selection_result({row=row,source="control"}))
        assert(second.value=="0" and #second.missing==0 and second.signature~=first.signature)
        assert(a11y.deliver_selection_result(second))
        assert(not a11y.selection_result_allowed(first))
        with_render_harness(function(output)
            a11y.flush_native_speech(100000)
            assert(#output==1 and output[1][1]=="Quantidade, 0")
        end)
        assert(second.status=="delivered")
        assert(a11y.read_context_state().selection.text==second.text)
    end)
end)

check("common selection deduplicates producers but reannounces after return and context reentry",function()
    with_rendered_panel({[0x110000]={name="text",text="Confirmar",parent=0x210000},
        [0x120000]={name="text",text="Outro comando",parent=0x220000}},function()
        local function offer(address,identity,source)
            local result=assert(a11y.selection_result({widget=address,identity=identity,source=source}))
            assert(a11y.deliver_selection_result(result));return result
        end
        local first=offer(0x110000,"confirm","component")
        offer(0x110000,"confirm","other-producer")
        assert(#speech_texts()==1)
        offer(0x120000,"other","component")
        offer(0x110000,"confirm","component")
        assert(#speech_texts()==3)
        a11y.reset_read_context("closed-and-returned")
        assert(not a11y.selection_result_allowed(first))
        offer(0x110000,"confirm","component")
        assert(#speech_texts()==4)
        with_render_harness(function(output)
            a11y.flush_native_speech(100000)
            assert(#output==1 and output[1][1]=="Confirmar")
        end)
    end)
end)

check("live rendered change rejects a composed result before observation polling catches up",function()
    with_rendered_panel({[0x110000]={name="text",text="País atual",parent=0x210000}},function(values)
        local result=assert(a11y.selection_result({widget=0x110000,identity="country",source="component"}))
        assert(a11y.deliver_selection_result(result))
        values[0x110000]="Outro país"
        assert(not a11y.selection_result_allowed(result))
        with_render_harness(function(output)
            a11y.flush_native_speech(100000);assert(#output==0)
        end)
        assert(result.status=="discarded")
        values[0x110000]="País atual"
        assert(a11y.deliver_selection_result(assert(a11y.selection_result({widget=0x110000,
            identity="country",source="component"}))))
        assert(#speech_texts()==1,"discarding is not successful delivery")
    end)
end)

check("common result rejects a context acquired after composition and refreshes the same focus",function()
    with_native_pages(function(memory,values,snapshot,owner)
        local getter=a11y.native_page_context
        a11y.native_page_context=function() return nil end
        local first=assert(a11y.selection_result({widget=0x110000,identity="exercise",source="component"}))
        assert(a11y.deliver_selection_result(first))
        a11y.native_page_context=getter
        assert(not a11y.selection_result_allowed(first))
        local second=assert(a11y.selection_result({widget=0x110000,identity="exercise",source="component"}))
        assert(second.page and a11y.deliver_selection_result(second))
        with_render_harness(function(output)
            a11y.flush_native_speech(100000)
            assert(#output==1 and output[1][1]=="Guia sem catálogo. Exercício comum")
        end)
    end)
end)

check("shown Task ancestor supplies presentation without becoming an input selection",function()
    with_native_windows(function(values,base)
        local old_base=upvalue(module.init,"process_base_u64")
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        local vt=base+0x2673558
        values[0x1100000],values[0x1110000]=vt,vt
        values[vt+0x50],values[vt+0x58]=base+0xe43510,base+0xe43450
        values[0x1110038],values[0x1100040],values[0x1110050]=0x1100000,0x1110000,0x1110000
        values[0x1200090],values[0x30000c],values[0x50000c]=0x300000,263,263
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_windows.members[0x500000].active)
        assert(a11y.native_windows.members[0x500000].presented)
        assert(not a11y.native_widget_allowed(0x500000) and a11y.native_text_presented(0x500000))
        assert(not a11y.native_windows.selected_members[0x500000])
        values[0x30000c]=259
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_text_presented(0x500000),"hidden ancestor is not presented")
        values[0x30000c],values[0x1110038]=263,0
        a11y.native_windows=assert(a11y.read_native_windows(base))
        assert(not a11y.native_text_presented(0x500000),"an unrelated disabled window is not context")
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end)

check("native window family discovers nested components and rejects arbitrary Task layouts",function()
    with_native_windows(function(values,base)
        local vt=base+0x261f788
        values[0x1110000],values[0x1120000]=vt,vt
        values[vt+0x50],values[vt+0x58]=base+0xe43510,base+0xe43450
        values[0x1110040],values[0x1120038],values[0x1120050]=0x1120000,0x1110000,0x1120000
        values[0x1120088],values[0x1220009],values[0x1220098]=0x1220000,1,0x320000
        values[0x320000],values[0x320170],values[0x320178]=base+0x27bae88,0x620000,0x620008
        values[0x620000],values[0x520000]=0x520000,base+0x27b5260
        local snapshot=assert(a11y.read_native_windows(base))
        assert(#snapshot.windows==3 and snapshot.members[0x520000].active)
        values[0x1120000]=base+0x27b5260
        snapshot=assert(a11y.read_native_windows(base))
        assert(#snapshot.windows==2 and not snapshot.members[0x520000])
        values[0x1120000]=vt;values[0x1120038]=0
        assert(#a11y.read_native_windows(base).windows==2,"child back-link must agree")
    end)
end)

check("a committed native list still reports a page change with no new list callback",function()
    with_native_pages(function(memory,values,snapshot)
        with_focus_memory({},function(tick)
            a11y.observe_native_list_selection(values[0x110000],"exercise-record",0x110000)
            tick(120);tick(123)
            assert(speech_texts()[1]:find("Guia sem catálogo. Exercício comum",1,true))
            memory[0x800000+0x1d0]=1
            tick(130);tick(133)
            assert(#speech_texts()==2 and speech_texts()[2]:find("Outra guia. Exercício comum",1,true))
            tick(140);assert(#speech_texts()==2)
            memory[0x800000+0x1d0]=0
            tick(150);tick(153)
            assert(#speech_texts()==3 and speech_texts()[3]:find("Guia sem catálogo.",1,true))
        end)
    end)
end)

check("review uses the composed field's current value without waiting for another focus event",function()
    with_rendered_panel({[0x110000]={name="setName",text="Valor do perfil",parent=0x210000}},function()
        local row={label="Valor do perfil",value="Primeiro",label_widget=0x110000,is_control=true}
        assert(a11y.deliver_selection_result(assert(a11y.selection_result({row=row,identity="profile",source="control"}))))
        row.value="Atualizado"
        local items=a11y.buffer_entries()
        assert(items[1]=="Valor do perfil, seletor, Atualizado")
        assert(not table.concat(items," | "):find("Primeiro",1,true))
    end)
end)

check("a committed entity without a proven player panel does not expose the other carousel clubs",function()
    with_rendered_panel({[0x110000]={name="teamName",text="Clube selecionado",parent=0x210000},
        [0x120000]={name="teamName",text="Clube lateral",parent=0x210000}},function(values,snapshot)
        snapshot.selected_members={[0x110000]=true};snapshot.cursor_members={[0x110000]=true}
        a11y.observe_native_list_selection(values[0x110000],"selected-record",0x110000)
        assert(a11y.process_native_list_focus(false))
        local items=a11y.buffer_entries()
        assert(#items==1 and items[1]=="Clube selecionado")
    end)
end)

check("assignment context follows the native column and same-owner captions in arbitrary visit order",function()
    with_rendered_panel({[0x110000]={name="personalDataName",text="Usuário 2",parent=0x300000},
        [0x120000]={name="personalDataName",text="Usuário 2",parent=0x310000},
        [0x130000]={name="personalDataName",text="Usuário 2",parent=0x320000},
        [0x140000]={name="text_home",text="Em casa",parent=0x230000},
        [0x150000]={name="text_away",text="Fora",parent=0x230000}},function(values,snapshot)
        local base=0x140000000
        local old_base=upvalue(module.init,"process_base_u64")
        set_upvalue(module.init,"process_base_u64",ffi.cast("uint64_t",base))
        local memory={[0x810000]=base+0x2715608,[base+0x2715608+0x140]=base+0xc68fd0,
            [base+0x2715608+0x148]=base+0xc67970,[0x810094]=0,[0x8100a4]=2,
            [0x900100]=base+0x27bae88,[0x900270]=0x200000,[0x900278]=0x200008,
            [0x200000]=0x210000,[0x210000]=base+0x27b8d60,
            [0x210170]=0x220000,[0x210178]=0x220018}
        for index=0,2 do
            local column=0x300000+index*0x10000
            memory[0x220000+index*8]=column;memory[column]=base+0x27cb508
            memory[column+0x170],memory[column+0x178]=0x400000+index*0x100,0x400008+index*0x100
            memory[0x400000+index*0x100]=0x110000+index*0x10000
        end
        for at in pairs(values) do memory[at]=base+0x27b5260;memory[at+0xc]=263 end
        a11y.menu_read=function(at) return memory[at] end
        snapshot.windows[2]={address=0x810000,root=0x900100,task_parent=0x800000,enabled=true}
        local expected={[0]="Em casa",[1]="Neutro",[2]="Fora"}
        with_focus_memory({},function(tick)
            for index,state in ipairs({2,0,1}) do
                memory[0x8100a4]=state
                local address=0x110000+state*0x10000
                snapshot.selected_members={[address]=true}
                local detail=assert(a11y.native_assignment_context(address))
                assert(detail.state==state and detail.text==expected[state])
                tick(120+index*10);tick(123+index*10)
                assert(speech_texts()[index]=="Usuário 2, " .. expected[state])
                tick(125+index*10);assert(#speech_texts()==index)
            end
            memory[0x8100a4]=9
            assert(not a11y.native_assignment_context(0x120000))
            assert(not a11y.selection_result_allowed(a11y.read_context_state().selection_result))
            memory[0x8100a4]=0;snapshot.selected_members={[0x110000]=true}
            snapshot.windows[2].task_parent=0xdead0000
            assert(not a11y.native_assignment_context(0x110000),"unrelated headings cannot name the column")
        end)
        set_upvalue(module.init,"process_base_u64",old_base)
    end)
end)

check("a selection deferred during a paragraph cannot deliver its obsolete value afterwards",function()
    with_rendered_panel({[0x110000]={name="setName",text="Campo sem catálogo de tela",parent=0x210000},
        [0x120000]={name="text",text="6",parent=0x220000}},function(values)
        local row={label="Campo sem catálogo de tela",value="6",label_widget=0x110000,
            value_widget=0x120000,is_control=true}
        local result=assert(a11y.selection_result({row=row,identity="field",source="control"}))
        set_upvalue(speak,"modal_focus_hold_until_ms",tonumber(ffi.C.GetTickCount64())+10000)
        assert(not a11y.deliver_selection_result(result))
        assert(a11y.deferred_modal_announcement and #speech_texts()==0)
        row.value,values[0x120000]="10","10"
        set_upvalue(speak,"modal_focus_hold_until_ms",0)
        with_render_harness(function(output)
            module.display_frame({})
            assert(#output==0,"obsolete delayed field reached Prism: " .. (output[1] and output[1][1] or ""))
            assert(a11y.deliver_selection_result(assert(a11y.selection_result({row=row,identity="field",source="control"}))))
            a11y.flush_native_speech(100000)
            assert(#output==1 and output[1][1]=="Campo sem catálogo de tela, 10")
        end)
    end)
end)

check("a valid deferred selection waits for the paragraph then delivers once with its evidence",function()
    with_rendered_panel({[0x110000]={name="text",text="Comando ainda atual",parent=0x210000}},function()
        local result=assert(a11y.selection_result({widget=0x110000,identity="command",source="component"}))
        set_upvalue(speak,"modal_focus_hold_until_ms",tonumber(ffi.C.GetTickCount64())+10000)
        assert(not a11y.deliver_selection_result(result) and result.status=="deferred")
        assert(not a11y.drain_deferred_speech() and a11y.deferred_speech)
        set_upvalue(speak,"modal_focus_hold_until_ms",0)
        assert(a11y.drain_deferred_speech() and result.status=="queued")
        assert(not a11y.drain_deferred_speech())
        assert(a11y.native_speech_queue[a11y.native_speech_last].selection_result==result)
        with_render_harness(function(output)
            a11y.flush_native_speech(100000)
            assert(#output==1 and output[1][1]=="Comando ainda atual" and not output[1][2])
        end)
        assert(result.status=="delivered")
        assert(a11y.deliver_selection_result(assert(a11y.selection_result({widget=0x110000,
            identity="command",source="component"}))) and #speech_texts()==0)
    end)
end)

check("deferred speech rejects an owner change even before a context reset",function()
    with_rendered_panel({[0x110000]={name="text",text="Item da janela anterior",parent=0x210000}},function(_,snapshot)
        set_upvalue(speak,"modal_focus_hold_until_ms",tonumber(ffi.C.GetTickCount64())+10000)
        speak("Item da janela anterior",true,false,"old-item",0x110000)
        assert(a11y.deferred_speech and #speech_texts()==0)
        snapshot.windows[1].root=0x990000
        set_upvalue(speak,"modal_focus_hold_until_ms",0)
        assert(not a11y.drain_deferred_speech() and #speech_texts()==0)
    end)
end)

check("deferred speech rejects a recycled widget and reset removes the pending packet",function()
    with_rendered_panel({[0x110000]={name="text",text="Legenda compartilhada",parent=0x210000}},function()
        set_upvalue(speak,"modal_focus_hold_until_ms",tonumber(ffi.C.GetTickCount64())+10000)
        speak("Legenda compartilhada",true,false,"old-widget",0x110000)
        local node=a11y.ui_model.nodes[host.memory.hex(0x110000)]
        node.identity=node.identity .. ":reused"
        set_upvalue(speak,"modal_focus_hold_until_ms",0)
        assert(not a11y.drain_deferred_speech() and #speech_texts()==0)
        a11y.defer_speech("Nova legenda",nil,nil)
        a11y.reset_read_context("next-dialog")
        assert(not a11y.deferred_modal_announcement and not a11y.deferred_speech)
        assert(not a11y.drain_deferred_speech())
    end)
end)

-- These packets preserve actual captions/values observed in dev 18. Supplying
-- their field relation here tests composition, not discovery or live coverage.
local observed_fields=assert(loadfile(sider_dir .. "/../FLAccess/tests/fixtures/observed-fields-dev18.lua"))()
for _,packet in ipairs(observed_fields.rows) do
    check("observed field packet sequence=" .. packet.sequence .. " label=" .. packet.label,function()
        with_rendered_panel({[0x110000]={name=packet.name,text=packet.label,parent=0x210000}},function()
            local row={label=packet.label,value=packet.value,label_widget=0x110000,is_control=true}
            local result=assert(a11y.selection_result({row=row,identity=packet.key,source="control"}))
            assert(result.label==packet.label and result.value==packet.value)
            assert(a11y.deliver_selection_result(result))
            assert(a11y.buffer_entries()[1]==result.text)
            with_render_harness(function(output)
                a11y.flush_native_speech(100000)
                assert(#output==1 and output[1][1]==packet.label .. ", " .. packet.value)
            end)
        end)
    end)
end

print("FLACCESS_OFFLINE_TESTS_OK checks=" .. checks ..
    " pt=" .. a11y.text_asset_counts.pt ..
    " en=" .. a11y.text_asset_counts.en)
