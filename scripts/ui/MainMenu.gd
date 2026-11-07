extends Node
## MainMenu — Subway Surfers–style runner chrome over live MenuWorld.

const THEME_PATH := "res://resources/ui/MainMenuTheme.tres"
const Economy = preload("res://scripts/economy/EconomyConfig.gd")
const HINT_SKINS := "Buy skeleton skins with banked souls. Witch is free."
const HINT_UPGRADES := "Permanent upgrades — each level makes every run stronger."
const TAB_ACTIVE_COLOR := Color(0.18, 0.62, 0.78, 1)

@onready var menu_world: Node3D = $MenuWorld
@onready var chrome: Control = %Chrome
@onready var home_layer: Control = %HomeLayer
@onready var main_panel: Control = %MainPanel
@onready var settings_panel: Control = %SettingsPanel
@onready var shop_panel: Control = %ShopPanel
@onready var high_score_label: Label = %HighScoreLabel
@onready var mult_label: Label = %MultLabel
@onready var mult_chip: PanelContainer = %MultChip
@onready var mission_box: VBoxContainer = %MissionBox
@onready var mission_labels: Array[Label] = [%Mission1, %Mission2, %Mission3]
@onready var mission_bars: Array[ProgressBar] = [%MissionBar1, %MissionBar2, %MissionBar3]
@onready var mission_counts: Array[Label] = [%MissionCount1, %MissionCount2, %MissionCount3]
@onready var mission_cards: Array[Control] = [%MissionCard1, %MissionCard2, %MissionCard3]
@onready var soul_wallet_label: Label = %SoulWalletLabel
@onready var brand_label: Label = %Brand
@onready var start_button: Button = %StartButton
@onready var shop_button: Button = %ShopButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var settings_back: Button = %SettingsBackButton
@onready var shop_balance_label: Label = %ShopBalanceLabel
@onready var shop_status_label: Label = %ShopStatusLabel
@onready var shop_back: Button = %ShopBackButton
@onready var skin_list: VBoxContainer = %SkinList
@onready var upgrade_list: VBoxContainer = %UpgradeList
@onready var shop_hint: Label = %ShopHint
@onready var shop_scroll: ScrollContainer = %ShopScroll
@onready var skins_tab_button: Button = %SkinsTabButton
@onready var upgrades_tab_button: Button = %UpgradesTabButton
@onready var transition_fade: ColorRect = %TransitionFade
@onready var vignette_top: ColorRect = %VignetteTop
@onready var vignette_bottom: ColorRect = %VignetteBottom

var _starting: bool = false
var _ui_tween: Tween = null
var _pulse_tween: Tween = null
var _brand_tween: Tween = null
var _skin_action_buttons: Dictionary = {} ## skin_id -> Button
## upgrade_id -> {button, level_label, effect_label, pips: Array[ColorRect]}
var _upgrade_rows: Dictionary = {}
var _shop_tab: String = "skins"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.state = GameManager.State.MENU
	if AudioManager:
		AudioManager.play_menu_music()
	_apply_title_font()
	_refresh_highscore()
	_refresh_multiplier()
	_refresh_missions()
	_refresh_souls()
	_sync_audio_toggles()
	_show_main()
	_build_skin_shop_rows()
	_build_upgrade_shop_rows()
	_setup_shop_tabs()
	_refresh_shop_state()
	start_button.pressed.connect(_on_start)
	shop_button.pressed.connect(_on_shop)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	settings_back.pressed.connect(_on_settings_back)
	shop_back.pressed.connect(_on_shop_back)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if not ScoreManager.highscore_changed.is_connected(_on_highscore_changed):
		ScoreManager.highscore_changed.connect(_on_highscore_changed)
	if not ScoreManager.total_souls_changed.is_connected(_on_total_souls_changed):
		ScoreManager.total_souls_changed.connect(_on_total_souls_changed)
	if SkinManager and not SkinManager.skins_changed.is_connected(_on_skins_changed):
		SkinManager.skins_changed.connect(_on_skins_changed)
	if UpgradeManager and not UpgradeManager.upgrades_changed.is_connected(_on_skins_changed):
		UpgradeManager.upgrades_changed.connect(_on_skins_changed)
	if MissionManager:
		if not MissionManager.multiplier_changed.is_connected(_on_multiplier_changed):
			MissionManager.multiplier_changed.connect(_on_multiplier_changed)
		if not MissionManager.missions_changed.is_connected(_on_missions_changed):
			MissionManager.missions_changed.connect(_on_missions_changed)
	start_button.grab_focus()
	_wire_button_hovers()
	call_deferred("_start_cta_pulse")
	call_deferred("_start_brand_glow")
	call_deferred("_play_chrome_intro")


