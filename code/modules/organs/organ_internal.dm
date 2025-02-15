#define PROCESS_ACCURACY 10

/****************************************************
				INTERNAL ORGANS DEFINES
****************************************************/


// Brain is defined in brain_item.dm.
/obj/item/organ/heart
	name = "heart"
	icon_state = "heart-on"
	organ_tag = "heart"
	parent_organ = "chest"
	dead_icon = "heart-off"
	robotic_name = "circulatory pump"
	robotic_sprite = "heart-prosthetic"

/obj/item/organ/lungs
	name = "lungs"
	icon_state = "lungs"
	gender = PLURAL
	organ_tag = "lungs"
	parent_organ = "chest"
	robotic_name = "gas exchange system"
	robotic_sprite = "heart-prosthetic"
	var/rescued = FALSE // whether or not a collapsed lung has been rescued with a syringe

/obj/item/organ/lungs/process()
	..()

	if(!owner)
		return

	if (germ_level > INFECTION_LEVEL_ONE)
		if(prob(5))
			owner.emote("cough")		//Respiratory tract infection

	if(is_broken() || (is_bruised() && !rescued)) // a thoracostomy can only help with a collapsed lung, not a mangled one
		if(prob(2))
			spawn owner.emote("me", 1, "coughs up blood!")
			owner.drip(10)
		if(prob(4))
			spawn owner.emote("me", 1, "gasps for air!")
			owner.losebreath += 15

	if(is_bruised() && rescued)
		if(prob(4))
			to_chat(owner, span("warning", "It feels hard to breathe..."))
			if (owner.losebreath < 5)
				owner.losebreath = min(owner.losebreath + 1, 5) // it's still not good, but it's much better than an untreated collapsed lung

/obj/item/organ/kidneys
	name = "kidneys"
	icon_state = "kidneys"
	gender = PLURAL
	organ_tag = "kidneys"
	parent_organ = "groin"
	robotic_name = "prosthetic kidneys"
	robotic_sprite = "kidneys-prosthetic"

/obj/item/organ/kidneys/process()

	..()

	if(!owner)
		return

	// Coffee is really bad for you with busted kidneys.
	// This should probably be expanded in some way, but fucked if I know
	// what else kidneys can process in our reagent list.
	var/datum/reagent/coffee = locate(/datum/reagent/drink/coffee) in owner.reagents.reagent_list
	if(coffee)
		if(is_bruised())
			owner.adjustToxLoss(0.1 * PROCESS_ACCURACY)
		else if(is_broken())
			owner.adjustToxLoss(0.3 * PROCESS_ACCURACY)

/obj/item/organ/eyes
	name = "eyeballs"
	icon_state = "eyes"
	gender = PLURAL
	organ_tag = "eyes"
	parent_organ = "head"
	robotic_name = "visual prosthesis"
	robotic_sprite = "eyes-prosthetic"
	var/list/eye_colour = list(0,0,0)
	var/singular_name = "eye"

/obj/item/organ/eyes/proc/update_colour()
	if(!owner)
		return
	eye_colour = list(
		owner.r_eyes ? owner.r_eyes : 0,
		owner.g_eyes ? owner.g_eyes : 0,
		owner.b_eyes ? owner.b_eyes : 0
		)

/obj/item/organ/eyes/take_damage(amount, var/silent=0)
	var/oldbroken = is_broken()
	..()
	if(is_broken() && !oldbroken && owner && !owner.stat)
		to_chat(owner, "<span class='danger'>You go blind!</span>")

/obj/item/organ/eyes/proc/flash_act()
	return

/obj/item/organ/eyes/process() //Eye damage replaces the old eye_stat var.
	..()
	if(!owner)
		return
	if(is_bruised())
		owner.eye_blurry = 20
	if(is_broken())
		owner.eye_blind = 20

/obj/item/organ/liver
	name = "liver"
	icon_state = "liver"
	organ_tag = "liver"
	parent_organ = "groin"
	robotic_name = "toxin filter"
	robotic_sprite = "liver-prosthetic"

/obj/item/organ/liver/process()

	..()

	if(!owner)
		return

	if (germ_level > INFECTION_LEVEL_ONE)
		if(prob(1))
			to_chat(owner, "<span class='warning'>Your skin itches.</span>")
	if (germ_level > INFECTION_LEVEL_TWO)
		if(prob(1))
			spawn owner.delayed_vomit()

	if(owner.life_tick % PROCESS_ACCURACY == 0)

		//A liver's duty is to get rid of toxins
		if(owner.getToxLoss() > 0 && owner.getToxLoss() <= 3)
			owner.adjustToxLoss(-0.2) //there isn't a lot of toxin damage, so we're going to be chill and slowly filter it out
		else if(owner.getToxLoss() > 3)
			if(is_bruised())
				//damaged liver works less efficiently
				owner.adjustToxLoss(-0.5)
				if(!owner.reagents.has_reagent("anti_toxin")) //no damage to liver if anti-toxin is present
					src.damage += 0.1 * PROCESS_ACCURACY
			else if(is_broken())
				//non-functioning liver ADDS toxins
				owner.adjustToxLoss(-0.1) //roughly 33 minutes to kill someone straight out, stacks with 60+ tox proc tho
			else 
				//functioning liver removes toxins at a cost
				owner.adjustToxLoss(-1)
				if(!owner.reagents.has_reagent("anti_toxin")) //no damage to liver if anti-toxin is present
					src.damage += 0.05 * PROCESS_ACCURACY


		//High toxins levels are super dangerous
		if(owner.getToxLoss() >= 60 && !owner.reagents.has_reagent("anti_toxin"))
			//Healthy liver suffers on its own
			if (src.damage < min_broken_damage)
				src.damage += 0.2 * PROCESS_ACCURACY
			//Damaged one shares the fun
			else
				var/obj/item/organ/O = pick(owner.internal_organs)
				if(O)
					O.damage += 0.2  * PROCESS_ACCURACY

		//Detox can heal small amounts of damage
		if (src.damage && src.damage < src.min_bruised_damage && owner.reagents.has_reagent("anti_toxin"))
			src.damage -= 0.2 * PROCESS_ACCURACY

		if(src.damage < 0)
			src.damage = 0

		var/filter_strength = INTOX_FILTER_HEALTHY
		if(is_bruised())
			filter_strength = INTOX_FILTER_BRUISED
		if(is_broken())
			filter_strength = INTOX_FILTER_DAMAGED

		if (owner.intoxication > 0)
			owner.intoxication -= filter_strength*PROCESS_ACCURACY
			owner.intoxication = max(owner.intoxication, 0)
			if (!owner.intoxication)
				owner.handle_intoxication()

		if(owner.chem_effects[CE_ALCOHOL_TOXIC])
			take_damage(owner.chem_effects[CE_ALCOHOL_TOXIC] * 0.1 * PROCESS_ACCURACY, prob(1))
			if(is_damaged())
				owner.adjustToxLoss(owner.chem_effects[CE_ALCOHOL_TOXIC] * 0.1 * PROCESS_ACCURACY)

/obj/item/organ/appendix
	name = "appendix"
	icon_state = "appendix"
	parent_organ = "groin"
	organ_tag = "appendix"

/obj/item/organ/appendix/removed()
	if(owner)
		var/inflamed = 0
		for(var/datum/disease/appendicitis/appendicitis in owner.viruses)
			inflamed = 1
			appendicitis.cure()
			owner.resistances += appendicitis
		if(inflamed)
			icon_state = "appendixinflamed"
			name = "inflamed appendix"
	..()
