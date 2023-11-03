#define SPLURT_MAX_AUTOPLAPPERS 3

/// Attempts to open the tgui menu
/mob/verb/interact_with()
	set name = "Interact With"
	set desc = "Perform an interaction with someone."
	set category = "IC"
	set src in view(usr.client)

	var/datum/component/interaction_menu_granter/menu = usr.GetComponent(/datum/component/interaction_menu_granter)
	if(!menu)
		usr.AddComponent(/datum/component/interaction_menu_granter)
		menu = usr.GetComponent(/datum/component/interaction_menu_granter)
	if(!menu)
		to_chat(usr, span_warning("Shits broken!."))
		return

	if(!src)
		to_chat(usr, span_warning("Your interaction target is gone!"))
		return
	menu.open_menu(usr, src)

#define INTERACTION_NORMAL 0
#define INTERACTION_LEWD 1
#define INTERACTION_EXTREME 2
#define INTERACTION_CONSENT 3

/// The menu itself, only var is target which is the mob you are interacting with
/datum/component/interaction_menu_granter
	var/datum/weakref/weaktarget
	// var/mob/living/target
	/// weakrefs to mobs we are doing cool things with
	var/list/splurting_with = list()
	/// our active automatic plappers
	var/list/autoplappers = list()

/datum/component/interaction_menu_granter/Initialize(...)
	if(!ismob(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/parent_mob = parent
	if(!parent_mob.client)
		return COMPONENT_INCOMPATIBLE
	. = ..()

/datum/component/interaction_menu_granter/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_CLICK_CTRL_SHIFT, .proc/open_menu)

/datum/component/interaction_menu_granter/Destroy(force, ...)
	weaktarget = null
	QDEL_LIST(autoplappers)
	. = ..()

/datum/component/interaction_menu_granter/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_CLICK_CTRL_SHIFT, COMSIG_SPLURT_REQUEST))
	. = ..()

/// The one interacting is clicker, the interacted is clicked.
/datum/component/interaction_menu_granter/proc/open_menu(mob/clicker, mob/clicked)

	// COMSIG_CLICK_CTRL_SHIFT accepts `atom`s, prevent it
	if(!istype(clicked))
		return FALSE
	// Don't cancel admin quick spawn
	if(isobserver(clicked) && check_rights_for(clicker.client, R_SPAWN))
		return FALSE
	weaktarget = WEAKREF(clicked)
	ui_interact(clicker)
	return COMSIG_MOB_CANCEL_CLICKON

/datum/component/interaction_menu_granter/ui_state(mob/user)
	// Funny admin, don't you dare be the extra funny now.
	if(user.client.holder && !user.client.holder.deadmined)
		return GLOB.always_state
	if(user == parent)
		return GLOB.conscious_state
	return GLOB.never_state

/datum/component/interaction_menu_granter/ui_interact(mob/user, datum/tgui/ui)
	if(!user.CheckActionCooldown(0.8 SECONDS))
		return // sex is combat, didnt ya know?
	user.DelayNextAction(0.8 SECONDS) // mainly cus spamming the buttons will lock up your client with sex messages

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MobInteraction", "Interactions")
		ui.open()

/proc/pref_to_num(pref)
	switch(pref)
		if("Yes")
			return 1
		if("Ask")
			return 2
		else
			return 0

