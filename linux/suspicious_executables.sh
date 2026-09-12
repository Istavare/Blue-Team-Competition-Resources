#!/bin/bash

SEARCH_PATHS=(
    /home
    /tmp
    /var
    /opt
    /mnt
    /root
    /media
    /srv
)

for path in "${SEARCH_PATHS[@]}"; do
  if [[ "$path" == "/var" ]]; then
    find /var \
      -path /var/lib -prune -o \
      -type f -perm /111 \
      -printf '%p | %f | %TY-%Tm-%Td %TH:%TM:%TS\n' 2>/dev/null
    
  else
    find "$path" \
      -type f -perm /111 \
      -printf '%p | %f | %TY-%Tm-%Td %TH:%TM:%TS\n' 2>/dev/null

  fi
done
