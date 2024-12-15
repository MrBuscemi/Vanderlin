/// DEFINITIONS ///
#define CLERIC_T0 0
#define CLERIC_T1 1
#define CLERIC_T2 2
#define CLERIC_T3 3

#define CLERIC_REQ_1 80
#define CLERIC_REQ_2 160
#define CLERIC_REQ_3 240

// Cleric Holder Datums

/datum/devotion/cleric_holder
	var/mob/living/carbon/human/holder_mob = null
	var/patron = null
	var/devotion = 0
	var/max_devotion = 1000
	var/progression = 0
	var/level = CLERIC_T0
	/// How much devotion is gained per process call
	var/passive_devotion_gain = 0
	/// How much progression is gained per process call
	var/passive_progression_gain = 0
	/// How much devotion is gained per prayer cycle
	var/prayer_effectiveness = 2

/datum/devotion/cleric_holder/New(mob/living/carbon/human/holder, god)
	holder_mob = holder
	holder.cleric = src
	patron = god

/datum/devotion/cleric_holder/Destroy(force)
	. = ..()
	holder_mob?.cleric = null
	holder_mob = null
	patron = null
	STOP_PROCESSING(SSpersecond, src)

/datum/devotion/cleric_holder/process()
	if(!passive_devotion_gain && !passive_progression_gain)
		return PROCESS_KILL
	if(holder_mob.stat >= DEAD)
		return
	update_devotion(passive_devotion_gain, passive_progression_gain)

/datum/devotion/cleric_holder/proc/check_devotion(req)
	if(abs(req) <= devotion)
		return TRUE
	else
		return FALSE

/datum/devotion/cleric_holder/proc/update_devotion(dev_amt, prog_amt)
	var/datum/patron/P = patron
	devotion += dev_amt
	//Max devotion limit
	if(devotion > max_devotion)
		devotion = max_devotion
	if(!prog_amt) // no point in the rest if it's just an expenditure
		return
	progression += prog_amt
	switch(level)
		if(CLERIC_T0)
			if(progression >= CLERIC_REQ_1)
				level = CLERIC_T1
				usr.mind.AddSpell(new P.t1)
				return
		if(CLERIC_T1)
			if(progression >= CLERIC_REQ_2)
				level = CLERIC_T2
				usr.mind.AddSpell(new P.t2)
				return
		if(CLERIC_T2)
			if(progression >= CLERIC_REQ_3)
				level = CLERIC_T3
				usr.mind.AddSpell(new P.t3)
				to_chat(usr, span_notice("All my Gods miracles are now open to me..."))
				return
		if(CLERIC_T3) // already maxed out
			return


/datum/devotion/cleric_holder/proc/grant_spells_churchling(mob/living/carbon/human/H)
	if(!H || !H.mind || !patron)
		return

	var/list/spelllist = list(/obj/effect/proc_holder/spell/targeted/touch/orison, /obj/effect/proc_holder/spell/invoked/lesser_heal, /obj/effect/proc_holder/spell/invoked/diagnose) //This would have caused jank.
	for(var/spell_type in spelllist)
		if(!spell_type || H.mind.has_spell(spell_type))
			continue
		var/newspell = new spell_type
		H.mind.AddSpell(newspell)
	level = CLERIC_T0
	max_devotion = CLERIC_REQ_1 //Max devotion limit - Churchlings only get diagnose and lesser miracle.

// Cleric Spell Spawner
/datum/devotion/cleric_holder/proc/grant_spells_priest(mob/living/carbon/human/H)
	if(!H || !H.mind)
		return

	var/datum/patron/A = H.patron
	var/list/spelllist = list(/obj/effect/proc_holder/spell/targeted/touch/orison, A.t0, A.t1, A.t2, A.t3, /obj/effect/proc_holder/spell/invoked/cure_rot)
	for(var/spell_type in spelllist)
		if(!spell_type || H.mind.has_spell(spell_type))
			continue
		H.mind.AddSpell(new spell_type)
	level = CLERIC_T3
	passive_devotion_gain = 1 //1 devotion per second
	update_devotion(300, 900)
	START_PROCESSING(SSpersecond, src)

/datum/devotion/cleric_holder/proc/grant_spells(mob/living/carbon/human/H)
	if(!H || !H.mind)
		return

	var/datum/patron/A = H.patron
	var/list/spelllist = list(A.t0, A.t1)
	for(var/spell_type in spelllist)
		if(!spell_type || H.mind.has_spell(spell_type))
			continue
		H.mind.AddSpell(new spell_type)
	level = CLERIC_T1

/datum/devotion/cleric_holder/proc/grant_spells_cleric(mob/living/carbon/human/H)
	if(!H || !H.mind)
		return

	var/datum/patron/A = H.patron
	var/list/spelllist = list(A.t0, A.t1)
	for(var/spell_type in spelllist)
		if(!spell_type || H.mind.has_spell(spell_type))
			continue
		H.mind.AddSpell(new spell_type)
	level = CLERIC_T1
	max_devotion = 230

/datum/devotion/cleric_holder/proc/grant_spells_templar(mob/living/carbon/human/H)
	if(!H || !H.mind)
		return

	var/datum/patron/A = H.patron
	var/list/spelllist = list(/obj/effect/proc_holder/spell/targeted/churn, A.t0)
	for(var/spell_type in spelllist)
		if(!spell_type || H.mind.has_spell(spell_type))
			continue
		H.mind.AddSpell(new spell_type)
	level = CLERIC_T0
	max_devotion = 150

/mob/living/carbon/human/proc/devotionreport()
	set name = "Check Devotion"
	set category = "Cleric"

	var/datum/devotion/cleric_holder/C = src.cleric
	to_chat(src,"My devotion is [C.devotion].")

// Debug verb
/mob/living/carbon/human/proc/devotionchange()
	set name = "(DEBUG)Change Devotion"
	set category = "Special Verbs"

	var/datum/devotion/cleric_holder/C = src.cleric
	var/changeamt = input(src, "My devotion is [C.devotion]. How much to change?", "How much to change?") as null|num
	if(!changeamt)
		return
	C.update_devotion(changeamt)

// Generation Procs

/mob/living/carbon/human/proc/clericpray()
	set name = "Give Prayer"
	set category = "Cleric"

	var/datum/devotion/cleric_holder/C = src.cleric
	if(!C)
		return
	if(C.devotion >= C.max_devotion)
		to_chat(src, "<font color='red'>I have reached the limit of my devotion...</font>")
		return
	var/prayersesh = 0
	visible_message("[src] kneels their head in prayer.", "I kneel my head in prayer to [patron.name].")
	for(var/i in 1 to 50)
		if(do_after(src, 30))
			if(C.devotion >= C.max_devotion)
				to_chat(src, "<font color='red'>I have reached the limit of my devotion...</font>")
				break
			C.update_devotion(C.prayer_effectiveness, C.prayer_effectiveness)
			prayersesh += C.prayer_effectiveness
		else
			visible_message("[src] concludes their prayer.", "I conclude my prayer.")
			break
	to_chat(src, "<font color='purple'>I gained [prayersesh] devotion!</font>")
