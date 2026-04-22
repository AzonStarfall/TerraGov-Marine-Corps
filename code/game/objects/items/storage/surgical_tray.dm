/obj/item/storage/surgical_tray
	name = "surgical tray"
	desc = "A small metallic tray covered in sterile tarp. Intended to store surgical tools in a neat and clean fashion."
	icon_state = "surgical_tray"
	atom_flags = CONDUCT
	w_class = WEIGHT_CLASS_BULKY //Should not fit in backpacks
	storage_type = /datum/storage/surgical_tray
	/// The patient currently being interacted with via the UI
	var/mob/living/current_patient
	/// The currently selected tool in the tray UI
	var/obj/item/selected_tool
	/// The currently targeted body zone
	var/selected_zone = BODY_ZONE_CHEST
	/// The mob currently viewing the tray UI
	var/mob/current_viewer
	/// Whether the proximity monitor loop is running
	var/monitoring = FALSE
	/// Set while a tool is temporarily moved out for surgery; suppresses Exited side-effects
	var/surgery_in_progress = FALSE
	/// Stable display order for the tool grid; new tools append to the bottom
	var/list/tool_display_order

/obj/item/storage/surgical_tray/PopulateContents()
	new /obj/item/tool/surgery/scalpel/manager(src)
	new /obj/item/tool/surgery/scalpel(src)
	new /obj/item/tool/surgery/hemostat(src)
	new /obj/item/tool/surgery/retractor(src)
	new /obj/item/tool/surgery/surgical_membrane(src)
	new /obj/item/tool/surgery/cautery(src)
	new /obj/item/tool/surgery/circular_saw(src)
	new /obj/item/tool/surgery/suture(src)
	new /obj/item/tool/surgery/bonegel(src)
	new /obj/item/tool/surgery/bonesetter(src)
	new /obj/item/tool/surgery/FixOVein(src)
	new /obj/item/stack/nanopaste(src)

/obj/item/storage/surgical_tray/update_icon_state()
	. = ..()
	if(!length(contents))
		icon_state = "surgical_tray_e"
	else
		icon_state = "surgical_tray"

/// Close the tray UI for the current viewer.
/obj/item/storage/surgical_tray/proc/close_tray_ui()
	if(current_viewer)
		current_viewer << browse(null, "window=surgical_tray_ui")
	current_viewer = null

/// Watches proximity between viewer and patient; closes the UI if they move apart.
/obj/item/storage/surgical_tray/proc/monitor_proximity()
	monitoring = TRUE
	while(current_viewer && !QDELETED(current_viewer) && \
	      current_patient && !QDELETED(current_patient))
		sleep(5)
		if(!current_viewer || QDELETED(current_viewer))
			break
		if(!current_patient || QDELETED(current_patient) || !current_patient.can_be_operated_on())
			close_tray_ui()
			break
		if(!current_viewer.Adjacent(current_patient))
			close_tray_ui()
			break
	monitoring = FALSE

/// Refresh the UI when items leave the tray.
/obj/item/storage/surgical_tray/Exited(atom/movable/AM, direction)
	. = ..()
	if(surgery_in_progress) // tool is being temporarily relocated for surgery; ignore
		return
	if(AM == selected_tool)
		selected_tool = null
	tool_display_order -= AM
	if(current_viewer && !QDELETED(current_viewer))
		open_tray_ui(current_viewer)

/// Refresh the UI when items are added to the tray.
/obj/item/storage/surgical_tray/Entered(atom/movable/AM, old_loc)
	. = ..()
	if(surgery_in_progress) // tool is being returned after surgery; Exited already handles the refresh
		return
	if(!tool_display_order)
		tool_display_order = list()
	if(!(AM in tool_display_order))
		tool_display_order += AM
	if(current_viewer && !QDELETED(current_viewer))
		open_tray_ui(current_viewer)

// Override attack to intercept before do_surgery runs the radial body selector
/obj/item/storage/surgical_tray/attack(mob/living/M, mob/living/user)
	if(M.can_be_operated_on())
		current_patient = M
		open_tray_ui(user)
		return TRUE
	return ..()