func _apply_title_font() -> void:
	var theme_res: Theme = load(THEME_PATH) as Theme
	if theme_res == null or brand_label == null:
		return
	## Prefer the theme's bold Fredoka variation when available.
	var title_font: Font = theme_res.get_font("font", "Label")
	if theme_res.has_font("title", "GraveDash"):
		title_font = theme_res.get_font("title", "GraveDash")
	## Fall back: load Fredoka directly as a variation.
	var fredoka: FontFile = load("res://assets/fonts/Fredoka.ttf") as FontFile
	if fredoka:
		var variation := FontVariation.new()
		variation.base_font = fredoka
		variation.variation_opentype = {2003265652: 700}
		brand_label.add_theme_font_override("font", variation)


func _start_cta_pulse() -> void:
	if start_button == null:
		return
	await get_tree().process_frame
	start_button.pivot_offset = start_button.size * 0.5
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(start_button, "scale", Vector2(1.06, 1.06), 0.7)
	_pulse_tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.7)


func _start_brand_glow() -> void:
	if brand_label == null:
		return
	await get_tree().process_frame
	brand_label.pivot_offset = brand_label.size * 0.5
	if _brand_tween != null and _brand_tween.is_valid():
		_brand_tween.kill()
	_brand_tween = create_tween().set_loops()
	_brand_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_brand_tween.tween_property(brand_label, "modulate", Color(1.12, 1.18, 1.08, 1.0), 1.1)
	_brand_tween.tween_property(brand_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.1)


func _play_chrome_intro() -> void:
	## Soft rise-in for top chips + missions so the menu feels alive.
	if home_layer == null:
		return
	await get_tree().process_frame
	var top_bar: Control = home_layer.get_node_or_null("TopBar") as Control
	var missions: Control = home_layer.get_node_or_null("MissionsPanel") as Control
	var title: Control = home_layer.get_node_or_null("TitleBlock") as Control
	var intro := create_tween()
	intro.set_parallel(true)
	for c in [top_bar, missions, title, main_panel]:
		if c == null:
			continue
		c.modulate.a = 0.0
		intro.tween_property(c, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	if title:
		title.scale = Vector2(0.94, 0.94)
		title.pivot_offset = title.size * 0.5
		intro.tween_property(title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _wire_button_hovers() -> void:
	## Secondary buttons get a snappy scale pop; START keeps its pulse loop.
	for btn in [shop_button, settings_button, quit_button]:
		if btn == null:
			continue
		btn.mouse_entered.connect(_on_nav_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_nav_hover.bind(btn, false))
		btn.focus_entered.connect(_on_nav_hover.bind(btn, true))
		btn.focus_exited.connect(_on_nav_hover.bind(btn, false))
	if start_button:
		start_button.mouse_entered.connect(_on_start_hover.bind(true))
		start_button.mouse_exited.connect(_on_start_hover.bind(false))


func _on_nav_hover(btn: Button, entered: bool) -> void:
	if btn == null or _starting:
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.08, 1.08) if entered else Vector2.ONE, 0.14)


func _on_start_hover(entered: bool) -> void:
	if start_button == null or _starting:
		return
	## Nudge above the idle pulse when hovered.
	start_button.pivot_offset = start_button.size * 0.5
	if entered and _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		start_button.scale = Vector2(1.1, 1.1)
	elif not entered:
		call_deferred("_start_cta_pulse")


func _refresh_highscore() -> void:
	high_score_label.text = "%d" % ScoreManager.highscore


func _refresh_multiplier() -> void:
	var mult: int = MissionManager.get_multiplier() if MissionManager else 1
	if mult_label:
		mult_label.text = "x%d" % mult
	if mult_chip:
		mult_chip.modulate = Color(1.0, 1.0, 1.0, 1.0) if mult <= 1 else Color(1.08, 1.05, 0.95, 1.0)


