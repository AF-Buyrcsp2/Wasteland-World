GLOBAL_LIST_INIT(blacklisted_cargo_types, typecacheof(list(
		/mob/living,
		/obj/structure/blob,
		/obj/effect/rune,
		/obj/structure/spider/spiderling,
		/obj/item/disk/nuclear,
		/obj/machinery/nuclearbomb,
		/obj/item/beacon,
		/obj/singularity/narsie,
		/obj/singularity/wizard,
		/obj/machinery/teleport/station,
		/obj/machinery/teleport/hub,
		/obj/machinery/quantumpad,
		/obj/machinery/clonepod,
		/obj/effect/mob_spawn,
		/obj/effect/hierophant,
		/obj/structure/receiving_pad,
//		/obj/effect/clockwork/spatial_gateway,
//		/obj/structure/destructible/clockwork/powered/clockwork_obelisk,
		/obj/item/warp_cube,
		/obj/machinery/rnd/production/protolathe, //print tracking beacons, send shuttle
		/obj/machinery/autolathe, //same
		/obj/item/projectile/beam/wormhole,
		/obj/effect/portal,
		/obj/item/shared_storage,
		/obj/structure/extraction_point,
		/obj/machinery/syndicatebomb
	)))

GLOBAL_LIST_INIT(cargo_shuttle_leave_behind_typecache, typecacheof(list(
	/mob/living/simple_animal/revenant,
	/mob/living/simple_animal/slaughter
	)))

/obj/docking_port/mobile/supply
	name = "supply shuttle"
	id = "supply"
	callTime = 600

	dir = WEST
	port_direction = EAST
	width = 12
	dwidth = 5
	height = 7
	movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)


	//Export categories for this run, this is set by console sending the shuttle.
	var/export_categories = EXPORT_CARGO

/obj/docking_port/mobile/supply/register()
	. = ..()
	SSshuttle.supply = src

/obj/docking_port/mobile/supply/canMove()
	if(is_station_level(z))
		return check_blacklist(shuttle_areas, GLOB.blacklisted_cargo_types - GLOB.cargo_shuttle_leave_behind_typecache)
	return ..()

/obj/docking_port/mobile/supply/enterTransit()
	var/list/leave_behind = list()
	for(var/i in check_blacklist(shuttle_areas, GLOB.cargo_shuttle_leave_behind_typecache))
		var/atom/movable/AM = i
		leave_behind[AM] = AM.loc
	. = ..()
	for(var/kicked in leave_behind)
		var/atom/movable/victim = kicked
		var/atom/oldloc = leave_behind[victim]
		victim.forceMove(oldloc)

/obj/docking_port/mobile/supply/proc/check_blacklist(areaInstances, list/typecache)
	for(var/place in areaInstances)
		var/area/shuttle/shuttle_area = place
		for(var/trf in shuttle_area)
			var/turf/T = trf
			for(var/a in T.GetAllContents())
				if(is_type_in_typecache(a, typecache))
					return FALSE
				if(istype(a, /obj/structure/closet))//Prevents eigenlockers from ending up at CC
					var/obj/structure/closet/c = a
					if(c.eigen_teleport == TRUE)
						return FALSE
	return TRUE

/obj/docking_port/mobile/supply/request(obj/docking_port/stationary/S)
	if(mode != SHUTTLE_IDLE)
		return 2
	return ..()

/obj/docking_port/mobile/supply/initiate_docking()
	if(getDockedId() == "supply_away") // Buy when we leave home.
		buy()
	. = ..() // Fly/enter transit.
	if(. != DOCKING_SUCCESS)
		return
	if(getDockedId() == "supply_away") // Sell when we get home
		sell()

