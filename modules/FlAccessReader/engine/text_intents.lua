local function clean_text(text)
    -- PES formatting markers use control byte 0x11 plus two command bytes.
    -- Keep the controls used by Game Plan tutorials. Stripping every marker
    -- made sentences such as "hold A" become only "hold".
    if a11y.control_symbol_text then text=a11y.control_symbol_text(text) end
    if a11y.ui_language == "pt" then
        text = text:gsub("\17ka", "botão A")
        text = text:gsub("\17jm", "analógico esquerdo")
        text = text:gsub("\238\130\146", "direcional")
    else
        text = text:gsub("\17ka", "A button")
        text = text:gsub("\17jm", "left stick")
        text = text:gsub("\238\130\146", "D-pad")
    end
    -- Scroll separators have no parameter. Consuming a third byte removes
    -- the first letter of the next copy of a scrolling caption.
    local scrolling=text:find("\17s",1,true)~=nil
    text = text:gsub("\17s", "")
    text = text:gsub("\17..", "")
    text = text:gsub("[\r\n\t]+", " ")
    text = text:gsub("[%z\1-\31]", "")
    -- Form arrows and condition icons are Unicode Private Use Area glyphs.
    -- They have no useful spoken name and can stop some speech backends.
    text = text:gsub("\238[\128-\191][\128-\191]", "")
    text = text:match("^%s*(.-)%s*$") or ""
    if scrolling then
        text=text:gsub("%s+"," ")
        -- Marquee buffers contain two identical copies, separated by padding.
        -- Collapse only exact halves, never repeated words in ordinary text.
        for at=1,#text do
            if text:sub(at,at)==" " and text:sub(1,at-1)==text:sub(at+1) then
                text=text:sub(1,at-1);break
            end
        end
    end
    return text
end