func _refresh_missions() -> void:
	if MissionManager == null:
		return
	var missions: Array[Dictionary] = MissionManager.get_active_missions()
	for i in mission_labels.size():
		var label: Label = mission_labels[i]
		var bar: ProgressBar = mission_bars[i] if i < mission_bars.size() else null
		var count: Label = mission_counts[i] if i < mission_counts.size() else null
		var card: Control = mission_cards[i] if i < mission_cards.size() else null
		if i < missions.size():
			var m: Dictionary = missions[i]
			var title: String = str(m.get("title", "Mission"))
			var progress: int = mini(int(m.get("progress", 0)), int(m.get("target", 1)))
			var target: int = maxi(int(m.get("target", 1)), 1)
			if label:
				label.visible = true
				label.text = title
			if count:
				count.text = "%d/%d" % [progress, target]
			if bar:
				bar.max_value = float(target)
				bar.value = float(progress)
			if card:
				card.visible = true
		else:
			if label:
				label.visible = false
			if card:
				card.visible = false


func _on_multiplier_changed(_value: int) -> void:
	_refresh_multiplier()


func _on_missions_changed() -> void:
	_refresh_missions()


func _refresh_souls() -> void:
	var total: int = ScoreManager.total_souls
	soul_wallet_label.text = "%d" % total
	if shop_balance_label:
		shop_balance_label.text = "Balance  %d souls" % total


func _on_highscore_changed(value: int) -> void:
	high_score_label.text = "%d" % value


func _on_total_souls_changed(value: int) -> void:
	soul_wallet_label.text = "%d" % value
	if shop_balance_label:
		shop_balance_label.text = "Balance  %d souls" % value
	_refresh_shop_state()


func _sync_audio_toggles() -> void:
	music_toggle.set_pressed_no_signal(AudioManager.is_music_muted())
	sfx_toggle.set_pressed_no_signal(AudioManager.is_sfx_muted())
	if music_volume_slider:
		music_volume_slider.set_value_no_signal(AudioManager.get_music_volume())
	if sfx_volume_slider:
		sfx_volume_slider.set_value_no_signal(AudioManager.get_sfx_volume())
	_update_toggle_text()


func _update_toggle_text() -> void:
	music_toggle.text = "Music: Muted" if music_toggle.button_pressed else "Music: On"
	sfx_toggle.text = "SFX: Muted" if sfx_toggle.button_pressed else "SFX: On"


func _ui_click() -> void:
	if AudioManager:
		AudioManager.play_ui_click()


func _show_main() -> void:
	if home_layer:
		home_layer.visible = true
	main_panel.visible = true
	settings_panel.visible = false
	shop_panel.visible = false


func _on_start() -> void:
	if _starting:
		return
	_ui_click()
	_starting = true
	_set_menu_interactive(false)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	start_button.scale = Vector2.ONE
	_play_start_transition()


func _set_menu_interactive(enabled: bool) -> void:
	start_button.disabled = not enabled
	shop_button.disabled = not enabled
	settings_button.disabled = not enabled
	quit_button.disabled = not enabled