/datum/component/interaction_menu_granter/ui_data(mob/user)
	. = ..()
	//Getting player
	var/mob/living/self = parent
	var/mob/living/target = GET_WEAKREF(weaktarget)
	if(!target)
		return
	//Getting info
	.["isTargetSelf"] = target == self
	.["interactingWith"] = target != self ? "Interacting with \the [target]..." : "Interacting with yourself..."
	.["selfAttributes"] = self.list_interaction_attributes(self)
	.["lust"] = self.get_lust()
	.["maxLust"] = self.get_lust_tolerance() * 3
	if(target != self)
		.["theirAttributes"] = target.list_interaction_attributes(self)
		if(HAS_TRAIT(user, TRAIT_IN_HEAT))
			.["theirLust"] = target.get_lust()
			.["theirMaxLust"] = target.get_lust_tolerance() * 3

	//Getting interactions
	var/list/sent_interactions = list()
	for(var/interaction_key in SSinteractions.interactions)
		var/datum/interaction/I = SSinteractions.interactions[interaction_key]
		if(!I.evaluate_user(self, silent = TRUE, action_check = FALSE) || !I.evaluate_target(self, target, silent = TRUE))
			continue
		if(I.user_is_target && target != self)
			continue
		var/list/interaction = list()
		interaction["key"] = I.type
		var/description = replacetext(I.description, "%COCK%", self.has_penis() ? "cock" : "strapon")
		interaction["desc"] = description
		if(istype(I, /datum/interaction/lewd))
			var/datum/interaction/lewd/O = I
			if(O.extreme)
				interaction["type"] = INTERACTION_EXTREME
			else
				interaction["type"] = INTERACTION_LEWD
		else
			interaction["type"] = INTERACTION_NORMAL
		interaction["additionalDetails"] = I.additional_details
		sent_interactions += list(interaction)
	.["interactions"] = sent_interactions
	.["autoplappers"] = package_autoplappers()
/* 
	//Get their genitals
	var/list/genitals = list()
	var/mob/living/carbon/get_genitals = self
	if(istype(get_genitals))
		for(var/obj/item/organ/genital/genital in get_genitals.internal_organs)	//Only get the genitals
			if(CHECK_BITFIELD(genital.genital_flags, GENITAL_INTERNAL))			//Not those though
				continue
			var/list/genital_entry = list()
			genital_entry["name"] = "[capitalize(genital.name)]" //Prevents code from adding a prefix
			genital_entry["key"] = REF(genital) //The key is the reference to the object
			var/visibility = "Invalid"
			if(CHECK_BITFIELD(genital.genital_visflags , GEN_VISIBLE_ALWAYS))
				visibility = "Always visible"
			else if(CHECK_BITFIELD(genital.genital_visflags , GEN_VISIBLE_NO_UNDIES))
				visibility = "Hidden by underwear"
			else if(CHECK_BITFIELD(genital.genital_visflags , GEN_VISIBLE_NEVER))
				visibility = "Always hidden"
			else
				visibility = "Hidden by clothes"
			genital_entry["visibility"] = visibility
			genital_entry["possible_choices"] = GLOB.genitals_visibility_toggles
			genital_entry["can_arouse"] = (
				!!CHECK_BITFIELD(genital.genital_flags, GENITAL_CAN_AROUSE) \
				&& !(HAS_TRAIT(get_genitals, TRAIT_PERMABONER) \
				|| HAS_TRAIT(get_genitals, TRAIT_NEVERBONER)))
			genital_entry["arousal_state"] = genital.aroused_state
			genital_entry["always_accessible"] = genital.always_accessible
			genitals += list(genital_entry)
		if(!get_genitals.getorganslot(ORGAN_SLOT_ANUS)) //SPLURT Edit
			var/simulated_ass = list()
			simulated_ass["name"] = "Anus"
			simulated_ass["key"] = "anus"
			var/visibility = "Invalid"
			switch(get_genitals.anus_exposed)
				if(1)
					visibility = "Always visible"
				if(0)
					visibility = "Hidden by underwear"
				else
					visibility = "Always hidden"
			simulated_ass["visibility"] = visibility
			simulated_ass["possible_choices"] = GLOB.genitals_visibility_toggles - GEN_VISIBLE_NO_CLOTHES
			simulated_ass["always_accessible"] = get_genitals.anus_always_accessible
			genitals += list(simulated_ass)
	.["genitals"] = genitals
*/
	var/datum/preferences/prefs = self?.client.prefs
	if(prefs)
	//Getting char prefs
		.["erp_pref"] = 			pref_to_num(prefs.erppref)
		.["noncon_pref"] = 			pref_to_num(prefs.nonconpref)
		.["vore_pref"] = 			pref_to_num(prefs.vorepref)
		.["extreme_pref"] = 		pref_to_num(prefs.extremepref)
		.["extreme_harm"] = 		pref_to_num(prefs.extremeharm)
		.["unholy_pref"] =		pref_to_num(prefs.unholypref)

	//Getting preferences
		.["verb_consent"] = 		!!CHECK_BITFIELD(prefs.toggles, VERB_CONSENT)
		.["lewd_verb_sounds"] = 	!CHECK_BITFIELD(prefs.toggles, NO_LEWD_VERB_SOUNDS)
		.["arousable"] = 			prefs.arousable
		.["genital_examine"] = 		!!CHECK_BITFIELD(prefs.cit_toggles, GENITAL_EXAMINE)
		.["forced_fem"] = 			!!CHECK_BITFIELD(prefs.cit_toggles, FORCED_FEM)
		.["forced_masc"] = 			!!CHECK_BITFIELD(prefs.cit_toggles, FORCED_MASC)
		.["hypno"] = 				!!CHECK_BITFIELD(prefs.cit_toggles, HYPNO)
		.["bimbofication"] = 		!!CHECK_BITFIELD(prefs.cit_toggles, BIMBOFICATION)
		.["breast_enlargement"] = 	!!CHECK_BITFIELD(prefs.cit_toggles, BREAST_ENLARGEMENT)
		.["penis_enlargement"] =	!!CHECK_BITFIELD(prefs.cit_toggles, PENIS_ENLARGEMENT)
		.["butt_enlargement"] =		!!CHECK_BITFIELD(prefs.cit_toggles, BUTT_ENLARGEMENT)
		.["belly_inflation"] = 		!!CHECK_BITFIELD(prefs.cit_toggles, BELLY_INFLATION)
		.["never_hypno"] = 			!CHECK_BITFIELD(prefs.cit_toggles, NEVER_HYPNO)
		.["no_aphro"] = 			!CHECK_BITFIELD(prefs.cit_toggles, NO_APHRO)
		.["no_ass_slap"] = 		!CHECK_BITFIELD(prefs.cit_toggles, NO_ASS_SLAP)
		.["no_auto_wag"] = 		!CHECK_BITFIELD(prefs.cit_toggles, NO_AUTO_WAG)
		.["chastity_pref"] = 		!!CHECK_BITFIELD(prefs.cit_toggles, CHASTITY)
		.["stimulation_pref"] = 	!!CHECK_BITFIELD(prefs.cit_toggles, STIMULATION)
		.["edging_pref"] =			!!CHECK_BITFIELD(prefs.cit_toggles, EDGING)
		.["cum_onto_pref"] = 		!!CHECK_BITFIELD(prefs.cit_toggles, CUM_ONTO)
		//Vore preferences
		.["vore_toggle"] = 			prefs.master_vore_toggle
		.["vore_examine"] = 		prefs.allow_vore_messages
		.["eating_noises"] = 		prefs.allow_eating_sounds
		.["digestion_noises"] =		prefs.allow_digestion_sounds
		.["trash_forcefeed"] = 		prefs.allow_trash_messages

