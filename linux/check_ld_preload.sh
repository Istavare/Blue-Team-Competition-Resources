#!/usr/bin/env bash

#Run with the command "source ./Check_LD_Preload.sh" so it impacts current environment

LOGFILE="/tmp/ld_preload_log.txt"

if [[ -n "$LD_PRELOAD" ]]; then
    echo "LD_PRELOAD detected: $LD_PRELOAD"
    
    # Save the value before removing it
    SAVED_LD_PRELOAD="$LD_PRELOAD"

    # Append to a logfile
    echo "$(date): $LD_PRELOAD" >> "$LOGFILE"

    # Unset the variable
    unset LD_PRELOAD

    echo "LD_PRELOAD unset. Logged original value to $LOGFILE"
else
    echo "LD_PRELOAD not set." >> $LOGFILE
fi