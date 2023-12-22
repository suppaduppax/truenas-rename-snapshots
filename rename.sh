DRY_RUN=1
LIST_ONLY=0

OPTSTRING=":d:flr:o:"

while getopts ${OPTSTRING} opt; do
  case ${opt} in
    d)
      shift
      DAY_OF_WEEK="$1"
      shift
      ;;
    f)
      shift
      DRY_RUN=0
      ;;
    l)
      shift
      LIST_ONLY=1
      ;;
    o)
      shift
      OUTPUT_FILE="$1"
      ;;
    r)
      shift
      REGEX="$1"
      shift
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

MATCH=$2
REPLACE=$3

if [ ! -z ${REGEX} ]; then
  SNAPSHOTS=$(zfs list -H -t snapshot -o name -S creation -r $1 | grep "${REGEX}")
elif [ ! -z "${DAY_OF_WEEK}" ]; then
  SNAPSHOTS=$(zfs list -H -t snapshot -o name -S creation -r $1)
fi

if [ "${LIST_ONLY}" -eq 1 ]; then
  SNAPSHOTS=$(zfs list -H -t snapshot -o name -S creation -r $1 | grep "${REGEX}")
  echo "${SNAPSHOTS}"
  exit 0
fi

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

for snapshot in ${SNAPSHOTS}; do
  if [ ! -z "${DAY_OF_WEEK}" ]; then
    match_day_of_week "${snapshot}" "${DAY_OF_WEEK}"
    if [ $? -eq 1 ]; then
      continue
    fi 
  fi
  new_snapshot=$(printf ${snapshot} | awk "{ gsub(/${MATCH}/,\"${REPLACE}\"); print }")
  dryrun_wrapper "zfs rename ${snapshot} ${new_snapshot}"
done