/obj/item/storage/surgical_tray/proc/open_tray_ui(mob/user)
	current_viewer = user
	if(!monitoring)
		INVOKE_ASYNC(src, PROC_REF(monitor_proximity))
	// --- Doll: white.dmi silhouette at 5x (160×160) ---
	var/icon/doll_icon = icon('icons/mob/screen/white.dmi', "zone_sel")
	var/doll_b64 = icon2base64(doll_icon)

	// Selected zone highlight overlay from zone_sel.dmi (drawn on top, non-interactive)
	var/overlay_html = ""
	if(selected_zone)
		var/icon/zone_overlay = icon('icons/mob/screen/zone_sel.dmi', selected_zone)
		var/overlay_b64 = icon2base64(zone_overlay)
		overlay_html = "<img src='data:image/png;base64,[overlay_b64]' width='160' height='160' \
			style='image-rendering:pixelated;position:absolute;top:0;left:0;pointer-events:none;'>"



	var/dat = "<table width='100%' height='100%' cellpadding='0' cellspacing='0'><tr>"

	// --- Left panel: 2-column icon grid, stable insertion order ---
	if(!tool_display_order)
		tool_display_order = list()
	var/list/ordered_tools = list()
	// Add tools in their stable display order
	for(var/obj/item/t in tool_display_order)
		if(!QDELETED(t) && t.loc == src)
			ordered_tools += t
	// Append any contents item not yet tracked (safety fallback)
	for(var/obj/item/t in contents)
		if(!(t in ordered_tools))
			ordered_tools += t

	dat += "<td valign='top' style='border-right:1px solid #555;padding:8px;width:160px;'>"
	dat += "<b style='display:block;margin-bottom:6px;'>Tools</b>"
	dat += "<div style='display:grid;grid-template-columns:1fr 1fr;gap:4px;overflow-y:auto;max-height:370px;'>"
	for(var/obj/item/tool in ordered_tools)
		var/is_selected = (tool == selected_tool)
		var/cell_style = is_selected ? \
			"background:#334466;outline:2px solid #88aaff;" : \
			"background:#222;"
		var/icon/tool_icon = icon(tool.icon, tool.icon_state, SOUTH, 1)
		var/tool_b64 = icon2base64(tool_icon)
		dat += "<a href='byond://?src=[REF(src)];select_tool=[REF(tool)]' title='[html_encode(tool.name)]' \
			style='display:flex;align-items:center;justify-content:center;padding:4px;[cell_style]text-decoration:none;border-radius:2px;'>"
		dat += "<img src='data:image/png;base64,[tool_b64]' width='32' height='32' \
			style='image-rendering:pixelated;'>"
		dat += "</a>"
	if(!length(contents))
		dat += "<i style='color:#888;'>Tray is empty.</i>"
	dat += "</div>"
	dat += "</td>"

	// --- Available surgery steps (all steps applicable with tray tools) ---
	var/next_step_html = ""
	if(!QDELETED(current_patient) && selected_zone && iscarbon(current_patient))
		var/mob/living/carbon/C = current_patient
		var/datum/limb/affected = C.get_limb(selected_zone)
		if(affected && !affected.in_surgery_op)
			var/steps_html = ""
			for(var/datum/surgery_step/step AS in GLOB.surgery_steps)
				if(!step.is_valid_target(C))
					continue
				if(step.can_use(user, C, selected_zone, null, affected) != SURGERY_CAN_USE)
					continue
				// Find tray tools valid for this step
				var/list/valid_tray_tools = list()
				for(var/obj/item/t in contents)
					if(step.tool_quality(t))
						valid_tray_tools += t
				if(!length(valid_tray_tools))
					continue // skip steps that can't be done with current tray contents
				var/list/path_parts = splittext("[step.type]", "/")
				var/step_label = replacetext(path_parts[length(path_parts)], "_", " ")
				step_label = uppertext(copytext(step_label, 1, 2)) + copytext(step_label, 2)
				steps_html += "<div style='display:flex;align-items:center;gap:4px;margin-bottom:3px;'>"
				steps_html += "<span style='color:#aac;font-size:0.8em;min-width:80px;'>[step_label]:</span>"
				steps_html += "<span style='display:flex;flex-wrap:wrap;gap:2px;'>"
				for(var/obj/item/t in valid_tray_tools)
					var/is_sel = (t == selected_tool)
					var/tbg = is_sel ? "background:#334466;outline:2px solid #88aaff;" : "background:#1a2233;"
					var/icon/ti = icon(t.icon, t.icon_state, SOUTH, 1)
					var/tb64 = icon2base64(ti)
					steps_html += "<img src='data:image/png;base64,[tb64]' width='24' height='24' title='[html_encode(t.name)]' style='image-rendering:pixelated;[tbg]border-radius:2px;padding:2px;'>"
				steps_html += "</span></div>"
			if(length(steps_html))
				next_step_html = "<div style='margin-top:8px;padding:5px 7px;background:#111827;border:1px solid #334;border-radius:3px;text-align:left;'>"
				next_step_html += "<div style='color:#88aacc;font-size:0.82em;font-weight:bold;margin-bottom:5px;'>Available steps:</div>"
				next_step_html += steps_html
				next_step_html += "</div>"

	// --- Right panel: target doll with image map ---
	// Image map coords at 5x scale, HTML top-left origin.
	// Derived from zone_sel's get_zone_at BYOND pixel ranges (32px source, bottom-left origin, 1-indexed):
	//   html_x1 = (byond_x_min - 1) * 5
	//   html_x2 = byond_x_max * 5
	//   html_y1 = (32 - byond_y_max) * 5
	//   html_y2 = (33 - byond_y_min) * 5
	dat += "<td valign='top' style='padding:8px;text-align:center;'>"
	dat += "<b style='display:block;margin-bottom:6px;'>Target Zone</b>"
	dat += "<div style='position:relative;display:inline-block;width:160px;height:160px;'>"
	dat += "<img src='data:image/png;base64,[doll_b64]' width='160' height='160' usemap='#zonesel' \
		style='image-rendering:pixelated;display:block;cursor:crosshair;'>"
	dat += overlay_html
	dat += "</div>"
	dat += "<map name='zonesel'>"
	dat += "<area shape='rect' coords='65,25,90,40'    href='byond://?src=[REF(src)];select_zone=eyes'   title='Eyes'>"
	dat += "<area shape='rect' coords='70,40,85,50'    href='byond://?src=[REF(src)];select_zone=mouth'  title='Mouth'>"
	dat += "<area shape='rect' coords='55,10,100,50'   href='byond://?src=[REF(src)];select_zone=head'   title='Head'>"
	dat += "<area shape='rect' coords='35,50,55,95'    href='byond://?src=[REF(src)];select_zone=r_arm'  title='Right arm'>"
	dat += "<area shape='rect' coords='55,50,100,95'   href='byond://?src=[REF(src)];select_zone=chest'  title='Chest'>"
	dat += "<area shape='rect' coords='100,50,120,95'  href='byond://?src=[REF(src)];select_zone=l_arm'  title='Left arm'>"
	dat += "<area shape='rect' coords='35,95,55,115'   href='byond://?src=[REF(src)];select_zone=r_hand' title='Right hand'>"
	dat += "<area shape='rect' coords='55,95,100,115'  href='byond://?src=[REF(src)];select_zone=groin'  title='Groin'>"
	dat += "<area shape='rect' coords='100,95,120,115' href='byond://?src=[REF(src)];select_zone=l_hand' title='Left hand'>"
	dat += "<area shape='rect' coords='45,115,75,145'  href='byond://?src=[REF(src)];select_zone=r_leg'  title='Right leg'>"
	dat += "<area shape='rect' coords='80,115,110,145' href='byond://?src=[REF(src)];select_zone=l_leg'  title='Left leg'>"
	dat += "<area shape='rect' coords='45,145,75,160'  href='byond://?src=[REF(src)];select_zone=r_foot' title='Right foot'>"
	dat += "<area shape='rect' coords='80,145,110,160' href='byond://?src=[REF(src)];select_zone=l_foot' title='Left foot'>"
	dat += "</map>"
	dat += "<div style='margin-top:6px;color:#aac;font-size:0.85em;'>Zone: <b>[selected_zone ? selected_zone : "none"]</b></div>"
	if(selected_tool)
		dat += "<div style='margin-top:6px;color:#9c9;font-size:0.9em;'><b>[html_encode(selected_tool.name)]</b></div>"
		dat += "<div style='color:#777;font-size:0.8em;'>Click a zone to operate</div>"
	else
		dat += "<div style='margin-top:6px;color:#666;font-size:0.85em;'>Select a tool first</div>"
	dat += next_step_html
	dat += "</td>"

	dat += "</tr></table>"

	var/datum/browser/B = new /datum/browser(user, "surgical_tray_ui", "Surgical Tray UI", 620, 470)
	B.set_content(dat)
	B.open()

