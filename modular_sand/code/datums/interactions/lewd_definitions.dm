
/*--------------------------------------------------
-------------------MOB STUFF----------------------
--------------------------------------------------
*/
//I'm sorry, lewd should not have mob procs such as life() and such in it. //NO SHIT IT SHOULDNT I REMOVED THEM

/proc/playlewdinteractionsound(turf/turf_source, soundin, vol as num, vary, extrarange as num, frequency, falloff, channel = 0, pressure_affected = TRUE, sound/S, envwet = -10000, envdry = 0, manual_x, manual_y, list/ignored_mobs)
	var/list/hearing_mobs
	for(var/mob/H in get_hearers_in_view(4, turf_source))
		if(!H.client || (H.client.prefs.toggles & NO_LEWD_VERB_SOUNDS))
			continue
		LAZYADD(hearing_mobs, H)
	if(ignored_mobs?.len)
		LAZYREMOVE(hearing_mobs, ignored_mobs)
	for(var/mob/H in hearing_mobs)
		H.playsound_local(turf_source, soundin, vol, vary, frequency, falloff)

/mob/living
	var/has_penis = FALSE
	var/has_balls = FALSE
	var/has_vagina = FALSE
	var/has_anus = TRUE
	var/has_butt = FALSE
	var/anus_always_accessible = FALSE
	var/has_breasts = FALSE
	var/anus_exposed = FALSE
	var/last_partner
	var/last_orifice
	var/obj/item/organ/last_genital
	var/lastmoan
	var/sexual_potency = 15
	var/lust_tolerance = 100
	var/lastlusttime = 0
	var/lust = 0
	var/multiorgasms = 1
	/// if set, the next sex-type action will make u cum
	var/ready_to_cum = FALSE // ARE YOU READY?
	COOLDOWN_DECLARE(refractory_period)
	COOLDOWN_DECLARE(interaction_cooldown)
	/// Sounds can only play so often
	COOLDOWN_DECLARE(interaction_sound_cooldown)
	/// You can still do an interaction but if it's a duplicate one within this time there's no message
	COOLDOWN_DECLARE(interaction_message_cooldown)
	/// Believe it or not these are annoying
	COOLDOWN_DECLARE(interaction_moan_cooldown)
	var/datum/interaction/lewd/last_lewd_datum	//Recording our last lewd datum allows us to do stuff like custom cum messages.
												//Yes i feel like an idiot writing this.
	var/cleartimer //Timer for clearing the "last_lewd_datum". This prevents some oddities.

/mob/living/proc/clear_lewd_datum()
	last_partner = null
	last_orifice = null
	last_genital = null
	last_lewd_datum = null

/mob/living/Initialize(mapload)
	. = ..()
	sexual_potency = rand(10,25)
	lust_tolerance = rand(75,200)

/mob/living/proc/get_lust_tolerance()
	. = lust_tolerance
	if(has_dna())
		var/mob/living/carbon/user = src
		if(user.dna.features["lust_tolerance"])
			. = user.dna.features["lust_tolerance"]

/mob/living/proc/get_sexual_potency()
	. = sexual_potency
	if(has_dna())
		var/mob/living/carbon/user = src
		if(user.dna.features["sexual_potency"])
			. = user.dna.features["sexual_potency"]

/mob/living/proc/add_lust(add)
	var/cur = get_lust() //GetLust handles per-time lust loss
	if((cur + add) < 0) //in case we retract lust
		lust = 0
	else
		lust = cur + add


/mob/living/proc/get_lust()
	var/curtime = world.time
	var/dif = (curtime - lastlusttime) / 10 //how much lust would we lose over time
	if((lust - dif) < 0)
		lust = 0
	else
		lust = lust - dif

	lastlusttime = world.time
	return lust

/mob/living/proc/set_lust(num)
	lust = num
	lastlusttime = world.time

/mob/living/proc/toggle_anus_always_accessible(accessibility)
	anus_always_accessible = isnull(accessibility) ? !anus_always_accessible : accessibility

/**
  * Returns the fluid modifier if the genital has one.
  *
  * Arguments:
  * * amount: Amount of fluid to be released.
  * * genital: Genital to check for any fluid modifiers.
*/
/mob/living/proc/get_fluid_mod(obj/item/organ/genital/G)
	if(CHECK_BITFIELD(G?.genital_flags, GENITAL_DISAPPOINTING))
		return 0.5
	return 1