func _play_start_transition() -> void:
	## 1) Witch starts running + camera dolly (MenuWorld).
	if menu_world != null and menu_world.has_method("begin_start_transition"):
		menu_world.call("begin_start_transition")
	## 2) Menu chrome flies out / fades.
	if _ui_tween != null and _ui_tween.is_valid():
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.set_parallel(true)
	_ui_tween.tween_property(chrome, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	_ui_tween.tween_property(chrome, "position:y", 80.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if vignette_top:
		_ui_tween.tween_property(vignette_top, "modulate:a", 0.0, 0.5)
	if vignette_bottom:
		_ui_tween.tween_property(vignette_bottom, "modulate:a", 0.0, 0.5)
	## 3) Brief soft fade (never linger — scene swap clears this node).
	_ui_tween.set_parallel(false)
	if transition_fade:
		transition_fade.color.a = 0.0
		## Keep the wipe light so gameplay never bootstraps from a black frame.
		_ui_tween.tween_property(transition_fade, "color:a", 0.55, 0.28).set_delay(0.45)
	_ui_tween.tween_callback(_finish_start_transition)


func _finish_start_transition() -> void:
	GameManager.go_to_gameplay()


func _on_shop() -> void:
	_ui_click()
	if home_layer:
		home_layer.visible = false
	main_panel.visible = false
	settings_panel.visible = false
	shop_panel.visible = true
	_refresh_souls()
	_refresh_shop_state()
	shop_status_label.text = ""
	shop_back.grab_focus()


func _on_shop_back() -> void:
	_ui_click()
	shop_panel.visible = false
	_show_main()
	shop_button.grab_focus()
	call_deferred("_start_cta_pulse")


func _on_settings() -> void:
	_ui_click()
	if home_layer:
		home_layer.visible = false
	main_panel.visible = false
	shop_panel.visible = false
	settings_panel.visible = true
	_sync_audio_toggles()
	settings_back.grab_focus()


func _on_settings_back() -> void:
	_ui_click()
	settings_panel.visible = false
	_show_main()
	settings_button.grab_focus()
	call_deferred("_start_cta_pulse")


func _on_music_toggled(pressed: bool) -> void:
	_ui_click()
	AudioManager.set_music_muted(pressed)
	_update_toggle_text()


func _on_sfx_toggled(pressed: bool) -> void:
	_ui_click()
	AudioManager.set_sfx_muted(pressed)
	_update_toggle_text()


func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)


func _on_quit() -> void:
	_ui_click()
	get_tree().quit()


func _setup_shop_tabs() -> void:
	var group := ButtonGroup.new()
	for btn in [skins_tab_button, upgrades_tab_button]:
		if btn == null:
			continue
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_ALL
	skins_tab_button.pressed.connect(_on_shop_tab.bind("skins"))
	upgrades_tab_button.pressed.connect(_on_shop_tab.bind("upgrades"))
	_show_shop_tab("skins")


func _on_shop_tab(tab: String) -> void:
	if tab == _shop_tab:
		return
	_ui_click()
	_show_shop_tab(tab)


func _show_shop_tab(tab: String) -> void:
	_shop_tab = tab
	var on_skins: bool = tab == "skins"
	skin_list.visible = on_skins
	upgrade_list.visible = not on_skins
	skins_tab_button.set_pressed_no_signal(on_skins)
	upgrades_tab_button.set_pressed_no_signal(not on_skins)
	for btn in [skins_tab_button, upgrades_tab_button]:
		var active: bool = btn.button_pressed
		btn.self_modulate = Color(1, 1, 1, 1) if active else Color(0.72, 0.76, 0.82, 1)
		if active:
			btn.add_theme_stylebox_override("normal", _tab_style(TAB_ACTIVE_COLOR))
			btn.add_theme_stylebox_override("pressed", _tab_style(TAB_ACTIVE_COLOR))
			btn.add_theme_stylebox_override("hover", _tab_style(TAB_ACTIVE_COLOR.lightened(0.1)))
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("pressed")
			btn.remove_theme_stylebox_override("hover")
	if shop_hint:
		shop_hint.text = HINT_SKINS if on_skins else HINT_UPGRADES
	if shop_scroll:
		shop_scroll.scroll_vertical = 0


func _tab_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.6, 0.95, 1.0, 0.9)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0.2, 0.8, 1.0, 0.35)
	sb.shadow_size = 8
	return sb


func _card_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18, 0.82)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _build_skin_shop_rows() -> void:
	if skin_list == null or SkinManager == null:
		return
	for c in skin_list.get_children():
		c.queue_free()
	_skin_action_buttons.clear()
	for skin in SkinManager.get_catalog():
		var skin_id: String = str(skin.get("id", ""))
		var color: Color = skin.get("preview_color", Color(0.5, 0.5, 0.5, 1))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style(color))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		## Color swatch preview.
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = color
		row.add_child(swatch)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var title := Label.new()
		title.text = str(skin.get("name", skin_id))
		info.add_child(title)
		var desc := Label.new()
		desc.text = str(skin.get("description", ""))
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.6, 0.68, 0.75, 1))
		info.add_child(desc)
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 56)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.set_meta("skin_id", skin_id)
		btn.pressed.connect(_on_skin_action.bind(skin_id))
		row.add_child(btn)
		skin_list.add_child(card)
		_skin_action_buttons[skin_id] = btn


func _build_upgrade_shop_rows() -> void:
	if upgrade_list == null or UpgradeManager == null:
		return
	for c in upgrade_list.get_children():
		c.queue_free()
	_upgrade_rows.clear()
	for def in UpgradeManager.get_catalog():
		var upgrade_id: String = str(def.get("id", ""))
		var color: Color = def.get("color", Color(0.5, 0.8, 1.0, 1))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style(color))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 52)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = color
		row.add_child(swatch)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var title := Label.new()
		title.text = str(def.get("name", upgrade_id))
		head.add_child(title)
		var level_label := Label.new()
		level_label.add_theme_font_size_override("font_size", 13)
		level_label.add_theme_color_override("font_color", color)
		level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(level_label)
		info.add_child(head)
		var desc := Label.new()
		desc.text = str(def.get("description", ""))
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.6, 0.68, 0.75, 1))
		info.add_child(desc)
		var effect_label := Label.new()
		effect_label.add_theme_font_size_override("font_size", 14)
		effect_label.add_theme_color_override("font_color", Color(0.8, 0.95, 0.85, 1))
		info.add_child(effect_label)
		var pip_row := HBoxContainer.new()
		pip_row.add_theme_constant_override("separation", 4)
		var pips: Array[ColorRect] = []
		for i in UpgradeManager.get_max_level(upgrade_id):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(26, 6)
			pip_row.add_child(pip)
			pips.append(pip)
		info.add_child(pip_row)
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 56)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.set_meta("upgrade_id", upgrade_id)
		btn.pressed.connect(_on_upgrade_action.bind(upgrade_id))
		row.add_child(btn)
		upgrade_list.add_child(card)
		_upgrade_rows[upgrade_id] = {
			"button": btn,
			"level_label": level_label,
			"effect_label": effect_label,
			"pips": pips,
			"color": color,
		}


