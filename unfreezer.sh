#!/bin/bash

# UnFreezer lite v0.1
# A set of scripts to determine when the OVERNET Linux command line client has "frozen" - does not respond to
# user interaction anymore - and kill/restart it then.
# Copyleft 2002 Praetorian - check LICENSE.unfreezer for the license conditions.

echo `date` "Starting UnFreezer as `id | cut -f2 -d'(' | cut -f1 -d')'`."

# Determine where which directory to run in (the other scripts are there...)
UNFREEZER_DIR="`dirname $0`"

# This could be pushd/popd'd but UnFreezer will be aborted by a Ctrl-C, so the popd won't be executed anyway. 
cd "$UNFREEZER_DIR" 

# Load the config
. ./unfreezer.conf

# Set some internal variables
READY_TO_RUN="FALSE"

# Unless UnFreezer and OVERNET are supposed to run as root but we still are root, we should change the user. 
# The variable READY_TO_RUN is set to "TRUE" if we reach a state that allows for the actual execution of UnFreezer. 
if [ "$OVERNET_USER" != "root" ];
	then	if id | awk '{print $1}' | grep root >/dev/null 2>&1; 
			then	# We are root although we are supposed not to be - let's change this. 
				# Another unfreezer.sh process, started as OVERNET_USER, is called. 
				# There is probably a more elegant way to do this, such as setuid in C. 
				# I didn't find it though. ;)
				echo `date` "UnFreezer is changing user to $OVERNET_USER.";
				su $OVERNET_USER -c "./unfreezer.sh";
				# Unfortunately, we can not detach this process and exit now, as OVERNET 
				# _needs_ foreground. But we will exit once our "child" is dead. 
				exit 0;
			else	# We no longer are root - so we are READY_TO_RUN. 
				READY_TO_RUN="TRUE";
		fi;
	else	# If we are supposed to run as root, we are READY_TO_RUN as well. 
		READY_TO_RUN="TRUE";
fi;

# If we are READY_TO_RUN, let's start OVERNET. Otherwise, let's exit with error code 1. 
if [ "$READY_TO_RUN" = "TRUE" ];
	then	# Start unfreezer.check in detached mode. It will run in background and wake us up
		# if we become frozen due to a freeze in the OVERNET process.
		./unfreezer.check > unfreezer.log 2>&1 &

		# Start the OVERNET loop which will be interrupted only by the unfreezer.check script. 
		# If unfreezer.check detects a freeze, it will kill the OVERNET child process and 
		# unfreezer.sh will return to the loop (and restart OVERNET after a break). 
		while true;
			do	# Make sure OVERNET won't be killed during startup.
				touch $OVERNET_DIR/log.txt;

				# Startup. Let's assume there are no problems with ports being occupied. 
				echo `date` "Starting OVERNET.";
				# "time" will display how long OVERNET was up when it terminates.
				time $OVERNET_DIR/$OVERNET;

				# No matter what, OVERNET is dead if/when we are here. So lets revive it!
				# Wait a while for all TCP connections to timeout, then restart.
				echo `date` "OVERNET has died.";
				echo `date` "Sleeping 30 seconds to allow you to abort (Ctrl-C)..." && sleep 30

				#####################################################################################
				# This piece of code was donated by LinuxFreak :) - I modified it a tiny bit ;)     #
				echo `date` "I'll check if there are any open connections left..."
				while true;
					do
						#Get the amount of open connections...(for tcp-Port)
						tcp=$(netstat -n|grep $OVERNET_TCP_PORT |wc|awk '{print $1}')
						#So, we have to check if there are any tcp-connections left...
						if [ $tcp -eq "0" ]
							then
								#If there aren't any, we can go on...   
								break
						fi
						#First, we have to wait for 30 sec. I think this is ok...(and no output, because it's disturbing. ;-)
						sleep 30
					#And again a new loop...
					done;
					echo `date` "Ok, no more connections open..."
				# End of LinuxFreak's code							     #
				######################################################################################

			done;
	else	# For some reason, we could not reach a state that allows us to run safely. Perhaps the username is wrong?
		echo `date` "UnFreezer can not run as $OVERNET_USER - please doublecheck the username/config!";
		echo `date` "Shutting down UnFreezer.";
		exit 1;
fi;