/proc/num_to_pref(num)
	switch(num)
		if(1)
			return "Yes"
		if(2)
			return "Ask"
		else
			return "No"

/datum/component/interaction_menu_granter/ui_act(action, params)
	if(..())
		return
	var/mob/living/parent_mob = parent
	switch(action)
		if("interact")
			if(!isliving(parent_mob))
				return
			var/datum/interaction/o = SSinteractions.interactions[params["interaction"]]
			if(o)
				var/mob/living/target = GET_WEAKREF(weaktarget)
				if(!target)
					return
				o.run_action(parent_mob, target)
				return TRUE
			return FALSE
		/* todo: make this work : ^ )
		if("genital")
			var/mob/living/carbon/self = parent_mob
			if("visibility" in params)
				if(params["genital"] == "anus")
					self.anus_toggle_visibility(params["visibility"])
					return TRUE
				var/obj/item/organ/genital/genital = locate(params["genital"], self.internal_organs)
				if(genital && (genital in self.internal_organs))
					genital.toggle_visibility(params["visibility"])
					return TRUE
			if("set_arousal" in params)
				var/obj/item/organ/genital/genital = locate(params["genital"], self.internal_organs)
				if(!genital || (genital \
					&& (!CHECK_BITFIELD(genital.genital_flags, GENITAL_CAN_AROUSE) \
					|| HAS_TRAIT(self, TRAIT_PERMABONER) \
					|| HAS_TRAIT(self, TRAIT_NEVERBONER))))
					return FALSE
				var/original_state = genital.aroused_state
				genital.set_aroused_state(params["set_arousal"])// i'm not making it just `!aroused_state` because
				if(original_state != genital.aroused_state)		// someone just might port skyrat's new genitals
					to_chat(self, span_userlove("[genital.aroused_state ? genital.arousal_verb : genital.unarousal_verb]."))
					. = TRUE
				else
					to_chat(self, span_userlove("You can't make that genital [genital.aroused_state ? "unaroused" : "aroused"]!"))
					. = FALSE
				genital.update_appearance()
				if(ishuman(self))
					var/mob/living/carbon/human/human = self
					human.update_genitals()
				return
			if("set_accessibility" in params)
				if(!self.getorganslot(ORGAN_SLOT_ANUS) && params["genital"] == "anus")
					self.toggle_anus_always_accessible()
					return TRUE
				var/obj/item/organ/genital/genital = locate(params["genital"], self.internal_organs)
				if(!genital)
					return FALSE
				genital.toggle_accessibility()
				return TRUE
			else
				return FALSE
			*/
		if("char_pref")
			var/datum/preferences/prefs = parent_mob.client.prefs
			var/value = num_to_pref(params["value"])
			switch(params["char_pref"])
				if("erp_pref")
					if(prefs.erppref == value)
						return FALSE
					else
						prefs.erppref = value
				if("noncon_pref")
					if(prefs.nonconpref == value)
						return FALSE
					else
						prefs.nonconpref = value
				if("vore_pref")
					if(prefs.vorepref == value)
						return FALSE
					else
						prefs.vorepref = value
				if("unholy_pref")
					if(prefs.unholypref == value)
						return FALSE
					else
						prefs.unholypref = value
				if("extreme_pref")
					if(prefs.extremepref == value)
						return FALSE
					else
						prefs.extremepref = value
						if(prefs.extremepref == "No")
							prefs.extremeharm = "No"
				if("extreme_harm")
					if(prefs.extremeharm == value)
						return FALSE
					else
						prefs.extremeharm = value
				else
					return FALSE
			prefs.save_character()
			return TRUE
		if("pref")
			var/datum/preferences/prefs = parent_mob.client.prefs
			switch(params["pref"])
				if("verb_consent")
					TOGGLE_BITFIELD(prefs.toggles, VERB_CONSENT)
				if("lewd_verb_sounds")
					TOGGLE_BITFIELD(prefs.toggles, NO_LEWD_VERB_SOUNDS)
				if("arousable")
					prefs.arousable = !prefs.arousable
				if("genital_examine")
					TOGGLE_BITFIELD(prefs.cit_toggles, GENITAL_EXAMINE)
				if("forced_fem")
					TOGGLE_BITFIELD(prefs.cit_toggles, FORCED_FEM)
				if("forced_masc")
					TOGGLE_BITFIELD(prefs.cit_toggles, FORCED_MASC)
				if("hypno")
					TOGGLE_BITFIELD(prefs.cit_toggles, HYPNO)
				if("bimbofication")
					TOGGLE_BITFIELD(prefs.cit_toggles, BIMBOFICATION)
				if("breast_enlargement")
					TOGGLE_BITFIELD(prefs.cit_toggles, BREAST_ENLARGEMENT)
				if("penis_enlargement")
					TOGGLE_BITFIELD(prefs.cit_toggles, PENIS_ENLARGEMENT)
				if("butt_enlargement")
					TOGGLE_BITFIELD(prefs.cit_toggles, BUTT_ENLARGEMENT)
				if("belly_inflation")
					TOGGLE_BITFIELD(prefs.cit_toggles, BELLY_INFLATION)
				if("never_hypno")
					TOGGLE_BITFIELD(prefs.cit_toggles, NEVER_HYPNO)
				if("no_aphro")
					TOGGLE_BITFIELD(prefs.cit_toggles, NO_APHRO)
				if("no_ass_slap")
					TOGGLE_BITFIELD(prefs.cit_toggles, NO_ASS_SLAP)
				if("no_auto_wag")
					TOGGLE_BITFIELD(prefs.cit_toggles, NO_AUTO_WAG)
				if("chastity_pref")
					TOGGLE_BITFIELD(prefs.cit_toggles, CHASTITY)
				if("stimulation_pref")
					TOGGLE_BITFIELD(prefs.cit_toggles, STIMULATION)
				if("edging_pref")
					TOGGLE_BITFIELD(prefs.cit_toggles, EDGING)
				if("cum_onto_pref")
					TOGGLE_BITFIELD(prefs.cit_toggles, CUM_ONTO)
				if("vore_toggle")
					prefs.master_vore_toggle = !prefs.master_vore_toggle
				if("vore_examine")
					TOGGLE_BITFIELD(prefs.cit_toggles, VOREALLOW_SEEING_BELLY_DESC)
				if("eating_noises")
					TOGGLE_BITFIELD(prefs.cit_toggles, EATING_NOISES)
				if("digestion_noises")
					prefs.allow_digestion_sounds = !prefs.allow_digestion_sounds
				if("trash_forcefeed")
					prefs.allow_trash_messages = !prefs.allow_trash_messages
				else
					return FALSE
			//Todo: Just save when the player closes the menu or switches tabs when there are unsaved changes.
			//Also add a save button.
			prefs.save_preferences()
			return TRUE
		if("autoplapper")
			if(params["action"] == "add")
				new_autoplap(params["plapname"], GET_WEAKREF(weaktarget), params["interval"])
			if(params["action"] == "remove")
				remove_autoplap(params["apid"])
			if(params["action"] == "toggle")
				var/datum/autoplapper/AP = autoplappers[params["apid"]]
				if(!AP)
					return FALSE
				AP.toggle_plapping()
			if(params["action"] == "change_interval")
				var/datum/autoplapper/AP = autoplappers[params["apid"]]
				if(!AP)
					return FALSE
				AP.change_interval(params["interval"])
			if(params["action"] == "save_plap_to_prefs")
				var/datum/autoplapper/AP = autoplappers[params["apid"]]
				if(!AP)
					return FALSE
				AP.save_plap_to_prefs()
			return TRUE