/obj/docking_port/mobile/supply/proc/buy()
	if(!SSshuttle.shoppinglist.len)
		return

	var/list/obj/miscboxes = list() //miscboxes are combo boxes that contain all goody orders grouped
	var/list/misc_order_num = list() //list of strings of order numbers, so that the manifest can show all orders in a box
	var/list/misc_contents = list() //list of lists of items that each box will contain

	var/list/empty_turfs = list()
	for(var/place in shuttle_areas)
		var/area/shuttle/shuttle_area = place
		for(var/turf/open/floor/T in shuttle_area)
			if(is_blocked_turf(T))
				continue
			empty_turfs += T

	var/datum/bank_account/cargo_budget = SSeconomy.get_dep_account(ACCOUNT_CAR)
	var/value = 0
	var/purchases = 0
	for(var/datum/supply_order/SO in SSshuttle.shoppinglist)
		if(!empty_turfs.len)
			break

		var/price = SO.pack.cost
		if(SO.applied_coupon)
			price *= (1 - SO.applied_coupon.discount_pct_off)
		var/datum/bank_account/D
		if(SO.paying_account) //Someone paid out of pocket
			D = SO.paying_account
			if(!SO.pack.goody)
				price *= 1.1 //TODO make this customizable by the quartermaster
		else
			D = cargo_budget
		if(D)
			if(!D.adjust_money(-SO.pack.cost))
				if(SO.paying_account)
					D.bank_card_talk("Cargo order #[SO.id] rejected due to lack of funds. Credits required: [price]")
				continue

		if(SO.paying_account)
			D.bank_card_talk("Cargo order #[SO.id] has shipped. [price] credits have been charged to your bank account.")
			var/datum/bank_account/department/cargo = SSeconomy.get_dep_account(ACCOUNT_CAR)
			cargo.adjust_money(price - SO.pack.cost) //Cargo gets the handling fee
		value += SO.pack.cost
		SSshuttle.shoppinglist -= SO
		SSshuttle.orderhistory += SO
		QDEL_NULL(SO.applied_coupon)

		if(SO.pack.goody) //goody means it gets piled in the miscbox
			if(SO.paying_account)
				if(!miscboxes.len || !miscboxes[D.account_holder]) //if there's no miscbox for this person
					miscboxes[D.account_holder] = new /obj/item/storage/lockbox/order(pick_n_take(empty_turfs))
					var/obj/item/storage/lockbox/order/our_box = miscboxes[D.account_holder]
					our_box.buyer_account = SO.paying_account
					miscboxes[D.account_holder].name = "small items case - purchased by [D.account_holder]"
					misc_contents[D.account_holder] = list()
				for (var/item in SO.pack.contains)
					misc_contents[D.account_holder] += item
				misc_order_num[D.account_holder] = "[misc_order_num[D.account_holder]]#[SO.id]  "
			else //No private payment, so we just stuff it all into a generic crate
				if(!miscboxes.len || !miscboxes["Cargo"])
					miscboxes["Cargo"] = new /obj/structure/closet/secure_closet/goodies(pick_n_take(empty_turfs))
					miscboxes["Cargo"].name = "small items closet"
					misc_contents["Cargo"] = list()
					miscboxes["Cargo"].req_access = list()
				for (var/item in SO.pack.contains)
					misc_contents["Cargo"] += item
					//new item(miscboxes["Cargo"])
				if(SO.pack.access)
					miscboxes["Cargo"].req_access += SO.pack.access
				misc_order_num["Cargo"] = "[misc_order_num["Cargo"]]#[SO.id]  "
		else
			SO.generate(pick_n_take(empty_turfs))

		SSblackbox.record_feedback("nested tally", "cargo_imports", 1, list("[SO.pack.cost]", "[SO.pack.name]"))
		investigate_log("Order #[SO.id] ([SO.pack.name], placed by [key_name(SO.orderer_ckey)]), paid by [D.account_holder] has shipped.", INVESTIGATE_CARGO)
		if(SO.pack.dangerous)
			message_admins("\A [SO.pack.name] ordered by [ADMIN_LOOKUPFLW(SO.orderer_ckey)], paid by [D.account_holder] has shipped.")
		purchases++

	for(var/I in miscboxes)
		var/datum/supply_order/SO = new/datum/supply_order()
		SO.id = misc_order_num[I]
		SO.generateCombo(miscboxes[I], I, misc_contents[I])
		qdel(SO)

	investigate_log("[purchases] orders in this shipment, worth [value] credits. [cargo_budget.account_balance] credits left.", INVESTIGATE_CARGO)

/obj/docking_port/mobile/supply/proc/sell()
	var/datum/bank_account/D = SSeconomy.get_dep_account(ACCOUNT_CAR)
	var/gain = 0

	if(!GLOB.exports_list.len) // No exports list? Generate it!
		setupExports()

	var/msg = ""
	var/matched_bounty = FALSE

	var/datum/export_report/ex = new

	for(var/place in shuttle_areas)
		var/area/shuttle/shuttle_area = place
		for(var/atom/movable/AM in shuttle_area)
			if(iscameramob(AM))
				continue
			if(bounty_ship_item_and_contents(AM, dry_run = FALSE))
				matched_bounty = TRUE
			if(!AM.anchored || istype(AM, /obj/mecha))
				export_item_and_contents(AM, export_categories , dry_run = FALSE, external_report = ex)

	if(ex.exported_atoms)
		ex.exported_atoms += "." //ugh

	if(matched_bounty)
		msg += "Bounty items received. An update has been sent to all bounty consoles. "

	for(var/datum/export/E in ex.total_amount)
		var/export_text = E.total_printout(ex)
		if(!export_text)
			continue

		msg += export_text + "\n"
		gain += ex.total_value[E]

	for(var/chem in ex.reagents_value)
		var/value = ex.reagents_value[chem]
		msg += "[value > 0 ? "+" : ""][value] credits: received [ex.reagents_volume[chem]]u of [chem].\n"
		gain += value

	D.adjust_money(gain)
	msg = copytext_char(msg, 1, MAX_MESSAGE_LEN)

	SSshuttle.centcom_message = msg
	investigate_log("Shuttle contents sold for [gain] credits. Contents: [ex.exported_atoms || "none."] Message: [SSshuttle.centcom_message || "none."]", INVESTIGATE_CARGO)