a11y.ui_strings = {
    pt = {
        title = "FlAccessReader %s",
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
        opened = "Sider. FlAccessReader versão %s. Leitura de menus ativa. Duas opções. %s. 6 e 7 navegam; 9 e 0 alteram; 8 restaura o padrão.",
        closed = "Sider fechado",
        tooltip_changed = "Ler tooltips, %s",
        diagnostic_changed = "Modo de diagnóstico, %s",
        diagnostic_file = "O diagnóstico será salvo em FLAccess-diagnostic.log",
        diagnostic_failed = "Não foi possível criar FLAccess-diagnostic.log",
        sider = "Sider",
        module = "módulo",
    },
    en = {
        title = "FlAccessReader %s",
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
        opened = "Sider. FlAccessReader version %s. Menu reading enabled. Two options. %s. 6 and 7 navigate; 9 and 0 change; 8 restores the default.",
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

function a11y.load_text_assets()
    if not a11y.use_text_assets or not a11y.sider_dir then
        return false
    end
    local loaded = false
    for _, language in ipairs({"pt", "en"}) do
        local path = a11y.sider_dir .. "\\livecpk\\FlAccessReader\\text\\" ..
            language .. ".tsv"
        local file = io.open(path, "rt")
        if file then
            local roles = {}
            local templates = {}
            local count = 0
            for line in file:lines() do
                if line:sub(1, 1) ~= "#" then
                    local role, text = line:match("^([^\t]+)\t(.+)$")
                    if role and text and roles[text] == nil then
                        roles[text] = role
                        count = count + 1
                        if (role == "dialog" or role == "instruction")
                                and text:find("%%%d*%$?s") then
                            local pieces = {}
                            local position = 1
                            local first_prefix = ""
                            while true do
                                local first, last = text:find(
                                    "%%%d*%$?s", position)
                                if not first then break end
                                local literal = text:sub(position, first - 1)
                                if #pieces == 0 then first_prefix = literal end
                                pieces[#pieces + 1] = literal:gsub(
                                    "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                                position = last + 1
                            end
                            local suffix = text:sub(position)
                            pieces[#pieces + 1] = suffix:gsub(
                                "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                            if #first_prefix + #suffix >= 15 then
                                templates[#templates + 1] = {
                                    role=role,
                                    prefix=first_prefix,
                                    suffix=suffix,
                                    pattern="^" .. table.concat(pieces, ".+") .. "$",
                                }
                            end
                        end
                    end
                end
            end
            file:close()
            a11y.text_asset_roles[language] = roles
            a11y.text_asset_templates[language] = templates
            a11y.text_asset_counts[language] = count
            loaded = true
            log(string.format(
                "[FLAccess] text-assets-loaded language=%s count=%d path=%q",
                language, count, path))
        else
            log(string.format(
                "[FLAccess] text-assets-missing language=%s path=%q",
                language, path))
        end
    end
    return loaded
end

function a11y.text_asset_role(text)
    if not a11y.use_text_assets or not text or text == "" then
        return nil
    end
    local roles = a11y.text_asset_roles[a11y.ui_language]
    local role = roles and roles[text] or nil
    if role or #text < 60 then return role end
    for _, template in ipairs(a11y.text_asset_templates[a11y.ui_language]) do
        if text:sub(1, #template.prefix) == template.prefix
                and (#template.suffix == 0
                    or text:sub(-#template.suffix) == template.suffix)
                and text:match(template.pattern) then
            return template.role
        end
    end
    return nil
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
        elseif name == "use_text_assets" then
            value = value:lower()
            a11y.use_text_assets = value ~= "false" and value ~= "no" and value ~= "0"
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
    file:write("use_text_assets = ", a11y.use_text_assets and "true" or "false", "\n")
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
    file:write("version=", VERSION, "\nbuild=", tostring(a11y.build), "\n")
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
    a11y.main_menu_tooltip_choice=nil
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
    elseif text:find("volume da narração e dos comentários", 1, true) then
        return "Volume dos comentários"
    elseif text:find("sons e cantos da torcida", 1, true) then
        return "Em jogo: Barulho da torcida"
    elseif text:find("anúncios do sistema de som", 1, true) then
        return "Em jogo: Anúncios do estádio"
    elseif text:find("músicas do jogo tocadas nos estádios", 1, true) then
        return "Em jogo: Músicas do estádio"
    elseif text:find("sons do campo", 1, true) then
        return "Em jogo: Sons do campo"
    elseif text:find("número de usuários participantes", 1, true) then
        return "Número de usuários"
    elseif text:find("nível de dificuldade das partidas", 1, true) then
        return "Nível da partida"
    elseif text:find("duração da partida", 1, true) then
        return "Duração da partida"
    elseif text:find("jogadores sofrem lesões", 1, true) then
        return "Lesões"
    elseif text:find("configurações de câmera que serão usadas", 1, true) then
        return "Configurações de câmera"
    end
    return nil
end

local function looks_like_message(text, widget)
    if a11y.is_structural_answer(text, widget and memory.hex(widget)) then return false end
    if is_noninteractive_text(text) or is_splash_text(text) then
        return false
    end
    local role = a11y.text_asset_role(text)
    if role == "dialog" or role == "instruction" or role == "status"
            or role == "tooltip-or-description" then
        return true
    elseif role == "control" or role == "dialog-button"
            or role == "menu-item-or-title" or role == "label-or-name" then
        return false
    end
    local name = widget and a11y.widget_internal_name(widget)
    if name and (name:match("_item$") or name:match("_value$")) then
        return false
    end
    return (#text >= 55
        or (#text >= 28 and text:match("[%.%!%?]$") ~= nil)
    )
end

local function is_cup_group_message(text)
    local lower = text:lower()
    return lower:find("agrupamentos da fase de grupos", 1, true) ~= nil
        or lower:find("group stage groups", 1, true) ~= nil
        or lower:find("groupings for the group stage", 1, true) ~= nil
end

function a11y.activate_cup_group_table(reset_cells)
    if a11y.cup_group_table_active and not reset_cells then return end
    a11y.cup_group_table_active = true
    a11y.cup_group_cell_by_widget = {}
    a11y.cup_group_current_cell = nil
    a11y.cup_group_last_announced = nil
    a11y.cup_group_last_navigation_frame = -10000
    a11y.reset_focus_reuse_state()
end

function a11y.is_cup_group_header(widget, text)
    return text and (text:match("^Grupo [A-H]$")
        or text:match("^Group [A-H]$"))
        and a11y.widget_internal_name(widget) == "groupName" or false
end

function a11y.is_instruction_message(text)
    if a11y.text_asset_role(text) == "instruction" then
        return true
    end
    local lower = text:lower()
    return lower:find("enquanto segura", 1, true) ~= nil
        or lower:find("mantendo pressionado", 1, true) ~= nil
        or lower:find("use escalação/editar posição", 1, true) ~= nil
        or lower:find("while holding", 1, true) ~= nil
        or lower:find("hold the", 1, true) ~= nil
        or lower:find("use team sheet/edit position", 1, true) ~= nil
end

local function is_modal_button(text)
    return text == "Concordo." or text == "I agree."
        or a11y.text_asset_role(text) == "dialog-button"
        or text == "Sim" or text == "Não" or text == "OK"
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
        native_owner = a11y.native_owner_token(),
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
    local node=widget_key and a11y.ui_model and a11y.ui_model.nodes[widget_key]
    if a11y.is_menu_description(node) then return end
    if a11y.is_match_ready_notice(text) and a11y.native_pause_context() then return end
    if not a11y.native_key_allowed(widget_key) then return end
    local observed=widget_key and a11y.ui_model and a11y.ui_model.nodes[widget_key]
    if observed and a11y.capture_reading_panel(observed) then return end
    if observed and not a11y.native_presentation_ready(observed.address) then
        a11y.defer_bound_guidance(observed.address,text)
        return
    end
    local message_role = a11y.text_asset_role(text)
    if a11y.dashboard_review and not a11y.read_context_state().structural_question
            and not a11y.read_context_state().structural_event then
        -- Loaded flow metadata must not silence a bound, current dialog.
        -- Keep ambient panel content in review; require an observed object.
        local node = a11y.ui_model and a11y.ui_model.nodes[widget_key]
        if message_role ~= "dialog" or not node or node.text ~= text then return end
    end
    if a11y.is_structural_answer(text,widget_key) then return end
    if is_modal_button(text) or is_noninteractive_text(text) then
        return
    end
    if control_label_from_tooltip(text) or a11y.is_control_help(text) then
        -- Focus help belongs after its label/type/value, not in the modal
        -- paragraph queue. The UI text hook schedules it as a tooltip.
        return
    end
    if message_role == "dialog" or message_role == "instruction" then
        a11y.transition_old_focus_texts = nil
        a11y.transition_guard_until_ms = 0
    end
    if a11y.pre_match_active and a11y.pre_match_notice_text == text then
        -- The ready notice is redrawn in the background of pre-match
        -- submenus. Re-queuing it on each draw can mute real navigation.
        return
    end
    local lower = text:lower()
    local cup_group_message = is_cup_group_message(text)
    if cup_group_message then
        -- Cup group assignment is a focusable table, but unlike the league and
        -- club carousels it does not pass through either native list renderer.
        -- Reset the cell map after its introduction, including when the
        -- structural group headers enabled the table earlier.
        a11y.activate_cup_group_table(true)
    end
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
        a11y.leave_game_plan()
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
            and widget_key == recent_message_widget_key
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
        if (pending_message_text
                and a11y.pending_message_widget_key == recent_message_widget_key
                and recent_message_text:sub(1, #pending_message_text)
                    == pending_message_text)
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
        return
    end
    local observed = a11y.ui_model and a11y.ui_model.nodes[widget_key]
    if looks_like_message(text, observed and observed.address)
            or a11y.is_instruction_message(text) or is_data_notice(text) then
        recent_message_text = text
        recent_message_widget_key = widget_key
        recent_message_frame = frame
        log(string.format(
            "[FLAccess] message-candidate text=%q",
            recent_message_text))
        if message_role == "dialog" or (text:match("%?$"))
                or cup_group_message
                or text:find("A partida começará quando os dois times", 1, true)
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
    -- Setter arguments frequently point into a caller's temporary stack.
    -- Only copied observations may survive the callback; never poll that pointer.
    local node=a11y.ui_model and a11y.ui_model.nodes[recent_message_widget_key]
    if not node or not a11y.native_widget_allowed(node.address)
            or not a11y.ui_node_matches_live(node) then return end
    local text=node.text
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
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if key == last_announced_message_key then
        return
    end
    if pending_message_text then
        if pending_message_key == key then return end
        if a11y.pending_message_widget_key == recent_message_widget_key
                and recent_message_text:sub(1, #pending_message_text)
                    == pending_message_text then
            -- A dialog sentence can arrive in two UI text writes. Replace
            -- the pending prefix instead of speaking prefix and full copy.
            pending_message_text = recent_message_text
            pending_message_key = key
            pending_message_due_ms = now_ms + 40
            a11y.open_read_dialog(recent_message_text, recent_message_widget_key)
            return
        end
        for _, entry in ipairs(a11y.modal_message_backlog) do
            if entry.key == key then return end
        end
        a11y.modal_message_backlog[#a11y.modal_message_backlog + 1] = {
            text=recent_message_text,
            key=key,
        }
        return
    end
    pending_message_text = recent_message_text
    pending_message_key = key
    a11y.pending_message_widget_key = recent_message_widget_key
    a11y.pending_message_owner=a11y.native_owner_token()
    pending_message_due_ms = now_ms
        + (recent_message_text:match("[%.%!%?]$") and 40 or 160)
    -- Any fresh message may own a paired Sim/Não confirmation. Require its
    -- buttons to be rendered with this message before using their focus bits.
    a11y.modal_dialog_start_frame = frame
    a11y.confirmation_dialog_until_frame = frame + 900
    a11y.open_read_dialog(recent_message_text, recent_message_widget_key)
    a11y.modal_navigation_last_ms = nil
    -- A newly detected dialog owns the next output. Drop focus announcements
    -- captured earlier in this render slice before the text hook arrived.
    local pending_title
    if last_screen_title_key and frame - a11y.last_screen_title_frame <= 120 then
        for index = a11y.native_speech_first,
                a11y.native_speech_last do
            local entry = a11y.native_speech_queue[index]
            if entry and entry.text == last_screen_title_key then
                pending_title = entry
                break
            end
        end
    end
    a11y.clear_speech_queue(pending_title)
    a11y.deferred_modal_announcement = nil
    a11y.pending_modal_button_text = nil
    pending_controller_tooltip = nil
    pending_controller_tooltip_label = nil
    controller_tooltip_due_ms = nil
    dynamic_text_candidate = nil
    dynamic_text_due_ms = nil
    main_menu_tooltip = nil
    main_menu_tooltip_due_ms = nil
end

speak = function(text, interrupt, modal, identity, origin_widget)
    if not text or text == "" or text == "No String" or text == "/" or a11y.unresolved_format(text) then
        return
    end
    local source_node=origin_widget and a11y.ui_model and a11y.ui_model.nodes[memory.hex(origin_widget)]
    if source_node and (a11y.is_media_caption(source_node) or (a11y.is_menu_description(source_node)
            and not (identity and identity:sub(1,8)=="tooltip:"))) then return end
    if a11y.selected_message_packet and a11y.selected_message_packet()
            and not overlay_visible and not sider_overlay_visible
            and not (identity and (identity:sub(1,17)=="selected-message:" or identity:sub(1,7)=="review:"
                or identity:sub(1,8)=="loading:")) then return end
    local information=a11y.native_information_context()
    if information and not overlay_visible and not sider_overlay_visible
            and a11y.read_context_state().kind~="dialog"
            and not (identity and (identity:sub(1,14)=="visualization:" or identity:sub(1,19)=="information-header:")) then return end
    if a11y.native_pause_context() and a11y.is_match_ready_notice(text) then
        a11y.poll_native_pause();return
    end
    if a11y.cup_group_table_active
            and (text == "OK, item selecionado"
                or text == "OK, botão selecionado") then
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
            text = effective .. default_suffix .. (a11y.ui_language == "pt"
                    and ", selecionada" or ", selected")
        end
    end
    if not game_is_foreground() then
        return
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if (text == "OK, item selecionado"
            or text == "OK, botão selecionado")
            and not modal and (pending_message_text
                or (modal_message_spoken_frame > 0
                    and now_ms < modal_focus_hold_until_ms + 1000)) then
        return
    end
    if text == last_spoken_text and now_ms - last_spoken_ms < 40
            and (not identity or identity == a11y.last_spoken_identity) then
        return
    end
    if pending_message_text and not modal then
        a11y.defer_speech(text,identity,origin_widget)
        return
    end
    -- Prism has no completion callback. While a modal paragraph is expected
    -- to be spoken, send later announcements to its non-interrupting queue.
    if now_ms < modal_focus_hold_until_ms then
        if interrupt ~= false and not modal then
            -- Rapid focus changes during a paragraph should not leave every
            -- obsolete item queued in Prism. Keep only the latest announcement.
            a11y.defer_speech(text,identity,origin_widget)
            return
        end
        interrupt = false
    elseif interrupt ~= false then
        a11y.deferred_modal_announcement = nil
        a11y.deferred_speech=nil
    end
    if a11y.title_pending_first_item then
        if now_ms <= a11y.title_pending_first_item_until_ms
                and text ~= a11y.title_pending_first_item then
            -- The automatically focused first row must not interrupt the
            -- title that was just submitted to the screen reader.
            interrupt = false
        end
        a11y.title_pending_first_item = nil
    end
    speech_sequence = speech_sequence + 1
    local mode = interrupt == false and "queue" or "interrupt"
    last_spoken_text = text
    a11y.last_spoken_identity = identity
    last_spoken_ms = now_ms
    a11y.native_speech_last = a11y.native_speech_last + 1
    a11y.native_speech_queue[a11y.native_speech_last] = {
        sequence=speech_sequence,
        text=text,
        interrupt=interrupt ~= false,
        mode=mode,
        identity=identity,
        presentation_owner=a11y.native_owner_token(),
        origin=origin_widget and a11y.capture_speech_origin(origin_widget) or nil,
    }
    if origin_widget then
        log("[FLAccess] speech-origin sequence=" .. tostring(speech_sequence) .. " widget=" .. memory.hex(origin_widget)
            .. " owner=" .. tostring(a11y.native_owner_token()))
    else
        log("[FLAccess] speech-origin sequence=" .. tostring(speech_sequence) .. " source=legacy-or-system")
    end
end

-- All queue replacement goes through this function, including modal takeover.
-- One publication lifecycle for every producer. Validation and delivery are
-- separate: queuing a sentence is not evidence that Prism accepted it.
