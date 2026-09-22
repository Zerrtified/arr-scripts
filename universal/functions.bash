log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1 >> "/config/logs/$logFileName"
}

logfileSetup () {
  logFileName="$scriptName-$(date +"%Y_%m_%d_%I_%M_%p").txt"

  # Keep only the last 2 log files for 3 active log files at any given time...
  rm -f $(ls -1t /config/logs/$scriptName-* | tail -n +2)
  # delete log files older than 5 days
  find "/config/logs" -type f -iname "$scriptName-*.txt" -mtime +5 -delete
  
  if [ ! -f "/config/logs/$logFileName" ]; then
    echo "" > "/config/logs/$logFileName"
    chmod 666 "/config/logs/$logFileName"
  fi
}

getArrAppInfo () {
  # Get Arr App information
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    local xml_file="/config/config.xml"

    # Helper function to extract XML tags safely using grep/sed
    extract_tag() {
      local tag="$1"
      grep -oPm1 "(?<=<${tag}>)[^<]+" "$xml_file" 2>/dev/null || echo ""
    }

    local raw_urlbase
    raw_urlbase=$(extract_tag "UrlBase")
    if [ -z "$raw_urlbase" ] || [ "$raw_urlbase" == "null" ]; then
      arrUrlBase=""
    else
      arrUrlBase="/$(echo "$raw_urlbase" | sed "s/\///g")"
    fi

    arrName=$(extract_tag "InstanceName")
    [ -z "$arrName" ] && arrName="Arr"

    arrApiKey=$(extract_tag "ApiKey")

    arrPort=$(extract_tag "Port")
    [ -z "$arrPort" ] && arrPort="8989"

    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi
}

verifyApiAccess () {
  until false
  do
    arrApiTest=""
    arrApiVersion=""
    if [ -z "$arrApiTest" ]; then
      arrApiVersion="v3"
      arrApiTest="$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)"
    fi
    if [ -z "$arrApiTest" ]; then
      arrApiVersion="v1"
      arrApiTest="$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)"
    fi
    if [ ! -z "$arrApiTest" ]; then
      break
    else
      log "$arrName is not ready, sleeping until valid response..."
      sleep 1
    fi
  done
}

ConfValidationCheck () {
  if [ ! -f "/config/extended.conf" ]; then
    log "ERROR :: \"extended.conf\" file is missing..."
    log "ERROR :: Download the extended.conf config file and place it into \"/config\" folder..."
    log "ERROR :: Exiting..."
    exit
  fi
  if [ -z "$enableAutoConfig" ]; then
    log "ERROR :: \"extended.conf\" file is unreadable..."
    log "ERROR :: Likely caused by editing with a non unix/linux compatible editor, to fix, replace the file with a valid one or correct the line endings..."
    log "ERROR :: Exiting..."
    exit
  fi
}

logfileSetup
ConfValidationCheck
