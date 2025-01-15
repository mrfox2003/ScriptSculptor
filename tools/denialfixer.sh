#!/bin/bash

# Usage: ./fix_sepolicy.sh <log_file>
# Example: ./fix_sepolicy.sh denial.log

if [ $# -ne 1 ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi

LOG_FILE=$1

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file not found!"
    exit 1
fi

# Output SEPolicy fixes
echo "Generating SEPolicy fixes from $LOG_FILE..."
echo ""

# Initialize an empty array to keep track of unique fixes
declare -A fixes

# Process each line with denial
grep "avc:  denied" "$LOG_FILE" | while read -r line; do
    scontext=$(echo "$line" | sed -n 's/.*scontext=u:r:\([^:]*\):s0.*/\1/p')
    tcontext=$(echo "$line" | sed -n 's/.*tcontext=u:object_r:\([^:]*\):s0.*/\1/p')
    tclass=$(echo "$line" | sed -n 's/.*tclass=\([^ ]*\).*/\1/p')
    permission=$(echo "$line" | sed -n 's/.*{ \(.*\) }.*/\1/p')

    # Create a unique key to identify each fix
    key="${scontext}_${tcontext}_${tclass}_${permission}"

    if [[ -z "${fixes[$key]}" ]]; then
        # If this fix hasn't been seen before, output it and mark as seen
        if [[ $tcontext == *"prop"* ]]; then
            if [[ $permission == *"set"* ]]; then
                fixes[$key]="set_prop($scontext, $tcontext)"
            elif [[ $permission == *"get"* ]]; then
                fixes[$key]="get_prop($scontext, $tcontext)"
            fi
        else
            fixes[$key]="allow $scontext $tcontext:$tclass { $permission };"
        fi
        echo "${fixes[$key]}"
    fi
done

echo ""
echo "SEPolicy fixes generated. Add these to the appropriate .te files."