/obj/item/storage/surgical_tray/Topic(href, list/href_list)
	. = ..()
	if(.)
		return
	if(!ishuman(usr))
		return
	var/mob/living/carbon/human/user = usr
	if(href_list["select_tool"])
		var/obj/item/tool = locate(href_list["select_tool"])
		if(tool && tool.loc == src)
			selected_tool = tool
		else
			selected_tool = null
		open_tray_ui(user)
	else if(href_list["select_zone"])
		var/static/list/valid_zones = list(
			BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM,
			BODY_ZONE_L_LEG, BODY_ZONE_R_LEG, BODY_ZONE_PRECISE_GROIN,
			BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND,
			BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_R_FOOT,
			BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH,
		)
		var/zone = href_list["select_zone"]
		if(!(zone in valid_zones))
			return
		selected_zone = zone
		open_tray_ui(user) // show zone highlight immediately before surgery begins

		// If a tool is selected and the patient is still operable, perform surgery on the chosen zone.
		// We temporarily move the tool into user.contents so do_surgery's fail_step branch fires
		// correctly (it checks `tool in user.contents`). We suppress our Exited handler during this.
		if(!QDELETED(selected_tool) && selected_tool.loc == src && \
		   !QDELETED(current_patient) && current_patient.can_be_operated_on() && \
		   iscarbon(current_patient) && user.Adjacent(current_patient))
			var/obj/item/tool = selected_tool
			user.zone_selected = selected_zone
			var/old_toggles = user.client?.prefs?.toggles_gameplay
			if(user.client?.prefs)
				user.client.prefs.toggles_gameplay &= ~RADIAL_MEDICAL
			surgery_in_progress = TRUE
			tool.forceMove(user) // puts tool in user.contents so fail_step fires on failure
			do_surgery(current_patient, user, tool)
			// Return tool to tray if it wasn't consumed by the surgery step
			if(!QDELETED(tool) && tool.loc == user)
				tool.forceMove(src)
			surgery_in_progress = FALSE
			if(user.client?.prefs && !isnull(old_toggles))
				user.client.prefs.toggles_gameplay = old_toggles
				// Update selected_tool: clear it if the tool was consumed, keep it if returned
			if(QDELETED(tool) || tool.loc != src)
				selected_tool = null
			open_tray_ui(user) // refresh after surgery completes
