/*
	The broadcaster sends processed messages to all radio devices in the game. They
	do not have to be headsets; intercoms and station-bounced radios suffice.

	They receive their message from a server after the message has been logged.
*/


/obj/machinery/telecomms/broadcaster
	name = "Subspace Broadcaster"
	icon = 'stationobjs.dmi'
	icon_state = "broadcaster"
	desc = "A dish-shaped machine used to broadcast processed subspace signals."
	density = 1
	anchored = 1
	use_power = 1
	idle_power_usage = 25
	machinetype = 5
	receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)


		if(signal.data["message"])


			/* ###### Broadcast a message using signal.data ###### */
			Broadcast_Message(signal.data["connection"], signal.data["mob"],
							  signal.data["vmask"], signal.data["vmessage"],
							  signal.data["radio"], signal.data["message"],
							  signal.data["name"], signal.data["job"],
							  signal.data["realname"], signal.data["vname"])

			signal.data["done"] = 1 // mark the signal as being broadcasted

			// Search for the original signal and mark it as done as well
			var/datum/signal/original = signal.data["original"]
			if(original)
				original.data["done"] = 1

			/* --- Do a snazzy animation! --- */
			flick("broadcaster_send", src)

/**

	Here is the big, bad function that broadcasts a message given the appropriate
	parameters.

	@param connection:
		The datum generated in radio.dm, stored in signal.data["connection"].

	@param M:
		Reference to the mob/speaker, stored in signal.data["mob"]

	@param vmask:
		Boolean value if the mob is "hiding" its identity via voice mask, stored in
		signal.data["vmask"]

	@param vmessage:
		If specified, will display this as the message; such as "chimpering"
		for monkies if the mob is not understood. Stored in signal.data["vmessage"].

	@param radio:
		Reference to the radio broadcasting the message, stored in signal.data["radio"]

	@param message:
		The actual string message to display to mobs who understood mob M. Stored in
		signal.data["message"]

	@param name:
		The name to display when a mob receives the message. signal.data["name"]

	@param job:
		The name job to display for the AI when it receives the message. signal.data["job"]

	@param realname:
		The "real" name associated with the mob. signal.data["realname"]

	@param vname:
		If specified, will use this name when mob M is not understood. signal.data["vname"]

	@param filtertype:
		If specified:
				1 -- Will only broadcast to intercoms
				2 -- Will only broadcast to intercoms and station-bounced radios

**/