/mob/living/proc/has_genital(slot, visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(istype(C))
		var/obj/item/organ/genital/genital = C.getorganslot(slot)
		if(genital)
			switch(visibility)
				if(REQUIRE_ANY)
					return TRUE
				if(REQUIRE_EXPOSED)
					return genital.is_exposed() || genital.always_accessible
				if(REQUIRE_UNEXPOSED)
					return !genital.is_exposed()
				else
					return TRUE
	return FALSE

/mob/living/proc/has_penis(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(has_penis && !istype(C))
		return TRUE
	return has_genital(ORGAN_SLOT_PENIS, visibility)

/mob/living/proc/has_strapon(visibility = REQUIRE_ANY)
	if(get_strapon())
		return TRUE
	/* If someone wants to make visibility checks later be my guest
	var/mob/living/carbon/C = src
	if(istype(C))
		var/obj/item/clothing/underwear/briefs/strapon/strapon = C.get_strapon()
		if(strapon)
			switch(visibility)
				if(REQUIRE_ANY)
					return TRUE
				if(REQUIRE_EXPOSED)
					return strapon.is_exposed()
				if(REQUIRE_UNEXPOSED)
					return !strapon.is_exposed()
				else
					return TRUE
	return FALSE
	*/

/mob/living/proc/get_strapon()
	for(var/obj/item/clothing/cloth in get_equipped_items())
		if(istype(cloth, /obj/item/clothing/underwear/briefs/strapon))
			return cloth
	return null

/mob/living/proc/can_penetrating_genital_cum()
	return has_penis()

/mob/living/proc/get_penetrating_genital_name(long = FALSE)
	return has_penis() ? (long ? pick(GLOB.dick_nouns) : pick("cock", "dick")) : pick("strapon")

/mob/living/proc/has_balls(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(has_balls && !istype(C))
		return TRUE
	return has_genital(ORGAN_SLOT_TESTICLES, visibility)

/mob/living/proc/has_vagina(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(has_vagina && !istype(C))
		return TRUE
	return has_genital(ORGAN_SLOT_VAGINA, visibility)

/mob/living/proc/has_breasts(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(has_breasts && !istype(C))
		return TRUE
	return has_genital(ORGAN_SLOT_BREASTS, visibility)

/mob/living/proc/has_anus(visibility = REQUIRE_ANY)
	if(has_anus && !iscarbon(src))
		return TRUE
	switch(visibility)
		if(REQUIRE_ANY)
			return TRUE
		if(REQUIRE_EXPOSED)
			if (has_anus && anus_always_accessible)
				return TRUE
			switch(anus_exposed)
				if(-1)
					return FALSE
				if(1)
					return TRUE
				else
					if(is_bottomless())
						return TRUE
					else
						return FALSE
		if(REQUIRE_UNEXPOSED)
			if(anus_exposed == -1)
				if(!anus_exposed)
					if(!is_bottomless())
						return TRUE
					else
						return FALSE
				else
					return FALSE
			else
				return TRUE
		else
			return TRUE

/mob/living/proc/has_hand(visibility = REQUIRE_ANY)
	if(iscarbon(src))
		var/mob/living/carbon/C = src
		var/handcount = 0
		var/covered = 0
		var/iscovered = FALSE
		for(var/obj/item/bodypart/l_arm/L in C.bodyparts)
			handcount++
		for(var/obj/item/bodypart/r_arm/R in C.bodyparts)
			handcount++
		if(C.get_item_by_slot(SLOT_HANDS))
			var/obj/item/clothing/gloves/G = C.get_item_by_slot(SLOT_HANDS)
			covered = G.body_parts_covered
		if(covered & HANDS)
			iscovered = TRUE
		switch(visibility)
			if(REQUIRE_ANY)
				return handcount
			if(REQUIRE_EXPOSED)
				if(iscovered)
					return FALSE
				else
					return handcount
			if(REQUIRE_UNEXPOSED)
				if(!iscovered)
					return FALSE
				else
					return handcount
			else
				return handcount
	return FALSE

/mob/living/proc/has_feet(visibility = REQUIRE_ANY)
	if(iscarbon(src))
		var/mob/living/carbon/C = src
		var/feetcount = 0
		var/covered = 0
		var/iscovered = FALSE
		for(var/obj/item/bodypart/l_leg/L in C.bodyparts)
			feetcount++
		for(var/obj/item/bodypart/r_leg/R in C.bodyparts)
			feetcount++
		if(!C.is_barefoot())
			covered = TRUE
		if(covered)
			iscovered = TRUE
		switch(visibility)
			if(REQUIRE_ANY)
				return feetcount
			if(REQUIRE_EXPOSED)
				if(iscovered)
					return FALSE
				else
					return feetcount
			if(REQUIRE_UNEXPOSED)
				if(!iscovered)
					return FALSE
				else
					return feetcount
			else
				return feetcount
	return FALSE

/mob/living/proc/get_num_feet()
	return has_feet(REQUIRE_ANY)

//weird procs go here
/mob/living/proc/has_ears(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(istype(C))
		var/obj/item/organ/peepee = C.getorganslot(ORGAN_SLOT_EARS)
		if(peepee)
			switch(visibility)
				if(REQUIRE_ANY)
					return TRUE
				if(REQUIRE_EXPOSED)
					//if(C.get_item_by_slot(SLOT_EARS_LEFT) || C.get_item_by_slot(SLOT_EARS_RIGHT))
					if(C.get_item_by_slot(SLOT_EARS))
						return FALSE
					else
						return TRUE
				if(REQUIRE_UNEXPOSED)
					//if(!C.get_item_by_slot(SLOT_EARS_LEFT || C.get_item_by_slot(SLOT_EARS_RIGHT)))
					if(C.get_item_by_slot(SLOT_EARS))
						return FALSE
					else
						return TRUE
				else
					return TRUE
	return FALSE

/mob/living/proc/has_earsockets(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(istype(C))
		var/obj/item/organ/peepee = C.getorganslot(ORGAN_SLOT_EARS)
		if(!peepee)
			switch(visibility)
				if(REQUIRE_ANY)
					return TRUE
				if(REQUIRE_EXPOSED)
					//if(C.get_item_by_slot(SLOT_EARS_LEFT) || C.get_item_by_slot(SLOT_EARS_RIGHT))
					if(C.get_item_by_slot(SLOT_EARS))
						return FALSE
					else
						return TRUE
				if(REQUIRE_UNEXPOSED)
					//if(!C.get_item_by_slot(SLOT_EARS_LEFT) || !C.get_item_by_slot(SLOT_EARS_RIGHT))
					if(C.get_item_by_slot(SLOT_EARS))
						return FALSE
					else
						return TRUE
				else
					return TRUE
	return FALSE

/mob/living/proc/has_eyes(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(istype(C))
		var/obj/item/organ/peepee = C.getorganslot(ORGAN_SLOT_EYES)
		if(peepee)
			switch(visibility)
				if(REQUIRE_ANY)
					return TRUE
				if(REQUIRE_EXPOSED)
					if(C.get_item_by_slot(SLOT_GLASSES))
						return FALSE
					else
						return TRUE
				if(REQUIRE_UNEXPOSED)
					if(!C.get_item_by_slot(SLOT_GLASSES))
						return FALSE
					else
						return TRUE
				else
					return TRUE
	return FALSE

/mob/living/proc/has_eyesockets(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(istype(C))
		var/obj/item/organ/peepee = C.getorganslot(ORGAN_SLOT_EYES)
		if(!peepee)
			switch(visibility)
				if(REQUIRE_ANY)
					return TRUE
				if(REQUIRE_EXPOSED)
					if(get_item_by_slot(SLOT_GLASSES))
						return FALSE
					else
						return TRUE
				if(REQUIRE_UNEXPOSED)
					if(!get_item_by_slot(SLOT_GLASSES))
						return FALSE
					else
						return TRUE
				else
					return TRUE
	return FALSE

/mob/living/proc/has_butt(visibility = REQUIRE_ANY)
	var/mob/living/carbon/C = src
	if(has_butt && !istype(C))
		return TRUE
	return has_genital(ORGAN_SLOT_BUTT, visibility)

///Are we wearing something that covers our chest?
/mob/living/proc/is_topless()
	for(var/slot in GLOB.slots)
		var/item_slot = GLOB.slot2slot[slot]
		if(!item_slot) // Safety
			continue
		var/obj/item/clothing = get_item_by_slot(item_slot)
		if(!clothing) // Don't have this slot or not wearing anything in it
			continue
		if(clothing.body_parts_covered & CHEST)
			return FALSE
	// If didn't stop before, then we're topless
	return TRUE

///Are we wearing something that covers our groin?
/mob/living/proc/is_bottomless()
	for(var/slot in GLOB.slots)
		var/item_slot = GLOB.slot2slot[slot]
		if(!item_slot) // Safety
			continue
		var/obj/item/clothing = get_item_by_slot(item_slot)
		if(!clothing) // Don't have this slot or not wearing anything in it
			continue
		if(clothing.body_parts_covered & GROIN)
			return FALSE
	// If didn't stop before, then we're bottomless
	return TRUE

///Are we wearing something that covers our shoes?
/mob/living/proc/is_barefoot()
	for(var/slot in GLOB.slots)
		var/item_slot = GLOB.slot2slot[slot]
		if(!item_slot) // Safety
			continue
		var/obj/item/clothing = get_item_by_slot(item_slot)
		if(!clothing) // Don't have this slot or not wearing anything in it
			continue
		if(clothing.body_parts_covered & FEET)
			return FALSE
	// If didn't stop before, then we're barefoot
	return TRUE

/mob/living/proc/moan()
	if(!(prob(get_lust() / get_lust_tolerance() * 50)))
		return
	if(COOLDOWN_FINISHED(src, interaction_moan_cooldown))
		COOLDOWN_START(src, interaction_moan_cooldown, LEWD_VERB_MOAN_COOLDOWN)
		var/moan = rand(1, 7)
		if(moan == lastmoan)
			moan--
		if(!is_muzzled())
			visible_message(message = span_love("<B>\The [src]</B> [pick("moans", "moans in pleasure")]."), ignored_mobs = get_unconsenting())
		else
			audible_message(span_love("<B>[src]</B> [pick("mimes a pleasured moan","moans in silence")]."), ignored_mobs = get_unconsenting())
		lastmoan = moan

/mob/living/proc/cum(mob/living/partner, target_orifice)
	ready_to_cum = FALSE
	if(HAS_TRAIT(src, TRAIT_NEVERBONER))
		return FALSE
	if(SEND_SIGNAL(src, COMSIG_MOB_PRE_CAME, target_orifice, partner))
		return FALSE
	var/message
	var/u_His = p_their()
	var/u_He = p_they()
	var/u_S = p_s()
	var/t_His = partner?.p_their()
	var/cumin = FALSE
	var/partner_carbon_check = FALSE
	var/obj/item/organ/genital/target_gen = null
	var/mob/living/carbon/c_partner = null

	// Do not display to those people as well
	var/list/mob/obscure_to

	//Carbon checks
	if(iscarbon(partner))
		c_partner = partner
		partner_carbon_check = TRUE

	if(src != partner)
		if(ismob(partner))
			if(!last_genital)
				if(has_penis())
					if(!istype(partner))
						target_orifice = null
					switch(target_orifice)
						if(CUM_TARGET_MOUTH)
							if(partner.has_mouth() && partner.mouth_is_free())
								message = "cums right in \the <b>[partner]</b>'s mouth."
								cumin = TRUE
							else
								message = "cums on \the <b>[partner]</b>'s face."
						if(CUM_TARGET_THROAT)
							if(partner.has_mouth() && partner.mouth_is_free())
								message = "shoves deep into \the <b>[partner]</b>'s throat and cums."
								cumin = TRUE
							else
								message = "cums on \the <b>[partner]</b>'s face."
						if(CUM_TARGET_VAGINA)
							if(partner.has_vagina(REQUIRE_EXPOSED))
								if(partner_carbon_check)
									target_gen = c_partner.getorganslot(ORGAN_SLOT_VAGINA)
								message = "cums in \the <b>[partner]</b>'s pussy."
								cumin = TRUE
							else
								message = "cums on \the <b>[partner]</b>'s belly."
						if(CUM_TARGET_ANUS)
							if(partner.has_anus(REQUIRE_EXPOSED))
								message = "cums in \the <b>[partner]</b>'s asshole."
								cumin = TRUE
							else
								message = "cums on \the <b>[partner]</b>'s backside."
						if(CUM_TARGET_HAND)
							if(partner.has_hand(REQUIRE_ANY))
								message = "cums in \the <b>[partner]</b>'s hand."
							else
								message = "cums on \the <b>[partner]</b>."
						if(CUM_TARGET_BREASTS)
							if(partner.has_breasts(REQUIRE_EXPOSED))
								message = "cums onto \the <b>[partner]</b>'s breasts."
							else
								message = "cums on \the <b>[partner]</b>'s chest and neck."
						if(NUTS_TO_FACE)
							if(partner.has_mouth() && partner.mouth_is_free())
								message = "vigorously ruts [u_His] nutsack into \the <b>[partner]</b>'s mouth before shooting [u_His] thick, sticky jizz all over [t_His] eyes and hair."
						if(THIGH_SMOTHERING)
							if(has_penis(REQUIRE_EXPOSED)) //it already checks for the cock before, why the hell would you do this redundant shit
								message = "keeps \the <b>[partner]</b> locked in [u_His] thighs as [u_His] cock throbs, dumping its heavy load all over [t_His] face."
							else
								message = "reaches [u_His] peak, locking [u_His] legs around \the <b>[partner]</b>'s head extra hard as [u_He] cum[u_S] straight onto the head stuck between [u_His] thighs"
							cumin = TRUE
						if(CUM_TARGET_FEET)
							if(!last_lewd_datum.require_target_num_feet)
								if(partner.has_feet())
									message = "cums on \the <b>[partner]</b>'s [partner.has_feet() == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
								else
									message = "cums on the floor!"
							else
								if(partner.has_feet())
									message = "cums on \the <b>[partner]</b>'s [last_lewd_datum.require_target_feet == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
								else
									message = "cums on the floor!"
						//weird shit goes here
						if(CUM_TARGET_EARS)
							if(partner.has_ears())
								message = "cums inside \the <b>[partner]</b>'s ear."
							else
								message = "cums inside \the <b>[partner]</b>'s earsocket."
							cumin = TRUE
						if(CUM_TARGET_EYES)
							if(partner.has_eyes())
								message = "cums on \the <b>[partner]</b>'s eyeball."
							else
								message = "cums inside \the <b>[partner]</b>'s eyesocket."
							cumin = TRUE
						//
						if(CUM_TARGET_PENIS)
							if(partner.has_penis(REQUIRE_EXPOSED))
								message = "cums on \the <b>[partner]</b>."
							else
								message = "cums on the floor!"
						else
							message = "cums on the floor!"
				else if(has_vagina())
					if(!istype(partner))
						target_orifice = null

					switch(target_orifice)
						if(CUM_TARGET_MOUTH)
							if(partner.has_mouth() && partner.mouth_is_free())
								message = "squirts right in \the <b>[partner]</b>'s mouth."
								cumin = TRUE
							else
								message = "squirts on \the <b>[partner]</b>'s face."
						if(CUM_TARGET_THROAT)
							if(partner.has_mouth() && partner.mouth_is_free())
								message = "rubs [u_His] vagina against \the <b>[partner]</b>'s mouth and cums."
								cumin = TRUE
							else
								message = "squirts on \the <b>[partner]</b>'s face."
						if(CUM_TARGET_VAGINA)
							if(partner.has_vagina(REQUIRE_EXPOSED))
								message = "squirts on \the <b>[partner]</b>'s pussy."
								cumin = TRUE
							else
								message = "squirts on \the <b>[partner]</b>'s belly."
						if(CUM_TARGET_ANUS)
							if(partner.has_anus(REQUIRE_EXPOSED))
								message = "squirts on \the <b>[partner]</b>'s asshole."
								cumin = TRUE
							else
								message = "squirts on \the <b>[partner]</b>'s backside."
						if(CUM_TARGET_HAND)
							if(partner.has_hand(REQUIRE_ANY))
								message = "squirts on \the <b>[partner]</b>'s hand."
							else
								message = "squirts on \the <b>[partner]</b>."
						if(CUM_TARGET_BREASTS)
							if(partner.has_breasts(REQUIRE_EXPOSED))
								message = "squirts onto \the <b>[partner]</b>'s breasts."
							else
								message = "squirts on \the <b>[partner]</b>'s chest and neck."
						if(NUTS_TO_FACE)
							if(partner.has_mouth() && partner.mouth_is_free())
								message = "vigorously ruts [u_His] clit into \the <b>[partner]</b>'s mouth before shooting [u_His] femcum all over [t_His] eyes and hair."
						if(THIGH_SMOTHERING)
							message = "keeps \the <b>[partner]</b> locked in [u_His] thighs as [u_He] orgasm[u_S], squirting over [t_His] face."
							cumin = TRUE
						if(CUM_TARGET_FEET)
							if(!last_lewd_datum.require_target_num_feet)
								if(partner.has_feet())
									message = "squirts on \the <b>[partner]</b>'s [partner.has_feet() == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
								else
									message = "squirts on the floor!"
							else
								if(partner.has_feet())
									message = "squirts on \the <b>[partner]</b>'s [last_lewd_datum.require_target_feet == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
								else
									message = "squirts on the floor!"
						//weird shit goes here
						if(CUM_TARGET_EARS)
							if(partner.has_ears())
								message = "squirts on \the <b>[partner]</b>'s ear."
							else
								message = "squirts on \the <b>[partner]</b>'s earsocket."
							cumin = TRUE
						if(CUM_TARGET_EYES)
							if(partner.has_eyes())
								message = "squirts on \the <b>[partner]</b>'s eyeball."
							else
								message = "squirts on \the <b>[partner]</b>'s eyesocket."
							cumin = TRUE
						//
						if(CUM_TARGET_PENIS)
							if(partner.has_penis(REQUIRE_EXPOSED))
								message = "squirts on \the <b>[partner]</b>'s penis"
							else
								message = "squirts on the floor!"
						else
							message = "squirts on the floor!"

				else
					message = pick("orgasms violently!", "twists in orgasm.")
			else
				switch(last_genital.type)
					if(/obj/item/organ/genital/penis)
						if(!istype(partner))
							target_orifice = null

						switch(target_orifice)
							if(CUM_TARGET_MOUTH)
								if(partner.has_mouth() && partner.mouth_is_free())
									message = "cums right in \the <b>[partner]</b>'s mouth."
									cumin = TRUE
								else
									message = "cums on \the <b>[partner]</b>'s face."
							if(CUM_TARGET_THROAT)
								if(partner.has_mouth() && partner.mouth_is_free())
									message = "shoves deep into \the <b>[partner]</b>'s throat and cums."
									cumin = TRUE
								else
									message = "cums on \the <b>[partner]</b>'s face."
							if(CUM_TARGET_VAGINA)
								if(partner.has_vagina(REQUIRE_EXPOSED))
									if(partner_carbon_check)
										target_gen = c_partner.getorganslot(ORGAN_SLOT_VAGINA)
									message = "cums in \the <b>[partner]</b>'s pussy."
									cumin = TRUE
								else
									message = "cums on \the <b>[partner]</b>'s belly."
							if(CUM_TARGET_ANUS)
								if(partner.has_anus(REQUIRE_EXPOSED))
									message = "cums in \the <b>[partner]</b>'s asshole."
									cumin = TRUE
								else
									message = "cums on \the <b>[partner]</b>'s backside."
							if(CUM_TARGET_HAND)
								if(partner.has_hand())
									message = "cums in \the <b>[partner]</b>'s hand."
								else
									message = "cums on \the <b>[partner]</b>."
							if(CUM_TARGET_BREASTS)
								if(partner.is_topless() && partner.has_breasts())
									message = "cums onto \the <b>[partner]</b>'s breasts."
								else
									message = "cums on \the <b>[partner]</b>'s chest and neck."
							if(NUTS_TO_FACE)
								if(partner.has_mouth() && partner.mouth_is_free())
									message = "vigorously ruts [u_His] nutsack into \the <b>[partner]</b>'s mouth before shooting [u_His] thick, sticky jizz all over [t_His] eyes and hair."
							if(THIGH_SMOTHERING)
								if(has_penis()) //it already checks for the cock before, why the hell would you do this redundant shit
									message = "keeps \the <b>[partner]</b> locked in [u_His] thighs as [u_His] cock throbs, dumping its heavy load all over [t_His] face."
								else
									message = "reaches [u_His] peak, locking [u_His] legs around \the <b>[partner]</b>'s head extra hard as [u_He] cum[u_S] straight onto the head stuck between [u_His] thighs"
								cumin = TRUE
							if(CUM_TARGET_FEET)
								if(!last_lewd_datum || !last_lewd_datum.require_target_num_feet)
									if(partner.has_feet())
										message = "cums on \the <b>[partner]</b>'s [partner.has_feet() == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
									else
										message = "cums on the floor!"
								else
									if(partner.has_feet())
										message = "cums on \the <b>[partner]</b>'s [last_lewd_datum.require_target_feet == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
									else
										message = "cums on the floor!"
							//weird shit goes here
							if(CUM_TARGET_EARS)
								if(partner.has_ears())
									message = "cums inside \the <b>[partner]</b>'s ear."
								else
									message = "cums inside \the <b>[partner]</b>'s earsocket."
								cumin = TRUE
							if(CUM_TARGET_EYES)
								if(partner.has_eyes())
									message = "cums on \the <b>[partner]</b>'s eyeball."
								else
									message = "cums inside \the <b>[partner]</b>'s eyesocket."
								cumin = TRUE
							//
							if(CUM_TARGET_PENIS)
								if(partner.has_penis(REQUIRE_EXPOSED))
									message = "cums on \the <b>[partner]</b>."
								else
									message = "cums on the floor!"
							else
								message = "cums on the floor!"
					if(/obj/item/organ/genital/vagina)
						if(!istype(partner))
							target_orifice = null

						switch(target_orifice)
							if(CUM_TARGET_MOUTH)
								if(partner.has_mouth() && partner.mouth_is_free())
									message = "squirts right in \the <b>[partner]</b>'s mouth."
									cumin = TRUE
								else
									message = "squirts on \the <b>[partner]</b>'s face."
							if(CUM_TARGET_THROAT)
								if(partner.has_mouth() && partner.mouth_is_free())
									message = "rubs [u_His] vagina against \the <b>[partner]</b>'s mouth and cums."
									cumin = TRUE
								else
									message = "squirts on \the <b>[partner]</b>'s face."
							if(CUM_TARGET_VAGINA)
								if(partner.has_vagina(REQUIRE_EXPOSED))
									message = "squirts on \the <b>[partner]</b>'s pussy."
									cumin = TRUE
								else
									message = "squirts on \the <b>[partner]</b>'s belly."
							if(CUM_TARGET_ANUS)
								if(partner.has_anus(REQUIRE_EXPOSED))
									message = "squirts on \the <b>[partner]</b>'s asshole."
									cumin = TRUE
								else
									message = "squirts on \the <b>[partner]</b>'s backside."
							if(CUM_TARGET_HAND)
								if(partner.has_hand())
									message = "squirts on \the <b>[partner]</b>'s hand."
								else
									message = "squirts on \the <b>[partner]</b>."
							if(CUM_TARGET_BREASTS)
								if(partner.has_breasts(REQUIRE_EXPOSED))
									message = "squirts onto \the <b>[partner]</b>'s breasts."
								else
									message = "squirts on \the <b>[partner]</b>'s chest and neck."
							if(NUTS_TO_FACE)
								if(partner.has_mouth() && partner.mouth_is_free())
									message = "vigorously ruts [u_His] clit into \the <b>[partner]</b>'s mouth before shooting [u_His] femcum all over [t_His] eyes and hair."

							if(THIGH_SMOTHERING)
								message = "keeps \the <b>[partner]</b> locked in [u_His] thighs as [u_He] orgasm[u_S], squirting over [t_His] face."

							if(CUM_TARGET_FEET)
								if(!last_lewd_datum || !last_lewd_datum.require_target_num_feet)
									if(partner.has_feet())
										message = "squirts on \the <b>[partner]</b>'s [partner.has_feet() == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
									else
										message = "squirts on the floor!"
								else
									if(partner.has_feet())
										message = "squirts on \the <b>[partner]</b>'s [last_lewd_datum.require_target_feet == 1 ? pick("foot", "sole") : pick("feet", "soles")]."
									else
										message = "squirts on the floor!"
							//weird shit goes here
							if(CUM_TARGET_EARS)
								if(partner.has_ears())
									message = "squirts on \the <b>[partner]</b>'s ear."
								else
									message = "squirts on \the <b>[partner]</b>'s earsocket."
								cumin = TRUE
							if(CUM_TARGET_EYES)
								if(partner.has_eyes())
									message = "squirts on \the <b>[partner]</b>'s eyeball."
								else
									message = "squirts on \the <b>[partner]</b>'s eyesocket."
								cumin = TRUE
							//
							if(CUM_TARGET_PENIS)
								if(partner.has_penis(REQUIRE_EXPOSED))
									message = "squirts on \the <b>[partner]</b>'s penis"
								else
									message = "squirts on the floor!"
							else
								message = "squirts on the floor!"
					else
						message = pick("orgasms violently!", "twists in orgasm.")
		else if(istype(partner, /obj/item/reagent_containers))
			var/did_anything = TRUE
			switch(last_genital.type)
				if(/obj/item/organ/genital/penis)
					message = "cums into \the <b>[partner]</b>!"
				if(/obj/item/organ/genital/vagina)
					message = "squirts into \the <b>[partner]</b>!"
				else
					did_anything = FALSE
			if(did_anything)
				LAZYADD(obscure_to, src)
	if(!message) //todo: better self cum messages
		message = "cums all over themselves!"
	if(gender == MALE)
		playlewdinteractionsound(loc, pick('modular_sand/sound/interactions/final_m1.ogg',
							'modular_sand/sound/interactions/final_m2.ogg',
							'modular_sand/sound/interactions/final_m3.ogg',
							'modular_sand/sound/interactions/final_m4.ogg',
							'modular_sand/sound/interactions/final_m5.ogg'), 90, 1, 0)
	else
		playlewdinteractionsound(loc, pick('modular_sand/sound/interactions/final_f1.ogg',
							'modular_sand/sound/interactions/final_f2.ogg',
							'modular_sand/sound/interactions/final_f3.ogg'), 70, 1, 0)
	visible_message(message = span_userlove("<b>\The [src]</b> [message]"), ignored_mobs = get_unconsenting(ignored_mobs = obscure_to))
	multiorgasms += 1

	COOLDOWN_START(src, refractory_period, (rand(300, 900) - get_sexual_potency()))//sex cooldown
	if(multiorgasms < get_sexual_potency())
		if(ishuman(src))
			var/mob/living/carbon/human/H = src
			if(!partner)
				H.mob_climax(TRUE, "masturbation", "none")
			else if(istype(partner, /obj/item/reagent_containers))
				H.mob_fill_container(last_genital, partner, 0)
			else
				H.mob_climax(TRUE, "sex", partner, !cumin, target_gen)
	set_lust(0)

	SEND_SIGNAL(src, COMSIG_MOB_POST_CAME, target_orifice, partner, cumin, last_genital)

	return TRUE

/mob/living/proc/is_fucking(mob/living/partner, orifice, obj/item/organ/genital/genepool, datum/interaction/lewd/lewd_datum)
	var/failed = FALSE
	if(partner)
		if(partner != last_partner)
			failed++
	if(orifice)
		if(orifice != last_orifice)
			failed++
	if(genepool)
		if(genepool != last_genital)
			failed++
	if(lewd_datum)
		if(lewd_datum != last_lewd_datum)
			failed++
	if(failed)
		return FALSE
	return TRUE

/mob/living/proc/set_is_fucking(mob/living/partner, orifice, obj/item/organ/genital/genepool)
	last_partner = partner
	last_orifice = orifice
	last_genital = genepool

/mob/living/proc/get_shoes(singular = FALSE)
	var/obj/A = get_item_by_slot(SLOT_SHOES)
	if(A)
		var/txt = A.name
		if(findtext (A.name,"the"))
			txt = copytext(A.name, 5, length(A.name)+1)
			if(singular)
				txt = copytext(A.name, 5, length(A.name))
			return txt
		else
			if(singular)
				txt = copytext(A.name, 1, length(A.name))
			return txt

///Handles the sex, if cumming returns true.
/mob/living/proc/handle_post_sex(amount, orifice, mob/living/partner)
	if(stat != CONSCIOUS)
		return FALSE

	moan()
	if(amount)
		add_lust(amount)
	if(ready_to_cum && cum(partner, orifice))
		return TRUE
	// var/lust = get_lust()
	// var/lust_tolerance = get_lust_tolerance()
	// if(lust >= lust_tolerance)
	// 	if(prob(10))
	// 		// to_chat(src, "<b>You struggle to not orgasm!</b>")
	// 		return FALSE
	// 	if(lust >= (lust_tolerance * 3) && CHECK_PREFS(src, NOTMERP_AUTOCLIMAX))
	return FALSE

/mob/living/proc/get_unconsenting(extreme = FALSE, list/ignored_mobs)
	var/list/nope = list()
	nope += ignored_mobs
	for(var/mob/M in range(7, src))
		if(M.client)
			var/client/cli = M.client
			if(!(cli.prefs.toggles & VERB_CONSENT)) //Note: This probably could do with a specific preference
				nope += M
			else if(extreme && (cli.prefs.extremepref == "No"))
				nope += M
		else
			nope += M
	return nope

/datum/emote/living/prime_cum
	key = "ready"

/datum/emote/living/prime_cum/run_emote(mob/living/user, params)
	. = ..()
	if(user.ready_to_cum == TRUE)
		to_chat(user, span_green("You're already on a hair trigger!"))
		return
	user.ready_to_cum = TRUE
	user.visible_message(span_love("[user] siezes up, ready to cum!"), pref_check = NOTMERP_LEWD_SOUNDS)
	user.emote("gasp")

/datum/emote/living/unprime_cum
	key = "unready"

/datum/emote/living/unprime_cum/run_emote(mob/living/user, params)
	if(user.ready_to_cum == FALSE)
		to_chat(user, span_green("You're already not going to do it!"))
		return
	user.ready_to_cum = FALSE
	user.visible_message(span_love("[user] relaxes[prob(1)?" and doesn't do it":""]!"), pref_check = NOTMERP_LEWD_SOUNDS)
	user.emote("sigh")

///VORER//
/datum/emote/living/splurter
	key = "consent"
	key_third_person = "consented"
	restraint_check = TRUE
	no_message = TRUE

/datum/emote/living/splurter/run_emote(mob/user)
	if(!..())
		return
	var/obj/item/hand_item/splurter/nummers = new(user)
	if(user.put_in_hands(nummers)) // NOTE: put_in_hand is MUCH different from put_in_hands - NOTE THE S
		to_chat(user, span_notice("You get ready to do sex to someone!"))
	else
		qdel(nummers)

/// splurt ITEM
/obj/item/hand_item/splurter
	name = "Mechanical Erotic Role Play initiator"
	desc = "Disclaimer: The Mechanical Erotic Role Play initiator is legally distinct from MERP(tm) and its authorized dommy subsidimommies."
	icon = 'icons/obj/in_hands.dmi'
	icon_state = "vorer"
	attack_verb = list("merped")
	hitsound = "sound/weapons/bite.ogg"
	siemens_coefficient = 5 
	force = 0
	force_wielded = 0
	throwforce = 0
	wound_bonus = -100
	sharpness = SHARP_NONE
	attack_speed = 4
	item_flags = DROPDEL | ABSTRACT | HAND_ITEM

/obj/item/hand_item/splurter/examine(mob/user)
	. = ..()
	. += span_notice("HOW TO USE:")
	. += "Hit someone with this thing to ask them to mechanically erotically roleplay with you. You'll need to do this if you want to do that with them!"

/obj/item/hand_item/splurter/attack(mob/living/L, mob/living/carbon/user)
	SSinteractions.add_or_remove_consent(user, L, TRUE)

/*
//ITEM INVENTORY SLOT BITMASKS
/// Suit slot (armors, costumes, space suits, etc.)
#define SLOT_OCLOTHING (1<<0)
/// Jumpsuit slot
#define SLOT_ICLOTHING (1<<1)
/// Glove slot
#define SLOTBIT_GLOVES (1<<2)
/// Glasses slot
#define SLOTBIT_GLASSES (1<<3)
/// Ear slot (radios, earmuffs)
#define SLOTBIT_EARS_LEFT (1<<4)
/// Mask slot
#define SLOTBIT_MASK (1<<5)
/// Head slot (helmets, hats, etc.)
#define SLOTBIT_HEAD (1<<6)
/// Shoe slot
#define SLOTBIT_FEET (1<<7)
/// ID slot
#define SLOTBIT_ID (1<<8)
/// Belt slot
#define SLOTBIT_BELT (1<<9)
/// Back slot
#define SLOTBIT_BACK (1<<10)
/// Dextrous simplemob "hands" (used for Drones and Dextrous Guardians)
#define SLOTBIT_DEX_STORAGE (1<<11)
/// Neck slot (ties, bedsheets, scarves)
#define SLOTBIT_NECK (1<<12)
/// A character's hand slots
#define SLOTBIT_HANDS (1<<13)
/// Inside of a character's backpack
#define SLOTBIT_BACKPACK (1<<14)
/// Suit Storage slot
#define SLOTBIT_S_STORE (1<<15)
/// Left Pocket slot
#define SLOTBIT_L_STORE (1<<16)
/// Right Pocket slot
#define SLOTBIT_R_STORE (1<<17)
// -- Sandstorm edit --
/// Underwear slot
#define SLOTBIT_UNDERWEAR (1<<18)
/// Socks slot
#define SLOTBIT_SOCKS (1<<19)
/// Shirt slot
#define SLOTBIT_SHIRT (1<<20)
/// Right ear slot
#define SLOTBIT_EARS_RIGHT (1<<21)
/// Wrist slot
#define SLOTBIT_WRISTS (1<<22)
// -- End edit --
/// Handcuff slot
#define SLOTBIT_HANDCUFFED (1<<23)
/// Legcuff slot (bolas, beartraps)
#define SLOTBIT_LEGCUFFED (1<<24)
/// To attach to a jumpsuit
#define SLOTBIT_ACCESSORY (1<<25)
*/

/// Specifies a bitfield for smarter debugging
/datum/bitfield
	/// The variable name that contains the bitfield
	var/variable

	/// An associative list of the readable flag and its true value
	var/list/flags

/// Turns /datum/bitfield subtypes into a list for use in debugging
/proc/generate_bitfields()
	var/list/bitfields = list()
	for (var/_bitfield in subtypesof(/datum/bitfield))
		var/datum/bitfield/bitfield = new _bitfield
		bitfields[bitfield.variable] = bitfield.flags
	return bitfields

/*
DEFINE_BITFIELD(slot_flags, list(
	"SLOTBIT_ACCESSORY" = SLOT_ACCESSORY,
	"SLOTBIT_BACK" = SLOT_BACK,
	"SLOTBIT_BACKPACK" = SLOT_BACKPACK,
	"SLOTBIT_BELT" = SLOT_BELT,
	"SLOTBIT_DEX_STORAGE" = SLOT_DEX_STORAGE,
	"SLOTBIT_EARS" = SLOT_EARS,
	"SLOTBIT_GLASSES" = SLOT_GLASSES,
	"SLOTBIT_FEET" = SLOT_SHOES,
	"SLOTBIT_GLOVES" = SLOT_GLOVES,
	"SLOTBIT_HANDCUFFED" = SLOT_HANDCUFFED,
	"SLOTBIT_HANDS" = SLOT_HANDS,
	"SLOTBIT_HEAD" = SLOT_HEAD,
	"SLOTBIT_ICLOTHING" = SLOT_ICLOTHING,
	"SLOTBIT_ID" = SLOT_ID,
	"SLOTBIT_LEGCUFFED" = SLOT_LEGCUFFED,
	"SLOTBIT_L_STORE" = SLOT_L_STORE,
	"SLOTBIT_MASK" = SLOT_MASK,
	"SLOTBIT_NECK" = SLOT_NECK,
	"SLOTBIT_OCLOTHING" = SLOT_OCLOTHING,
	"SLOTBIT_R_STORE" = SLOT_R_STORE,
	"SLOTBIT_S_STORE" = SLOT_S_STORE,
))
*/