//////// AUTOPLAPPER STUFF
/datum/component/interaction_menu_granter/proc/new_autoplap(key, mob/living/partner, interval)
	if(!isliving(partner) || !key)
		to_chat(parent, span_alert("That didnt work!!!"))
		return
	if(LAZYLEN(autoplappers) >= SPLURT_MAX_AUTOPLAPPERS)
		to_chat(parent, span_alert("You have too many autointeractions to add another one!"))
		return
	var/datum/interaction/I = LAZYACCESS(SSinteractions.interactions, key)
	if(!I)
		to_chat(parent, span_alert("That didnt work!!!"))
		return
	if(!I.can_autoplap)
		to_chat(parent, span_alert("That one really shouldnt be automated!"))
		return
	if(!I.can_do_interaction(parent, partner))
		return
	var/mob/living/me = parent
	var/mob/living/them = partner
	var/datum/autoplapper/AP = new(me, them, I, interval)
	autoplappers[AP.apid] = AP
	if(!interval) // it'll 
		I.run_action(me, them) // plap to get things started

/datum/component/interaction_menu_granter/proc/remove_autoplap(apid)
	var/datum/autoplapper/AP = autoplappers[apid]
	if(!AP)
		return
	AP.stop_plapping()
	to_chat(parent, span_success("Removed auto-action for [AP.plap_key]!"))
	qdel(AP)
	autoplappers -= AP

/datum/component/interaction_menu_granter/proc/package_autoplappers()
	var/list/ret = list()
	for(var/autoplapper/AP in autoplappers)
		var/list/entry = list()
		entry["apid"] = AP.apid || "!!!"
		entry["plapname"] = AP.plap_key || "???"
		var/mob/living/L = ckey2mob(AP.plappee)
		entry["partner"] = L?.name || "Your Mom"
		entry["interval"] = AP.interval || 0
		entry["plapping"] = AP.plapping || FALSE
		entry["plapcount"] = AP.plapcount || 0
		ret += list(entry)
	return ret



#undef INTERACTION_NORMAL
#undef INTERACTION_LEWD
#undef INTERACTION_EXTREME
#undef INTERACTION_CONSENT
#undef SPLURT_MAX_AUTOPLAPPERS