func _on_skins_changed() -> void:
	_refresh_shop_state()


func _refresh_shop_state() -> void:
	_refresh_upgrade_rows()
	if SkinManager == null:
		return
	for skin in SkinManager.get_catalog():
		var skin_id: String = str(skin.get("id", ""))
		var btn: Button = _skin_action_buttons.get(skin_id) as Button
		if btn == null:
			continue
		var price: int = int(skin.get("price", 0))
		if SkinManager.is_equipped(skin_id):
			btn.text = "Equipped"
			btn.disabled = true
		elif SkinManager.is_owned(skin_id):
			btn.text = "Equip"
			btn.disabled = false
		elif price <= 0:
			btn.text = "Free"
			btn.disabled = false
		else:
			btn.text = "%d souls" % price
			btn.disabled = ScoreManager.total_souls < price


func _refresh_upgrade_rows() -> void:
	if UpgradeManager == null:
		return
	for upgrade_id in _upgrade_rows.keys():
		var row: Dictionary = _upgrade_rows[upgrade_id]
		var level: int = UpgradeManager.get_level(upgrade_id)
		var max_level: int = UpgradeManager.get_max_level(upgrade_id)
		var now_text: String = Economy.format_value(upgrade_id, Economy.value_at(upgrade_id, level))
		var btn: Button = row["button"] as Button
		(row["level_label"] as Label).text = "Lv %d/%d" % [level, max_level]
		if level >= max_level:
			(row["effect_label"] as Label).text = "%s  ·  MAX" % now_text
			btn.text = "MAX"
			btn.disabled = true
		else:
			var next_text: String = Economy.format_value(upgrade_id, Economy.value_at(upgrade_id, level + 1))
			(row["effect_label"] as Label).text = "%s  →  %s" % [now_text, next_text]
			var cost: int = UpgradeManager.get_next_cost(upgrade_id)
			btn.text = "%d souls" % cost
			btn.disabled = not UpgradeManager.can_afford(upgrade_id)
		var color: Color = row["color"]
		var pips: Array = row["pips"]
		for i in pips.size():
			(pips[i] as ColorRect).color = color if i < level else Color(0.25, 0.28, 0.34, 0.9)


func _on_upgrade_action(upgrade_id: String) -> void:
	_ui_click()
	if UpgradeManager == null:
		return
	var err: String = UpgradeManager.buy_upgrade(upgrade_id)
	if err != "":
		shop_status_label.text = err
		return
	var def: Dictionary = Economy.get_upgrade_def(upgrade_id)
	shop_status_label.text = "%s upgraded to Lv %d!" % [
		str(def.get("name", upgrade_id)), UpgradeManager.get_level(upgrade_id)]
	_refresh_shop_state()
	var row: Dictionary = _upgrade_rows.get(upgrade_id, {})
	var btn: Button = row.get("button") as Button
	if btn:
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2(1.12, 1.12)
		create_tween().tween_property(btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_skin_action(skin_id: String) -> void:
	_ui_click()
	if SkinManager == null:
		return
	if SkinManager.is_owned(skin_id):
		var err: String = SkinManager.equip_skin(skin_id)
		if err != "":
			shop_status_label.text = err
		else:
			var skin: Dictionary = SkinManager.get_skin(skin_id)
			shop_status_label.text = "Equipped %s." % str(skin.get("name", skin_id))
		_refresh_shop_state()
		return
	var err_buy: String = SkinManager.buy_skin(skin_id)
	if err_buy != "":
		shop_status_label.text = err_buy
		return
	var bought: Dictionary = SkinManager.get_skin(skin_id)
	shop_status_label.text = "Purchased %s!" % str(bought.get("name", skin_id))
	## Auto-equip on purchase.
	SkinManager.equip_skin(skin_id)
	_refresh_shop_state()