/proc/Broadcast_Message(var/datum/radio_frequency/connection, var/mob/M,
						var/vmask, var/vmessage, var/obj/item/device/radio/radio,
						var/message, var/name, var/job, var/realname, var/vname,
						var/filtertype)


  /* ###### Prepare the radio connection ###### */

	var/display_freq = connection.frequency

	var/list/receive = list()


	// --- Broadcast only to intercom devices ---

	if(filtertype == 1)
		for (var/obj/item/device/radio/intercom/R in connection.devices["[RADIO_CHAT]"])

			receive |= R.send_hear(display_freq)


	// --- Broadcast only to intercoms and station-bounced radios ---

	else if(filtertype == 2)
		for (var/obj/item/device/radio/R in connection.devices["[RADIO_CHAT]"])

			if(istype(R, /obj/item/device/radio/headset))
				continue

			receive |= R.send_hear(display_freq)


	// --- Broadcast to ALL radio devices ---

	else
		for (var/obj/item/device/radio/R in connection.devices["[RADIO_CHAT]"])

			receive |= R.send_hear(display_freq)


  /* ###### Organize the receivers into categories for displaying the message ###### */

  	// Understood the message:
	var/list/heard_masked 	= list() // masked name or no real name
	var/list/heard_normal 	= list() // normal message

	// Did not understand the message:
	var/list/heard_voice 	= list() // voice message	(ie "chimpers")
	var/list/heard_garbled	= list() // garbled message (ie "f*c* **u, **i*er!")

	for (var/mob/R in receive)

	  /* --- Loop through the receivers and categorize them --- */

		if (R.client && R.client.STFU_radio) //Adminning with 80 people on can be fun when you're trying to talk and all you can hear is radios.
			continue

		// --- Can understand the speech ---

		if (R.say_understands(M))

			// - Not human or wearing a voice mask -
			if (!ishuman(M) || vmask)
				heard_masked += R

			// - Human and not wearing voice mask -
			else
				heard_normal += R

		// --- Can't understand the speech ---

		else
			// - The speaker has a prespecified "voice message" to display if not understood -
			if (vmessage)
				heard_voice += R

			// - Just display a garbled message -
			else
				heard_garbled += R


  /* ###### Begin formatting and sending the message ###### */
	if (length(heard_masked) || length(heard_normal) || length(heard_voice) || length(heard_garbled))

	  /* --- Some miscellaneous variables to format the string output --- */
		var/part_a = "<span class='radio'><span class='name'>" // goes in the actual output
		var/freq_text // the name of the channel

		// --- Set the name of the channel ---
		switch(display_freq)

			if(SYND_FREQ)
				freq_text = "#unkn"
			if(COMM_FREQ)
				freq_text = "Command"
			if(1351)
				freq_text = "Science"
			if(1355)
				freq_text = "Medical"
			if(1357)
				freq_text = "Engineering"
			if(1359)
				freq_text = "Security"
			if(1349)
				freq_text = "Mining"
			if(1347)
				freq_text = "Cargo"
		//There's probably a way to use the list var of channels in code\game\communications.dm to make the dept channels non-hardcoded, but I wasn't in an experimentive mood. --NEO


		// --- If the frequency has not been assigned a name, just use the frequency as the name ---

		if(!freq_text)
			freq_text = format_frequency(display_freq)

		// --- Some more pre-message formatting ---

		var/part_b = "</span><b> \icon[radio]\[[freq_text]\]</b> <span class='message'>" // Tweaked for security headsets -- TLE
		var/part_c = "</span></span>"

		if (display_freq==SYND_FREQ)
			part_a = "<span class='syndradio'><span class='name'>"
		else if (display_freq==COMM_FREQ)
			part_a = "<span class='comradio'><span class='name'>"
		else if (display_freq in DEPT_FREQS)
			part_a = "<span class='deptradio'><span class='name'>"


		// --- Filter the message; place it in quotes apply a verb ---

		var/quotedmsg = M.say_quote(message)

		// --- This following recording is intended for research and feedback in the use of department radio channels ---

		var/part_blackbox_b = "</span><b> \[[freq_text]\]</b> <span class='message'>" // Tweaked for security headsets -- TLE
		var/blackbox_msg = "[part_a][name][part_blackbox_b][quotedmsg][part_c]"
		//var/blackbox_admin_msg = "[part_a][M.name] (Real name: [M.real_name])[part_blackbox_b][quotedmsg][part_c]"
		for (var/obj/machinery/blackbox_recorder/BR in world)
			//BR.messages_admin += blackbox_admin_msg
			switch(display_freq)
				if(1459)
					BR.msg_common += blackbox_msg
				if(1351)
					BR.msg_science += blackbox_msg
				if(1353)
					BR.msg_command += blackbox_msg
				if(1355)
					BR.msg_medical += blackbox_msg
				if(1357)
					BR.msg_engineering += blackbox_msg
				if(1359)
					BR.msg_security += blackbox_msg
				if(1441)
					BR.msg_deathsquad += blackbox_msg
				if(1213)
					BR.msg_syndicate += blackbox_msg
				if(1349)
					BR.msg_mining += blackbox_msg
				if(1347)
					BR.msg_cargo += blackbox_msg
				else
					BR.messages += blackbox_msg

		//End of research and feedback code.

	 /* ###### Send the message ###### */


	  	/* --- Process all the mobs that heard a masked voice (understood) --- */

		if (length(heard_masked))
			var/N = name
			var/J = job
			var/rendered = "[part_a][N][part_b][quotedmsg][part_c]"
			for (var/mob/R in heard_masked)
				if(istype(R, /mob/living/silicon/ai))
					R.show_message("[part_a]<a href='byond://?src=\ref[radio];track2=\ref[R];track=\ref[M]'>[N] ([J]) </a>[part_b][quotedmsg][part_c]", 2)
				else
					R.show_message(rendered, 2)

		/* --- Process all the mobs that heard the voice normally (understood) --- */

		if (length(heard_normal))
			var/rendered = "[part_a][M.real_name][part_b][quotedmsg][part_c]"

			for (var/mob/R in heard_normal)
				if(istype(R, /mob/living/silicon/ai))
					R.show_message("[part_a]<a href='byond://?src=\ref[radio];track2=\ref[R];track=\ref[M]'>[realname] ([job]) </a>[part_b][quotedmsg][part_c]", 2)
				else
					R.show_message(rendered, 2)

		/* --- Process all the mobs that heard the voice normally (did not understand) --- */
			// Does not display message; displayes the mob's voice_message (ie "chimpers")

		if (length(heard_voice))
			var/rendered = "[part_a][vname][part_b][M.voice_message][part_c]"

			for (var/mob/R in heard_voice)
				if(istype(R, /mob/living/silicon/ai))
					R.show_message("[part_a]<a href='byond://?src=\ref[radio];track2=\ref[R];track=\ref[M]'>[vname] ([job]) </a>[part_b][vmessage]][part_c]", 2)
				else
					R.show_message(rendered, 2)

		/* --- Process all the mobs that heard a garbled voice (did not understand) --- */
			// Displays garbled message (ie "f*c* **u, **i*er!")

		if (length(heard_garbled))
			quotedmsg = M.say_quote(stars(message))
			var/rendered = "[part_a][vname][part_b][quotedmsg][part_c]"

			for (var/mob/R in heard_voice)
				if(istype(R, /mob/living/silicon/ai))
					R.show_message("[part_a]<a href='byond://?src=\ref[radio];track2=\ref[R];track=\ref[M]'>[vname]</a>[part_b][quotedmsg][part_c]", 2)
				else
					R.show_message(rendered, 2)



