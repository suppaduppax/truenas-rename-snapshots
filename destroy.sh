DRY_RUN=1
LIST_ONLY=0
PRUNE_HEAD=1
PRUNE_TAIL=2
PRUNE_INVERSE_HEAD=3
PRUNE_INVERSE_TAIL=4

OPTSTRING=":d:fh:H:lm:rRt:T:"

while getopts ${OPTSTRING} opt; do
  case ${opt} in
    d)
      DAY_OF_WEEK="${OPTARG}"
      ;;
    f)
      DRY_RUN=0
      ;;
    h)
      # Destroy the specified number of snapshots starting at the head of the list
      PRUNE_TYPE="${PRUNE_HEAD}"
      PRUNE_AMOUNT="${OPTARG}"
      ;;
    H)
      # Keep the specified number of snapshots starting at the head of the list
      # and destroy the rest. This is an inverse of -h. 
      PRUNE_TYPE="${PRUNE_INVERSE_HEAD}"
      PRUNE_AMOUNT="${OPTARG}"
      ;;
    l)
      LIST_ONLY=1
      ;;
    m)
      PIPE="${PIPE} | grep ${OPTARG}"
      ;;
    r)
      EXTRA_OPTS="${EXTRA_OPTS} -r"
      ;;
    R)
      # use recursive rename
      ZFS_EXTRA_OPTS="${ZFS_EXTRA_OPTS} -r"
      ;;
    t)
      # Destroy the specified number of snapshots starting at the tail of the list
      PRUNE_TYPE="${PRUNE_TAIL}"
      PRUNE_AMOUNT="${OPTARG}"
      ;;
    T)
      # Keep the specified number of snapshots starting at the tail of the list
      # and destroy the rest. This is an inverse of -t. 
      PRUNE_TYPE="${PRUNE_INVERSE_TAIL}"
      PRUNE_AMOUNT="${OPTARG}"
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
    
  esac
done

shift $((OPTIND-1))

dryrun_wrapper () {
  printf "$1\n"
  [ ${DRY_RUN} -eq 0 ] && eval $1
}

match_day_of_week () {
  date=$(printf '%s' "$1" | grep -o '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')

  # cache the last checked date to prevent unecessary cURLs to find the day of the week

  if [ -z "${cached_date}" ] || [ "${cached_date}" != "${date}" ]; then
    date_to_curl=$(printf '%s' "$date" | awk '{ gsub(/-/, " "); print $2,$3,$1 }' | awk '{ gsub(/ /, "%2F"); print }')

    curl_dow=$(curl -s "http://www.calculator.net/day-of-the-week-calculator.html?today=${date_to_curl}&x=Calculate")
    dow_word=$(printf '%s' "$curl_dow" | grep -o "is a [a-z]*" | head -n 1 | awk '{ print $3 }')

    if [ "${dow_word}" = "Sunday" ]; then
      dow=0
    elif [ "${dow_word}" = "Monday" ]; then
      dow=1
    elif [ "${dow_word}" = "Tuesday" ]; then
      dow=2
    elif [ "${dow_word}" = "Wednesday" ]; then
      dow=3
    elif [ "${dow_word}" = "Thursday" ]; then
      dow=4
    elif [ "${dow_word}" = "Friday" ]; then
      dow=5
    elif [ "${dow_word}" = "Saturday" ]; then
      dow=6
    fi
  fi

  cached_date="${date}"

  if [ "${DAY_OF_WEEK}" -ne "${dow}" ]; then
    return 1
  fi

  return 0
}

if [ ${DRY_RUN} -ne 0 ]; then 
  ZFS_EXTRA_OPTS="${ZFS_EXTRA_OPTS} -n"
fi

DATASET=$1
KEEP=$2

snapshots=$(eval "zfs list -H -t snapshot -o name -S creation ${DATASET}${PIPE}")
total=$(echo "${snapshots}" | wc -l | awk '{$1=$1;print}')

if [ ${PRUNE_TYPE} -eq ${PRUNE_HEAD} ]; then
  remaining=$(($total-${PRUNE_AMOUNT}))

  if [ "${remaining}" -lt 0 ]; then
    remaining=${total}
  fi
  [ ${remaining} -gt 0 ] && to_keep=$(printf "${snapshots}" | tail --lines=${remaining})
  [ ${PRUNE_AMOUNT} -gt 0 ] && to_prune=$(printf "${snapshots}" | head --lines=${PRUNE_AMOUNT})
  to_prune_amount="${PRUNE_AMOUNT}"

elif [ ${PRUNE_TYPE} -eq ${PRUNE_INVERSE_HEAD} ]; then
  remaining=$(($total-${PRUNE_AMOUNT}))

  if [ "${remaining}" -lt 0 ]; then
    remaining=${total}
  fi

  echo "remaining: $remaining"
  [ ${PRUNE_AMOUNT} -gt 0 ] && to_keep=$(printf "${snapshots}" | head --lines=${PRUNE_AMOUNT})
  [ ${remaining} -gt 0 ] && to_prune=$(printf "${snapshots}" | tail --lines=${remaining})
  to_prune_amount=$(printf "${to_prune}" | wc -l)

elif [ ${PRUNE_TYPE} -eq ${PRUNE_TAIL} ]; then
  remaining=$(($total-${PRUNE_AMOUNT}))

  if [ "${remaining}" -lt 0 ]; then
    remaining=${total}
  fi

  [ ${remaining} -gt 0 ] && to_keep=$(printf "${snapshots}" | head --lines=${remaining})
  [ ${PRUNE_AMOUNT} -gt 0 ] && to_prune=$(printf "${snapshots}" | tail --lines=${PRUNE_AMOUNT})
  to_prune_amount="${PRUNE_AMOUNT}"

elif [ ${PRUNE_TYPE} -eq ${PRUNE_INVERSE_TAIL} ]; then
  remaining=$(($total-${PRUNE_AMOUNT}))

  if [ "${remaining}" -lt 0 ]; then
    remaining=${total}
  fi

  [ ${PRUNE_AMOUNT} -gt 0 ] && to_keep=$(printf "${snapshots}" | tail --lines=${PRUNE_AMOUNT})
  [ ${remaining} -gt 0 ] && to_prune="$(printf "${snapshots}" | head --lines=${remaining})"
  to_prune_amount=$(printf "${to_prune}" | wc -l)
fi

if [ "${LIST_ONLY}" -eq 1 ]; then
  printf "Keeping:\n%s\n" "${to_keep}"
  printf "Destroying:\n%s\n" "${to_prune}"
  printf "Destroying %s/%s snapshots\n" "${to_prune_amount}" "${total}"

else
  printf "Destroying %s/%s snapshots\n" "${to_prune_amount}" "${total}"
  printf "${to_prune}" | xargs -n 1 zfs destroy -p${ZFS_EXTRA_OPTS}
  
  if [ "${DRY_RUN}" -ne 0 ]; then
    printf "Dry-run mode activated. Use option -f to actually execute script.\n"
  fi
fi

