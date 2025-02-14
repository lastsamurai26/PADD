#!/usr/bin/env sh
# shellcheck disable=SC1091

# PADD
#
# A more advanced version of the chronometer provided with Pihole

# SETS LOCALE
# Issue 5: https://github.com/jpmck/PADD/issues/5
# Updated to en_US to support
# export LC_ALL=en_US.UTF-8 > /dev/null 2>&1 || export LC_ALL=en_GB.UTF-8 > /dev/null 2>&1 || export LC_ALL=C.UTF-8 > /dev/null 2>&1
LC_ALL=C
LC_NUMERIC=C

# cd to the directory this script is stored in
# creates a new local temp directory /tmp/padd_uid
tmpdir=$(dirname "$(mktemp -u)")
mkdir -p "$tmpdir/padd_$(id -u)/"

# change into the newly created directory
oldpath=$(pwd)
cd "$tmpdir/padd_$(id -u)/" > /dev/null || {
    EC=$?
    echo >&2 "Could not chdir to the temp directory (exit code $EC)"
    exit $EC
}

############################################ VARIABLES #############################################

# VERSION
padd_version="v3.7.1"

# DATE
today=$(date +%Y%m%d)

# CORES
core_count=1
core_count=$(cat /sys/devices/system/cpu/kernel_max 2> /dev/null)+1

# Get Config variables
. /etc/pihole/setupVars.conf

piHoleVersion_file="./piHoleVersion"


# COLORS
CSI="$(printf '\033')["
red_text="${CSI}91m"     # Red
green_text="${CSI}92m"   # Green
yellow_text="${CSI}93m"  # Yellow
blue_text="${CSI}94m"    # Blue
magenta_text="${CSI}95m" # Magenta
cyan_text="${CSI}96m"    # Cyan
reset_text="${CSI}0m"    # Reset to default

# STYLES
bold_text="${CSI}1m"
blinking_text="${CSI}5m"
dim_text="${CSI}2m"

# CHECK BOXES
check_box_good="[${green_text}✓${reset_text}]"       # Good
check_box_bad="[${red_text}✗${reset_text}]"          # Bad
check_box_question="[${yellow_text}?${reset_text}]"  # Question / ?
check_box_info="[${yellow_text}i${reset_text}]"      # Info / i

# PICO STATUSES
pico_status_ok="${check_box_good} Sys. OK"
pico_status_update="${check_box_info} Update"
pico_status_hot="${check_box_bad} Sys. Hot!"
pico_status_off="${check_box_bad} Offline"
pico_status_ftl_down="${check_box_info} FTL Down"
pico_status_dns_down="${check_box_bad} DNS Down"
pico_status_unknown="${check_box_question} Stat. Unk."

# MINI STATUS
mini_status_ok="${check_box_good} System OK"
mini_status_update="${check_box_info} Update avail."
mini_status_hot="${check_box_bad} System is hot!"
mini_status_off="${check_box_bad} Pi-hole off!"
mini_status_ftl_down="${check_box_info} FTL down!"
mini_status_dns_down="${check_box_bad} DNS off!"
mini_status_unknown="${check_box_question} Status unknown"

# REGULAR STATUS
full_status_ok="${check_box_good} System is healthy."
full_status_update="${check_box_info} Updates are available."
full_status_hot="${check_box_bad} System is hot!"
full_status_off="${check_box_bad} Pi-hole is offline"
full_status_ftl_down="${check_box_info} FTL is down!"
full_status_dns_down="${check_box_bad} DNS is off!"
full_status_unknown="${check_box_question} Status unknown!"

# MEGA STATUS
mega_status_ok="${check_box_good} Your system is healthy."
mega_status_update="${check_box_info} Updates are available."
mega_status_hot="${check_box_bad} Your system is hot!"
mega_status_off="${check_box_bad} Pi-hole is offline."
mega_status_ftl_down="${check_box_info} FTLDNS service is not running."
mega_status_dns_down="${check_box_bad} Pi-hole's DNS server is off!"
mega_status_unknown="${check_box_question} Unable to determine Pi-hole status."

# TINY STATUS
tiny_status_ok="${check_box_good} System is healthy."
tiny_status_update="${check_box_info} Updates are available."
tiny_status_off="${check_box_bad} Pi-hole is offline"
tiny_status_ftl_down="${check_box_info} FTL is down!"
tiny_status_dns_down="${check_box_bad} DNS is off!"
tiny_status_unknown="${check_box_question} Status unknown!"

# Text only "logos"
padd_text="${green_text}${bold_text}PADD${reset_text}"

# PADD logos - regular and retro
padd_logo_1="${bold_text}${green_text} __      __  __   ${reset_text}"
padd_logo_2="${bold_text}${green_text}|__) /\\ |  \\|  \\  ${reset_text}"
padd_logo_3="${bold_text}${green_text}|   /--\\|__/|__/  ${reset_text}"
padd_logo_retro_1="${bold_text} ${yellow_text}_${green_text}_      ${blue_text}_${magenta_text}_  ${yellow_text}_${green_text}_   ${reset_text}"
padd_logo_retro_2="${bold_text}${yellow_text}|${green_text}_${blue_text}_${cyan_text}) ${red_text}/${yellow_text}\\ ${blue_text}|  ${red_text}\\${yellow_text}|  ${cyan_text}\\  ${reset_text}"
padd_logo_retro_3="${bold_text}${green_text}|   ${red_text}/${yellow_text}-${green_text}-${blue_text}\\${cyan_text}|${magenta_text}_${red_text}_${yellow_text}/${green_text}|${blue_text}_${cyan_text}_${magenta_text}/  ${reset_text}"

############################################# GETTERS ##############################################

GetFTLData() {
    ftl_port=$(cat /run/pihole-FTL.port 2> /dev/null)
    if [ -n "$ftl_port" ]; then
      # Send command to FTL and ask to quit when finished
      echo ">$1 >quit" | nc 127.0.0.1 "${ftl_port}"
    else
           echo "0"
    fi
}

GetSummaryInformation() {
  summary=$(GetFTLData "stats")
  cache_info=$(GetFTLData "cacheinfo")

  clients=$(echo "${summary}" | grep "unique_clients" | grep -Eo "[0-9]+$")

  blocking_status=$(echo "${summary}" | grep "status" | grep -Eo "enabled|disabled|unknown" )

  domains_being_blocked_raw=$(echo "${summary}" | grep "domains_being_blocked" | grep -Eo "[0-9]+$")
  domains_being_blocked=$(printf "%.f" "${domains_being_blocked_raw}")

  dns_queries_today_raw=$(echo "$summary" | grep "dns_queries_today" | grep -Eo "[0-9]+$")
  dns_queries_today=$(printf "%.f" "${dns_queries_today_raw}")

  ads_blocked_today_raw=$(echo "$summary" | grep "ads_blocked_today" | grep -Eo "[0-9]+$")
  ads_blocked_today=$(printf "%.f" "${ads_blocked_today_raw}")

  ads_percentage_today_raw=$(echo "$summary" | grep "ads_percentage_today" | grep -Eo "[0-9.]+$")
  ads_percentage_today=$(printf "%.1f" "${ads_percentage_today_raw}")
  cache_size=$(echo "$cache_info" | grep "cache-size" | grep -Eo "[0-9.]+$")
  cache_deletes=$(echo "$cache_info" | grep "cache-live-freed" | grep -Eo "[0-9.]+$")
  cache_inserts=$(echo "$cache_info"| grep "cache-inserted" | grep -Eo "[0-9.]+$")


  latest_blocked=$(GetFTLData recentBlocked)

  top_blocked=$(GetFTLData "top-ads (1)" | awk '{print $3}')

  top_domain=$(GetFTLData "top-domains (1)" | awk '{print $3}')

  top_client_raw=$(GetFTLData "top-clients (1)" | awk '{print $4}')
  if [ -z "${top_client_raw}" ]; then
    top_client=$(GetFTLData "top-clients (1)" | awk '{print $3}')
  else
    top_client="${top_client_raw}"
  fi

  if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 10 "color")
  elif [ "$1" = "mini" ]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 20 "color")

    if [ ${#latest_blocked} -gt 30 ]; then
      latest_blocked=$(echo "$latest_blocked" | cut -c1-27)"..."
    fi

    if [ ${#top_blocked} -gt 30 ]; then
      top_blocked=$(echo "$top_blocked" | cut -c1-27)"..."
    fi
  elif [ "$1" = "tiny" ]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 30 "color")

    if [ ${#latest_blocked} -gt 38 ]; then
      latest_blocked=$(echo "$latest_blocked" | cut -c1-38)"..."
    fi

    if [ ${#top_blocked} -gt 38 ]; then
      top_blocked=$(echo "$top_blocked" | cut -c1-38)"..."
    fi

    if [ ${#top_domain} -gt 38 ]; then
      top_domain=$(echo "$top_domain" | cut -c1-38)"..."
    fi

    if [ ${#top_client} -gt 38 ]; then
      top_client=$(echo "$top_client" | cut -c1-38)"..."
    fi
  elif [ "$1" = "regular" ] || [ "$1" = "slim" ]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 40 "color")
  else
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 30 "color")
  fi
}

GetSystemInformation() {
  # System uptime
  if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
    system_uptime=$(uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/){if ($9=="min") {d=$6;m=$8} else {d=$6;h=$8;m=$9}} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours"}')
  else
    system_uptime=$(uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/){if ($9=="min") {d=$6;m=$8} else {d=$6;h=$8;m=$9}} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')
  fi

  # CPU temperature
  if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    cpu=$(cat /sys/class/thermal/thermal_zone0/temp)
  elif [ -f /sys/class/hwmon/hwmon0/temp1_input ]; then
    cpu=$(cat /sys/class/hwmon/hwmon0/temp1_input)
  else
    cpu=0
  fi

  # Convert CPU temperature to correct unit
  if [ "${TEMPERATUREUNIT}" = "F" ]; then
    temperature="$(printf %.1f "$(echo "${cpu}" | awk '{print $1 * 9 / 5000 + 32}')")°F"
  elif [ "${TEMPERATUREUNIT}" = "K" ]; then
    temperature="$(printf %.1f "$(echo "${cpu}" | awk '{print $1 / 1000 + 273.15}')")°K"
  # Addresses Issue 1: https://github.com/jpmck/PAD/issues/1
  else
    temperature="$(printf %.1f "$(echo "${cpu}" | awk '{print $1 / 1000}')")°C"
  fi

  # CPU load, heatmap
  cpu_load_1=$(awk '{print $1}' < /proc/loadavg)
  cpu_load_5=$(awk '{print $2}' < /proc/loadavg)
  cpu_load_15=$(awk '{print $3}' < /proc/loadavg)
  cpu_load_1_heatmap=$(HeatmapGenerator "${cpu_load_1}" "${core_count}")
  cpu_load_5_heatmap=$(HeatmapGenerator "${cpu_load_5}" "${core_count}")
  cpu_load_15_heatmap=$(HeatmapGenerator "${cpu_load_15}" "${core_count}")
  cpu_percent=$(printf %.1f "$(echo "${cpu_load_1} ${core_count}" | awk '{print ($1 / $2) * 100}')")

  # CPU temperature heatmap
  # If we're getting close to 85°C... (https://www.raspberrypi.org/blog/introducing-turbo-mode-up-to-50-more-performance-for-free/)
  if [ ${cpu} -gt 80000 ]; then
    temp_heatmap=${blinking_text}${red_text}
    pico_status="${pico_status_hot}"
    mini_status_="${mini_status_hot} ${blinking_text}${red_text}${temperature}${reset_text}"
    full_status_="${full_status_hot} ${blinking_text}${red_text}${temperature}${reset_text}"
    mega_status="${mega_status_hot} ${blinking_text}${red_text}${temperature}${reset_text}"
  elif [ ${cpu} -gt 70000 ]; then
    temp_heatmap=${magenta_text}
  elif [ ${cpu} -gt 60000 ]; then
    temp_heatmap=${blue_text}
  else
    temp_heatmap=${cyan_text}
  fi

  # Memory use, heatmap and bar
  memory_percent=$(awk '/MemTotal:/{total=$2} /MemFree:/{free=$2} /Buffers:/{buffers=$2} /^Cached:/{cached=$2} END {printf "%.1f", (total-free-buffers-cached)*100/total}' '/proc/meminfo')
  memory_heatmap=$(HeatmapGenerator "${memory_percent}")

  #  Bar generations
  if [ "$1" = "mini" ]; then
    cpu_bar=$(BarGenerator "${cpu_percent}" 20)
    memory_bar=$(BarGenerator "${memory_percent}" 20)
  elif [ "$1" = "tiny" ]; then
    cpu_bar=$(BarGenerator "${cpu_percent}" 7)
    memory_bar=$(BarGenerator "${memory_percent}" 7)
  else
    cpu_bar=$(BarGenerator "${cpu_percent}" 10)
    memory_bar=$(BarGenerator "${memory_percent}" 10)
  fi
}

GetNetworkInformation() {
  # Get pi IPv4 address
  pi_ip4_addrs="$(ip addr | grep 'inet ' | grep -v '127.0.0.1/8' | awk '{print $2}' | cut -f1 -d'/' |wc -l)"
  if [ "${pi_ip4_addrs}" -eq 0 ]; then
    # No IPv4 address available
    pi_ip4_addr="N/A"
  elif [ "${pi_ip4_addrs}" -eq 1 ]; then
    # One IPv4 address available
    pi_ip4_addr="$(ip addr | grep 'inet ' | grep -v '127.0.0.1/8' | awk '{print $2}' | cut -f1 -d'/' | head -n 1)"
  else
    # More than one IPv4 address available
    pi_ip4_addr="$(ip addr | grep 'inet ' | grep -v '127.0.0.1/8' | awk '{print $2}' | cut -f1 -d'/' | head -n 1)+"
  fi

  # Get pi IPv6 address
  pi_ip6_addrs="$(ip addr | grep 'inet6 ' | grep -v '::1/128' | awk '{print $2}' | cut -f1 -d'/' | wc -l)"
  if [ "${pi_ip6_addrs}" -eq 0 ]; then
    # No IPv6 address available
    pi_ip6_addr="N/A"
  elif [ "${pi_ip6_addrs}" -eq 1 ]; then
    # One IPv6 address available
    pi_ip6_addr="$(ip addr | grep 'inet6 ' | grep -v '::1/128' | awk '{print $2}' | cut -f1 -d'/' | head -n 1)"
  else
    # More than one IPv6 address available
    pi_ip6_addr="$(ip addr | grep 'inet6 ' | grep -v '::1/128' | awk '{print $2}' | cut -f1 -d'/' | head -n 1)+"
  fi

  # Get hostname and gateway
  pi_hostname=$(hostname)
  pi_gateway=$(ip r | grep 'default' | awk '{print $3}')

  full_hostname=${pi_hostname}
  # does the Pi-hole have a domain set?
  if [ -n "${PIHOLE_DOMAIN+x}" ]; then
    # is Pi-hole acting as DHCP server?
    if [ "${DHCP_ACTIVE}" = "true" ]; then
      count=${pi_hostname}"."${PIHOLE_DOMAIN}
      count=${#count}
      if [ "${count}" -lt "18" ]; then
        full_hostname=${pi_hostname}"."${PIHOLE_DOMAIN}
      fi
    fi
  fi

#######################
    if command -v vcgencmd >/dev/null 2>&1; then
        local sys_throttle_raw
        local sys_rev_raw

        sys_throttle_raw=$(vgt=$(sudo vcgencmd get_throttled); echo "${vgt##*x}")

        # Active Throttle Notice: https://bit.ly/2gnunOo
        if [ "$sys_throttle_raw" != "0" ]; then
            case "$sys_throttle_raw" in
                *0001) thr_type="${COL_YELLOW}Under Voltage";;
                *0002) thr_type="${COL_LIGHT_BLUE}Arm Freq Cap";;
                *0003) thr_type="${COL_YELLOW}UV${COL_DARK_GRAY},${COL_NC} ${COL_LIGHT_BLUE}AFC";;
                *0004) thr_type="${COL_LIGHT_RED}Throttled";;
                *0005) thr_type="${COL_YELLOW}UV${COL_DARK_GRAY},${COL_NC} ${COL_LIGHT_RED}TT";;
                *0006) thr_type="${COL_LIGHT_BLUE}AFC${COL_DARK_GRAY},${COL_NC} ${COL_LIGHT_RED}TT";;
                *0007) thr_type="${COL_YELLOW}UV${COL_DARK_GRAY},${COL_NC} ${COL_LIGHT_BLUE}AFC${COL_DARK_GRAY},${COL_NC} ${COL_LIGHT_RED}TT";;
            esac
        [ -n "$thr_type" ] && sys_throttle="$thr_type${COL_DARK_GRAY}"
        fi

sys_rev_raw=$(awk '/Revision/ {print $3}' < /proc/cpuinfo)
        case "$sys_rev_raw" in
            000[2-6]) sys_model=" 1, Model B";; # 256MB
            000[7-9]) sys_model=" 1, Model A";; # 256MB
            000d|000e|000f) sys_model=" 1, Model B";; # 512MB
            0010|0013) sys_model=" 1, Model B+";; # 512MB
            0012|0015) sys_model=" 1, Model A+";; # 256MB
            a0104[0-1]|a21041|a22042) sys_model=" 2, Model B";; # 1GB
            900021) sys_model=" 1, Model A+";; # 512MB
            900032) sys_model=" 1, Model B+";; # 512MB
            90009[2-3]|920093) sys_model=" Zero";; # 512MB
            9000c1) sys_model=" Zero W";; # 512MB
            a02082|a[2-3]2082) sys_model=" 3, Model B";; # 1GB
            a020d3) sys_model=" 3, Model B+";; # 1GB
            *) sys_model="";;
        esac
        sys_type="Raspberry Pi$sys_model"
    else
        . "/etc/os-release"
        # remove parenthesis and only print second substring
        CODENAME=$(echo "${VERSION}"| sed 's/[()]//g' | awk '{print $2}')

        # only print first substring of NAME and make first character of CODENAME uppercase
        sys_type=$(echo "${NAME}" | awk '{print $1}')
        CODENAME=$(echo "$CODENAME" | sed 's/./\U&/')
        sys_type="${sys_type} ${CODENAME} $VERSION_ID"
    fi
#################

  # Get the DNS count (from pihole -c)
  dns_count="0"
  [ -n "${PIHOLE_DNS_1}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_2}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_3}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_4}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_5}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_6}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_7}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_8}" ] && dns_count=$((dns_count+1))
  [ -n "${PIHOLE_DNS_9}" ] && dns_count=$((dns_count+1))

  # if there's only one DNS server
  if [ ${dns_count} -eq 1 ]; then
    if [ "${PIHOLE_DNS_1}" = "127.0.0.1#5053" ]; then
      dns_information="1 server (Cloudflared)"
    elif [ "${PIHOLE_DNS_1}" = "${pi_gateway}#53" ]; then
      dns_information="1 server (gateway)"
    else
      dns_information="1 server"
    fi
  elif [ ${dns_count} -gt 8 ]; then
    dns_information="8+ servers"
  else
    dns_information="${dns_count} servers"
  fi

  # Is Pi-Hole acting as the DHCP server?
  if [ "${DHCP_ACTIVE}" = "true" ]; then
    dhcp_status="Enabled"
    dhcp_info=" Range:    ${DHCP_START} - ${DHCP_END}"
    dhcp_heatmap=${green_text}
    dhcp_check_box=${check_box_good}

    # Is DHCP handling IPv6?
    # DHCP_IPv6 is set in setupVars.conf
    # shellcheck disable=SC2154
    if [ "${DHCP_IPv6}" = "true" ]; then
      dhcp_ipv6_status="Enabled"
      dhcp_ipv6_heatmap=${green_text}
      dhcp_ipv6_check_box=${check_box_good}
    else
      dhcp_ipv6_status="Disabled"
      dhcp_ipv6_heatmap=${red_text}
      dhcp_ipv6_check_box=${check_box_bad}
    fi
  else
    dhcp_status="Disabled"
    dhcp_heatmap=${red_text}
    dhcp_check_box=${check_box_bad}

    # if the DHCP Router variable isn't set
    # Issue 3: https://github.com/jpmck/PADD/issues/3
    if [ -z ${DHCP_ROUTER+x} ]; then
      DHCP_ROUTER=$(/sbin/ip route | awk '/default/ { printf "%s\t", $3 }')
    fi

    dhcp_info=" Router:   ${DHCP_ROUTER}"
    dhcp_heatmap=${red_text}
    dhcp_check_box=${check_box_bad}

    dhcp_ipv6_status="N/A"
    dhcp_ipv6_heatmap=${yellow_text}
    dhcp_ipv6_check_box=${check_box_question}
  fi

  # DNSSEC
  if [ "${DNSSEC}" = "true" ]; then
    dnssec_status="Enabled"
    dnssec_heatmap=${green_text}
  else
    dnssec_status="Disabled"
    dnssec_heatmap=${red_text}
  fi

  # Conditional forwarding
  if [ "${CONDITIONAL_FORWARDING}" = "true" ] || [ "${REV_SERVER}" = "true" ]; then
    conditional_forwarding_status="Enabled"
    conditional_forwarding_heatmap=${green_text}
  else
    conditional_forwarding_status="Disabled"
    conditional_forwarding_heatmap=${red_text}
  fi
}

GetPiholeInformation() {
  # Get FTL status
  ftlPID=$(pidof pihole-FTL)

  if [ -z ${ftlPID+x} ]; then
    ftl_status="Not running"
    ftl_heatmap=${yellow_text}
    ftl_check_box=${check_box_info}
    pico_status=${pico_status_ftl_down}
    mini_status_=${mini_status_ftl_down}
    tiny_status_=${tiny_status_ftl_down}
    full_status_=${full_status_ftl_down}
    mega_status=${mega_status_ftl_down}
  else
    ftl_status="Running"
    ftl_heatmap=${green_text}
    ftl_check_box=${check_box_good}
    ftl_cpu="$(ps -p "${ftlPID}" -o %cpu | tail -n1 | tr -d '[:space:]')"
    ftl_mem_percentage="$(ps -p "${ftlPID}" -o %mem | tail -n1 | tr -d '[:space:]')"
  fi

  # Get Pi-hole (blocking) status
  ftl_dns_port=$(GetFTLData "dns-port")

  # ${ftl_dns_port} == 0 DNS server part of dnsmasq disabled, ${ftl_status} == "Not running" no ftlPID found
  if [ "${ftl_dns_port}" = 0 ] || [ "${ftl_status}" = "Not running" ]; then
    pihole_status="DNS Offline"
    pihole_heatmap=${red_text}
    pihole_check_box=${check_box_bad}
    pico_status=${pico_status_dns_down}
    mini_status_=${mini_status_dns_down}
    tiny_status_=${tiny_status_dns_down}
    full_status_=${full_status_dns_down}
    mega_status=${mega_status_dns_down}
  else
    if [ "${blocking_status}" = "enabled" ]; then
      pihole_status="Active"
      pihole_heatmap=${green_text}
      pihole_check_box=${check_box_good}
    fi
    if [ "${blocking_status}" = "disabled" ]; then
      pihole_status="Blocking disabled"
      pihole_heatmap=${red_text}
      pihole_check_box=${check_box_bad}
      pico_status=${pico_status_off}
      mini_status_=${mini_status_off}
      tiny_status_=${tiny_status_off}
      full_status_=${full_status_off}
      mega_status=${mega_status_off}
    fi
    if [ "${blocking_status}" = "unknown" ]; then
      pihole_status="Unknown"
      pihole_heatmap=${yellow_text}
      pihole_check_box=${check_box_question}
      pico_status=${pico_status_unknown}
      mini_status_=${mini_status_unknown}
      tiny_status_=${tiny_status_unknown}
      full_status_=${full_status_unknown}
      mega_status=${mega_status_unknown}
    fi
  fi

}

GetVersionInformation() {
  # Check if version status has been saved
  if [ -f "$piHoleVersion_file" ]; then # the file exists...
    # the file exits, use it
    # shellcheck source=./piHoleVersion
    . "$piHoleVersion_file"

    # Today is
    today=$(date +%Y%m%d)

    # was the last check today?
    # last_check is read from ./piHoleVersion
    # shellcheck disable=SC2154
    if [ "${today}" != "${last_check}" ]; then # no, it wasn't today
      # Remove the Pi-hole version file...
      rm -f "$piHoleVersion_file"
    fi

  else # the file doesn't exist, create it...
    # Gather core version information...
    core_version=$(pihole -v -p | awk '{print $4}' | tr -d '[:alpha:]')
    core_version_latest=$(pihole -v -p | awk '{print $6}' | tr -d ')')


    if [ "${core_version_latest}" = "ERROR" ]; then
      core_version_heatmap=${yellow_text}
    else
      core_version_latest=$(echo "${core_version_latest}" | tr -d '\r\n[:alpha:]')
      # is core up-to-date?
      if [ "${core_version}" != "${core_version_latest}" ]; then
        out_of_date_flag="true"
        core_version_heatmap=${red_text}
      else
        core_version_heatmap=${green_text}
      fi
    fi

    # Gather web version information...
    if [ "$INSTALL_WEB_INTERFACE" = true ]; then
      web_version=$(pihole -v -a | awk '{print $4}' | tr -d '[:alpha:]')
      web_version_latest=$(pihole -v -a | awk '{print $6}' | tr -d ')')
      if [ "${web_version_latest}" = "ERROR" ]; then

        web_version_heatmap=${yellow_text}
      else
        web_version_latest=$(echo "${web_version_latest}" | tr -d '\r\n[:alpha:]')
        # is web up-to-date?
        if [ "${web_version}" != "${web_version_latest}" ]; then
          out_of_date_flag="true"
          web_version_heatmap=${red_text}
        else
          web_version_heatmap=${green_text}
        fi
      fi
    else
      # Web interface not installed
      web_version_heatmap=${red_text}
      web_version="$(printf '\x08')"  # Hex 0x08 is for backspace, to delete the leading 'v'
      web_version="${web_version}N/A" # N/A = Not Available
    fi

    # Gather FTL version information...
    ftl_version=$(pihole -v -f | awk '{print $4}' | tr -d '[:alpha:]')
    ftl_version_latest=$(pihole -v -f | awk '{print $6}' | tr -d ')')
    if [ "${ftl_version_latest}" = "ERROR" ]; then

      ftl_version_heatmap=${yellow_text}
    else
      ftl_version_latest=$(echo "${ftl_version_latest}" | tr -d '\r\n[:alpha:]')
      # is ftl up-to-date?
      if [ "${ftl_version}" != "${ftl_version_latest}" ]; then
        out_of_date_flag="true"
        ftl_version_heatmap=${red_text}
      else
        ftl_version_heatmap=${green_text}
      fi
    fi

    # PADD version information...
    padd_version_latest="$(curl --silent https://api.github.com/repos/pi-hole/PADD/releases/latest | grep '"tag_name":' | awk -F \" '{print $4}')"

    # is PADD up-to-date?
    if [ "${padd_version_latest}" = "" ]; then
      padd_version_heatmap=${yellow_text}
    else
      if [ "${padd_version}" != "${padd_version_latest}" ]; then
        padd_out_of_date_flag="true"
        padd_version_heatmap=${red_text}
      else
        padd_version_heatmap=${green_text}
      fi
    fi

    # was any portion of Pi-hole out-of-date?
    # yes, pi-hole is out of date
    if [ "${out_of_date_flag}" = "true" ]; then
      version_status="Pi-hole is out-of-date!"
      version_heatmap=${red_text}
      version_check_box=${check_box_bad}
      pico_status=${pico_status_update}
      mini_status_=${mini_status_update}
      tiny_status_=${tiny_status_update}
      full_status_=${full_status_update}
      mega_status=${mega_status_update}
    else
      # but is PADD out-of-date?
      if [ "${padd_out_of_date_flag}" = "true" ]; then
        version_status="PADD is out-of-date!"
        version_heatmap=${red_text}
        version_check_box=${check_box_bad}
        pico_status=${pico_status_update}
        mini_status_=${mini_status_update}
        tiny_status_=${tiny_status_update}
        full_status_=${full_status_update}
        mega_status=${mega_status_update}
      # else, everything is good!
      else
        version_status="Pi-hole is up-to-date!"
        version_heatmap=${green_text}
        version_check_box=${check_box_good}
        pico_status=${pico_status_ok}
        mini_status_=${mini_status_ok}
        tiny_status_=${tiny_status_ok}
        full_status_=${full_status_ok}
        mega_status=${mega_status_ok}
      fi
    fi

    # write it all to the file
    echo "last_check=${today}" > "$piHoleVersion_file"
    {
      echo "core_version=$core_version"
      echo "core_version_latest=$core_version_latest"
      echo "core_version_heatmap=$core_version_heatmap"

      echo "web_version=$web_version"
      echo "web_version_latest=$web_version_latest"
      echo "web_version_heatmap=$web_version_heatmap"

      echo "ftl_version=$ftl_version"
      echo "ftl_version_latest=$ftl_version_latest"
      echo "ftl_version_heatmap=$ftl_version_heatmap"

      echo "padd_version=$padd_version"
      echo "padd_version_latest=$padd_version_latest"
      echo "padd_version_heatmap=$padd_version_heatmap"

      echo "version_status=\"$version_status\""
      echo "version_heatmap=$version_heatmap"
      echo "version_check_box=\"$version_check_box\""

      echo "pico_status=\"$pico_status\""
      echo "mini_status_=\"$mini_status_\""
      echo "tiny_status_=\"$tiny_status_\""
      echo "full_status_=\"$full_status_\""
      echo "mega_status=\"$mega_status\""
    } >> "$piHoleVersion_file"

    # there's a file now
  fi
}

############################################# PRINTERS #############################################

# terminfo clr_eol (clears to end of line to erase artifacts after resizing smaller)
ceol=$(tput el)

# wrapper - echo with a clear eol afterwards to wipe any artifacts remaining from last print
CleanEcho() {
  echo "${ceol}$1"
}

# wrapper - printf
CleanPrintf() {
# tput el
# disabling shellcheck here because we pass formatting instructions within `"${@}"`
# shellcheck disable=SC2059
  printf "$@"
}

PrintLogo() {
  # Screen size checks
  if [ "$1" = "pico" ]; then
    CleanEcho "p${padd_text} ${pico_status}"
  elif [ "$1" = "nano" ]; then
    CleanEcho "n${padd_text} ${mini_status_}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "µ${padd_text}     ${mini_status_}"
    CleanEcho ""
  elif [ "$1" = "mini" ]; then
    CleanEcho "${padd_text}${dim_text}mini${reset_text}  ${mini_status_}"
    CleanEcho ""
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${padd_text}${dim_text}tiny${reset_text}   Pi-hole® ${core_version_heatmap}v${core_version}${reset_text}, Web ${web_version_heatmap}v${web_version}${reset_text}, FTL ${ftl_version_heatmap}v${ftl_version}${reset_text}"
    CleanPrintf "           PADD ${padd_version_heatmap}${padd_version}${reset_text} ${tiny_status_}${reset_text}\e[0K\\n"
  elif [ "$1" = "slim" ]; then
    CleanEcho "${padd_text}${dim_text}slim${reset_text}   ${full_status_}"
    CleanEcho ""
  # For the next two, use printf to make sure spaces aren't collapsed
  elif [ "$1" = "regular" ] || [ "$1" = "slim" ]; then
    CleanPrintf "${padd_logo_1}\e[0K\\n"
    CleanPrintf "${padd_logo_2}Pi-hole® ${core_version_heatmap}v${core_version}${reset_text}, Web ${web_version_heatmap}v${web_version}${reset_text}, FTL ${ftl_version_heatmap}v${ftl_version}${reset_text}\e[0K\\n"
  # CleanPrintf "${padd_logo_3}PADD ${padd_version_heatmap}${padd_version}${reset_text}${full_status_}${reset_text}\e[0K\\n"
    CleanPrintf "${padd_logo_3}PADD ${padd_version_heatmap}${padd_version}${reset_text}   ${full_status_}${reset_text}\e[0K\\n"
    CleanEcho ""
  # normal or not defined
  else
    CleanPrintf "${padd_logo_retro_1}\e[0K\\n"
    CleanPrintf "${padd_logo_retro_2}   Pi-hole® ${core_version_heatmap}v${core_version}${reset_text}, Web ${web_version_heatmap}v${web_version}${reset_text}, FTL ${ftl_version_heatmap}v${ftl_version}${reset_text}, PADD ${padd_version_heatmap}${padd_version}${reset_text}\e[0K\\n"
    CleanPrintf "${padd_logo_retro_3}   ${pihole_check_box} Core  ${ftl_check_box} FTL   ${mega_status}${reset_text}\e[0K\\n"

    CleanEcho ""
  fi
}

PrintNetworkInformation() {
  if [ "$1" = "pico" ]; then
    CleanEcho "${bold_text}NETWORK ============${reset_text}"
    CleanEcho " Hst: ${pi_hostname}"
    CleanEcho " IP:  ${pi_ip4_addr}"
    CleanEcho " DHCP ${dhcp_check_box} IPv6 ${dhcp_ipv6_check_box}"
  elif [ "$1" = "nano" ]; then
    CleanEcho "${bold_text}NETWORK ================${reset_text}"
    CleanEcho " Host: ${pi_hostname}"
    CleanEcho " IP:  ${pi_ip4_addr}"
    CleanEcho " DHCP: ${dhcp_check_box}    IPv6: ${dhcp_ipv6_check_box}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}NETWORK ======================${reset_text}"
    CleanEcho " Host:    ${full_hostname}"
    CleanEcho " IP:      ${pi_ip4_addr}"
    CleanEcho " DHCP:    ${dhcp_check_box}     IPv6:  ${dhcp_ipv6_check_box}"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}NETWORK ================================${reset_text}"
    CleanPrintf " %-9s%-19s\e[0K\\n" "Host:" "${full_hostname}"
    CleanPrintf " %-9s%-19s\e[0K\\n" "IP:"   "${pi_ip4_addr}"
    CleanPrintf " %-9s%-10s\e[0K\\n" "DNS:" "${dns_information}"

    if [ "${DHCP_ACTIVE}" = "true" ]; then
      CleanPrintf " %-9s${dhcp_heatmap}%-10s${reset_text} %-9s${dhcp_ipv6_heatmap}%-10s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6:" ${dhcp_ipv6_status}
    fi
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}NETWORK ============================================${reset_text}"
    CleanPrintf " %-10s%-16s %-8s%-16s\e[0K\\n" "Hostname:" "${full_hostname}" "IP:  " "${pi_ip4_addr}"
    CleanPrintf " %-6s%-39s\e[0K\\n" "IPv6:" "${pi_ip6_addr}"
    CleanPrintf " %-10s%-16s %-8s%-16s\e[0K\\n" "DNS:" "${dns_information}" "DNSSEC:" "${dnssec_heatmap}${dnssec_status}${reset_text}"

    if [ "${DHCP_ACTIVE}" = "true" ]; then
      CleanPrintf " %-10s${dhcp_heatmap}%-16s${reset_text} %-8s${dhcp_ipv6_heatmap}%-10s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6:" ${dhcp_ipv6_status}
      CleanPrintf "%s\e[0K\\n" "${dhcp_info}"
    fi
  elif [ "$1" = "regular" ] || [ "$1" = "slim" ]; then
    CleanEcho "${bold_text}NETWORK ===================================================${reset_text}"
    CleanPrintf " %-10s%-19s %-10s%-19s\e[0K\\n" "Hostname:" "${full_hostname}" "IP:" "${pi_ip4_addr}"
    CleanPrintf " %-6s%-19s\e[0K\\n" "IPv6:" "${pi_ip6_addr}"
    CleanPrintf " %-10s%-19s %-10s%-19s\e[0K\\n" "DNS:" "${dns_information}" "DNSSEC:" "${dnssec_heatmap}${dnssec_status}${reset_text}"

    if [ "${DHCP_ACTIVE}" = "true" ]; then
      CleanPrintf " %-10s${dhcp_heatmap}%-19s${reset_text} %-10s${dhcp_ipv6_heatmap}%-19s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6:" ${dhcp_ipv6_status}
      CleanPrintf "%s\e[0K\\n" "${dhcp_info}"
    fi
  else
    CleanEcho "${bold_text}NETWORK =======================================================================${reset_text}"
    CleanPrintf " %-10s%-19s\e[0K\\n" "Hostname:" "${full_hostname}" "Model:" "${sys_type}"
    CleanPrintf " %-6s%-19s %-10s%-29s\e[0K\\n" "IPv4:     " "${pi_ip4_addr}" "IPv6:" "${pi_ip6_addr}"
    CleanEcho "DNS ==========================================================================="
    CleanPrintf " %-10s%-39s\e[0K\\n" "Servers:" "${dns_information}"
    CleanPrintf " %-10s${dnssec_heatmap}%-19s${reset_text} %-20s${conditional_forwarding_heatmap}%-9s${reset_text}\e[0K\\n" "DNSSEC:" "${dnssec_status}" "Conditional Fwding:" "${conditional_forwarding_status}"

    CleanEcho "DHCP =========================================================================="
    CleanPrintf " %-10s${dhcp_heatmap}%-19s${reset_text} %-10s${dhcp_ipv6_heatmap}%-9s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6 Spt:" "${dhcp_ipv6_status}"
    CleanPrintf "%s\e[0K\\n" "${dhcp_info}"
  fi
}

PrintPiholeInformation() {
  # size checks
  if [ "$1" = "pico" ]; then
    :
  elif [ "$1" = "nano" ]; then
    CleanEcho "${bold_text}PI-HOLE ================${reset_text}"
    CleanEcho " Up:  ${pihole_check_box}      FTL: ${ftl_check_box}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}PI-HOLE ======================${reset_text}"
    CleanEcho " Status:  ${pihole_check_box}      FTL:  ${ftl_check_box}"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}PI-HOLE ================================${reset_text}"
    CleanPrintf " %-9s${pihole_heatmap}%-10s${reset_text} %-9s${ftl_heatmap}%-10s${reset_text}\e[0K\\n" "Status:" "${pihole_status}" "FTL:" "${ftl_status}"
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}PI-HOLE ============================================${reset_text}"
    CleanPrintf " %-10s${pihole_heatmap}%-16s${reset_text} %-8s${ftl_heatmap}%-10s${reset_text}\e[0K\\n" "Status:" "${pihole_status}" "FTL:" "${ftl_status}"
  elif [ "$1" = "regular" ] || [ "$1" = "slim" ]; then
    CleanEcho "${bold_text}PI-HOLE ===================================================${reset_text}"
    CleanPrintf " %-10s${pihole_heatmap}%-19s${reset_text} %-10s${ftl_heatmap}%-19s${reset_text}\e[0K\\n" "Status:" "${pihole_status}" "FTL:" "${ftl_status}"
  else
    return
  fi
}

PrintPiholeStats() {
  # are we on a reduced screen size?
  if [ "$1" = "pico" ]; then
    CleanEcho "${bold_text}PI-HOLE ============${reset_text}"
    CleanEcho " [${ads_blocked_bar}] ${ads_percentage_today}%"
    CleanEcho " ${ads_blocked_today} / ${dns_queries_today}"
  elif [ "$1" = "nano" ]; then
    CleanEcho " Blk: [${ads_blocked_bar}] ${ads_percentage_today}%"
    CleanEcho " Blk: ${ads_blocked_today} / ${dns_queries_today}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}STATS ========================${reset_text}"
    CleanEcho " Blckng:  ${domains_being_blocked} domains"
    CleanEcho " Piholed: [${ads_blocked_bar}] ${ads_percentage_today}%"
    CleanEcho " Piholed: ${ads_blocked_today} / ${dns_queries_today}"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}STATS ==================================${reset_text}"
    CleanPrintf " %-9s%-29s\e[0K\\n" "Blckng:" "${domains_being_blocked} domains"
    CleanPrintf " %-9s[%-20s] %-5s\e[0K\\n" "Piholed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-9s%-29s\e[0K\\n" "Piholed:" "${ads_blocked_today} out of ${dns_queries_today}"
    CleanPrintf " %-9s%-29s\e[0K\\n" "Latest:" "${latest_blocked}"
    if [ "${DHCP_ACTIVE}" != "true" ]; then
      CleanPrintf " %-9s%-29s\\n" "Top Ad:" "${top_blocked}"
    fi
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}STATS ==============================================${reset_text}"
    CleanPrintf " %-10s%-29s\e[0K\\n" "Blocking:" "${domains_being_blocked} domains"
    CleanPrintf " %-10s[%-30s] %-5s\e[0K\\n" "Pi-holed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Pi-holed:" "${ads_blocked_today} out of ${dns_queries_today}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Latest:" "${latest_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Ad:" "${top_blocked}"
    if [ "${DHCP_ACTIVE}" != "true" ]; then
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Dmn:" "${top_domain}"
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Clnt:" "${top_client}"
    fi
  elif [ "$1" = "regular" ] || [ "$1" = "slim" ]; then
    CleanEcho "${bold_text}STATS =====================================================${reset_text}"
    CleanPrintf " %-10s%-49s\e[0K\\n" "Blocking:" "${domains_being_blocked} domains"
    CleanPrintf " %-10s[%-40s] %-5s\e[0K\\n" "Pi-holed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-10s%-49s\e[0K\\n" "Pi-holed:" "${ads_blocked_today} out of ${dns_queries_today} queries"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Latest:" "${latest_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Ad:" "${top_blocked}"
    if [ "${DHCP_ACTIVE}" != "true" ]; then
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Dmn:" "${top_domain}"
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Clnt:" "${top_client}"
    fi
  else
    CleanEcho "${bold_text}STATS =========================================================================${reset_text}"
    CleanPrintf " %-10s%-19s %-10s[%-40s] %-5s\e[0K\\n" "Blocking:" "${domains_being_blocked} domains" "Piholed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-10s%-30s%-29s\e[0K\\n" "Clients:" "${clients}" " ${ads_blocked_today} out of ${dns_queries_today} queries"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Latest:" "${latest_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Ad:" "${top_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Dmn:" "${top_domain}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Clnt:" "${top_client}"
    CleanEcho "FTL ==========================================================================="
    CleanPrintf " %-10s%-9s %-10s%-9s %-10s%-9s\e[0K\\n" "PID:" "${ftlPID}" "CPU Use:" "${ftl_cpu}%" "Mem. Use:" "${ftl_mem_percentage}%"
    CleanPrintf " %-10s%-69s\e[0K\\n" "DNSCache:" "${cache_inserts} insertions, ${cache_deletes} deletions, ${cache_size} total entries"
  fi
}

PrintSystemInformation() {
  if [ "$1" = "pico" ]; then
    CleanEcho "${bold_text}CPU ================${reset_text}"
    printf "%b" "${ceol} [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
  elif [ "$1" = "nano" ]; then
    CleanEcho "${ceol}${bold_text}SYSTEM =================${reset_text}"
    CleanEcho " Up:  ${system_uptime}"
    printf "%b"  "${ceol} CPU: [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}SYSTEM =======================${reset_text}"
    CleanEcho " Uptime:  ${system_uptime}"
    CleanEcho " Load:    [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
# echo -ne "${ceol}Memory:  [${memory_heatmap}${memory_bar}${reset_text}] ${memory_percent}%"
    printf "%b" "${ceol} Memory:  [${memory_heatmap}${memory_bar}${reset_text}] ${memory_percent}%"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}SYSTEM =================================${reset_text}"
    CleanPrintf " %-9s%-29s\\n" "Uptime:" "${system_uptime}"
    CleanEcho " Load:    [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
# echo -ne "${ceol}Memory:  [${memory_heatmap}${memory_bar}${reset_text}] ${memory_percent}%"
    printf "%b" "${ceol} Memory:  [${memory_heatmap}${memory_bar}${reset_text}] ${memory_percent}%"
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}SYSTEM =============================================${reset_text}"
    CleanPrintf " %-10s%-29s\e[0K\\n" "Uptime:" "${system_uptime}"
    CleanPrintf " %-10s${temp_heatmap}%-17s${reset_text} %-8s${cpu_load_1_heatmap}%-4s${reset_text}, ${cpu_load_5_heatmap}%-4s${reset_text}, ${cpu_load_15_heatmap}%-4s${reset_text}\e[0K\\n" "CPU Temp:" "${temperature}" "Load:" "${cpu_load_1}" "${cpu_load_5}" "${cpu_load_15}"
    # Memory and CPU bar
    CleanPrintf " %-10s[${memory_heatmap}%-7s${reset_text}] %-6s %-8s[${cpu_load_1_heatmap}%-7s${reset_text}] %-5s" "Memory:" "${memory_bar}" "${memory_percent}%" "CPU:" "${cpu_bar}" "${cpu_percent}%"
  # else we're not
  elif [ "$1" = "regular" ] || [ "$1" = "slim" ]; then
    CleanEcho "${bold_text}SYSTEM ====================================================${reset_text}"
    # Uptime
    CleanPrintf " %-10s%-39s\e[0K\\n" "Uptime:" "${system_uptime}"

    # Temp and Loads
    CleanPrintf " %-10s${temp_heatmap}%-20s${reset_text}" "CPU Temp:" "${temperature}"
    CleanPrintf " %-10s${cpu_load_1_heatmap}%-4s${reset_text}, ${cpu_load_5_heatmap}%-4s${reset_text}, ${cpu_load_15_heatmap}%-4s${reset_text}\e[0K\\n" "CPU Load:" "${cpu_load_1}" "${cpu_load_5}" "${cpu_load_15}"

    # Memory and CPU bar
    CleanPrintf " %-10s[${memory_heatmap}%-10s${reset_text}] %-6s %-10s[${cpu_load_1_heatmap}%-10s${reset_text}] %-5s" "Memory:" "${memory_bar}" "${memory_percent}%" "CPU Load:" "${cpu_bar}" "${cpu_percent}%"
  else
    CleanEcho "${bold_text}SYSTEM ========================================================================${reset_text}"
    # Uptime and memory
    CleanPrintf " %-10s%-39s %-10s[${memory_heatmap}%-10s${reset_text}] %-6s\\n" "Uptime:" "${system_uptime}" "Memory:" "${memory_bar}" "${memory_percent}%"

    # CPU temp, load, percentage
    CleanPrintf " %-10s${temp_heatmap}%-10s${reset_text} %-10s${cpu_load_1_heatmap}%-4s${reset_text}, ${cpu_load_5_heatmap}%-4s${reset_text}, ${cpu_load_15_heatmap}%-7s${reset_text} %-10s[${memory_heatmap}%-10s${reset_text}] %-6s" "CPU Temp:" "${temperature}" "CPU Load:" "${cpu_load_1}" "${cpu_load_5}" "${cpu_load_15}" "CPU Load:" "${cpu_bar}" "${cpu_percent}%"
  fi
}

############################################# HELPERS ##############################################

# Provides a color based on a provided percentage
# takes in one or two parameters
HeatmapGenerator () {
  # if one number is provided, just use that percentage to figure out the colors
  if [ -z "$2" ]; then
    load=$(printf "%.0f" "$1")
  # if two numbers are provided, do some math to make a percentage to figure out the colors
  else
    load=$(printf "%.0f" "$(echo "$1 $2" | awk '{print ($1 / $2) * 100}')")
  fi

  # Color logic
  #  |<-                 green                  ->| yellow |  red ->
  #  0  5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100
  if [ "${load}" -lt 75 ]; then
    out=${green_text}
  elif [ "${load}" -lt 90 ]; then
    out=${yellow_text}
  else
    out=${red_text}
  fi

  echo "$out"
}

# Provides a "bar graph"
# takes in two or three parameters
# $1: percentage filled
# $2: max length of the bar
# $3: colored flag, if "color" backfill with color
BarGenerator() {
  # number of filled in cells in the bar
  barNumber=$(printf %.f "$(echo "$1 $2" | awk '{print ($1 / 100) * $2}')")
  frontFill=$(for i in $(seq "$barNumber"); do printf "%b" "■"; done)

  # remaining "unfilled" cells in the bar
  backfillNumber=$(($2-barNumber))

  # if the filled in cells is less than the max length of the bar, fill it
  if [ "$barNumber" -lt "$2" ]; then
    # if the bar should be colored
    if [ "$3" = "color" ]; then
      # fill the rest in color
      backFill=$(for i in $(seq $backfillNumber); do printf "%b" "■"; done)
      out="${red_text}${frontFill}${green_text}${backFill}${reset_text}"
    # else, it shouldn't be colored in
    else
      # fill the rest with "space"
      backFill=$(for i in $(seq $backfillNumber); do printf "%b" "·"; done)
      out="${frontFill}${reset_text}${backFill}"
    fi
  # else, fill it all the way
  else
    out=$(for i in $(seq "$2"); do printf "%b" "■"; done)
  fi

  echo "$out"
}

# Checks the size of the screen and sets the value of padd_size
SizeChecker(){
  # Below Pico. Gives you nothing...
  if [ "$console_width" -lt "20" ] || [ "$console_height" -lt "10" ]; then
    # Nothing is this small, sorry
    clear
    printf "%b" "${check_box_bad} Error!\\n    PADD isn't\\n    for ants!\n"
    exit 1
  # Below Nano. Gives you Pico.
  elif [ "$console_width" -lt "24" ] || [ "$console_height" -lt "12" ]; then
    padd_size="pico"
  # Below Micro, Gives you Nano.
  elif [ "$console_width" -lt "30" ] || [ "$console_height" -lt "16" ]; then
    padd_size="nano"
  # Below Mini. Gives you Micro.
  elif [ "$console_width" -lt "40" ] || [ "$console_height" -lt "18" ]; then
    padd_size="micro"
  # Below Tiny. Gives you Mini.
  elif [ "$console_width" -lt "53" ] || [ "$console_height" -lt "20" ]; then
      padd_size="mini"
  # Below Slim. Gives you Tiny.
  elif [ "$console_width" -lt "60" ] || [ "$console_height" -lt "21" ]; then
      padd_size="tiny"
  # Below Regular. Gives you Slim.
  elif [ "$console_width" -lt "80" ] || [ "$console_height" -lt "26" ]; then
    if [ "$console_height" -lt "22" ]; then
      padd_size="slim"
    else
      padd_size="regular"
    fi
  # Mega
  else
    padd_size="mega"
  fi
}

CheckConnectivity() {
  connectivity="false"
  connection_attempts=1
  wait_timer=1

  while [ $connection_attempts -lt 9 ]; do

    if nc -zw1 google.com 443 2>/dev/null; then
      if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
        echo "Attempt #${connection_attempts} passed..."
      elif [ "$1" = "mini" ]; then
        echo "Attempt ${connection_attempts} passed."
      else
        echo "  - Attempt ${connection_attempts} passed...                                     "
      fi

      connectivity="true"
      connection_attempts=11
    else
      connection_attempts=$((connection_attempts+1))

      inner_wait_timer=$((wait_timer*1))

      # echo "$wait_timer = $inner_wait_timer"
      while [ $inner_wait_timer -gt 0 ]; do
        if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
          printf "%b" "Attempt #${connection_attempts} failed...\\r"
        elif [ "$1" = "mini" ] || [ "$1" = "tiny" ]; then
          printf "%b" "- Attempt ${connection_attempts} failed, wait ${inner_wait_timer}  \\r"
        else
          printf "%b" "  - Attempt ${connection_attempts} failed... waiting ${inner_wait_timer} seconds...  \\r"
        fi
        sleep 1
        inner_wait_timer=$((inner_wait_timer-1))
      done

      # echo -ne "Attempt $connection_attempts failed... waiting $wait_timer seconds...\\r"
      # sleep $wait_timer
      wait_timer=$((wait_timer*2))
    fi

  done

  if [ "$connectivity" = "false" ]; then
    if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
      echo "Check failed..."
    elif [ "$1" = "mini" ] || [ "$1" = "tiny" ]; then
      echo "- Connectivity check failed."
    else
      echo "  - Connectivity check failed..."
    fi
  else
    if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
      echo "Check passed..."
    elif [ "$1" = "mini" ] || [ "$1" = "tiny" ]; then
      echo "- Connectivity check passed."
    else
      echo "  - Connectivity check passed..."
    fi
  fi
}


########################################## MAIN FUNCTIONS ##########################################

OutputJSON() {
  GetSummaryInformation
  echo "{\"domains_being_blocked\":${domains_being_blocked_raw},\"dns_queries_today\":${dns_queries_today_raw},\"ads_blocked_today\":${ads_blocked_today_raw},\"ads_percentage_today\":${ads_percentage_today_raw}},\"clients\": ${clients}}"
    cd "$oldpath" > /dev/null || exit

}

StartupRoutine(){
  if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
    PrintLogo "$1"
    printf "%b" "START-UP ===========\n"
    printf "%b" "Checking connection.\n"
    CheckConnectivity "$1"
    printf "%b" "Starting PADD...\n"

    printf "%b" " [■·········]  10%\\r"

    # Check for updates
      printf "%b" " [■■········]  20%\\r"
    if [ -f "$piHoleVersion_file" ]; then
      rm -f "$piHoleVersion_file"
      printf "%b" " [■■■·······]  30%\\r"
    else
      printf "%b" " [■■■·······]  30%\\r"
    fi

    # Get our information for the first time
    printf "%b" " [■■■■······]  40%\\r"
    GetSystemInformation "$1"
    printf "%b" " [■■■■■·····]  50%\\r"
    GetSummaryInformation "$1"
    printf "%b" " [■■■■■■····]  60%\\r"
    GetPiholeInformation "$1"
    printf "%b" " [■■■■■■■···]  70%\\r"
    GetNetworkInformation "$1"
    printf "%b" " [■■■■■■■■··]  80%\\r"
    GetVersionInformation "$1"
    printf "%b" " [■■■■■■■■■·]  90%\\r"
    printf "%b" " [■■■■■■■■■■] 100%\\n"

  elif [ "$1" = "mini" ]; then
    PrintLogo "$1"
    echo "START UP ====================="
    echo "Checking connectivity."
    CheckConnectivity "$1"

    echo "Starting PADD."

    # Check for updates
    echo "- Checking for version file."
    if [ -f "$piHoleVersion_file" ]; then
      echo "  - Found and deleted."
      rm -f "$piHoleVersion_file"
    else
      echo "  - Not found."
    fi

    # Get our information for the first time
    echo "- Gathering system info."
    GetSystemInformation "mini"
    echo "- Gathering Pi-hole info."
    GetSummaryInformation "mini"
    echo "- Gathering network info."
    GetNetworkInformation "mini"
    echo "- Gathering version info."
    GetVersionInformation "mini"
    echo "  - Core v$core_version, Web v$web_version"
    echo "  - FTL v$ftl_version, PADD $padd_version"
    echo "  - $version_status"

  else
    printf "%b" "${padd_logo_retro_1}\n"
    printf "%b" "${padd_logo_retro_2}Pi-hole® Ad Detection Display\n"
    printf "%b" "${padd_logo_retro_3}A client for Pi-hole\n\n"
    if [ "$1" = "tiny" ]; then
      echo "START UP ============================================"
    else
      echo "START UP ==================================================="
    fi

    printf "%b" "- Checking internet connection...\n"
    CheckConnectivity "$1"

    # Check for updates
    echo "- Checking for PADD version file..."
    if [ -f "$piHoleVersion_file" ]; then
      echo "  - PADD version file found... deleting."
      rm -f "$piHoleVersion_file"
    else
      echo "  - PADD version file not found."
    fi

    # Get our information for the first time
    echo "- Gathering system information..."
    GetSystemInformation "$1"
    echo "- Gathering Pi-hole information..."
    GetSummaryInformation "$1"
    GetPiholeInformation "$1"
    echo "- Gathering network information..."
    GetNetworkInformation "$1"
    echo "- Gathering version information..."
    GetVersionInformation "$1"
    echo "  - Pi-hole Core v$core_version"
    echo "  - Web Admin v$web_version"
    echo "  - FTL v$ftl_version"
    echo "  - PADD $padd_version"
    echo "  - $version_status"
  fi

  printf "%s" "- Starting in "

  for i in 3 2 1
  do
    printf "%s..." "$i"
    sleep 1
  done
}

NormalPADD() {
  while true; do

    console_width=$(tput cols)
    console_height=$(tput lines)

    # Sizing Checks
    SizeChecker

    # Move the cursor to top left of console to redraw
    tput cup 0 0

    # Output everything to the screen
    PrintLogo ${padd_size}
    PrintPiholeInformation ${padd_size}
    PrintPiholeStats ${padd_size}
    PrintNetworkInformation ${padd_size}
    PrintSystemInformation ${padd_size}

    # Clear to end of screen (below the drawn dashboard)
    tput ed

    pico_status=${pico_status_ok}
    mini_status_=${mini_status_ok}
    tiny_status_=${tiny_status_ok}

    # Start getting our information
    GetVersionInformation ${padd_size}
    GetSummaryInformation ${padd_size}
    GetPiholeInformation ${padd_size}
    GetNetworkInformation ${padd_size}
    GetSystemInformation ${padd_size}

    # Sleep for 5 seconds
    sleep 5
  done
}

DisplayHelp() {
  cat << EOM
::: PADD displays stats about your piHole!
:::
::: Note: If no option is passed, then stats are displayed on screen, updated every 5 seconds
:::
::: Options:
:::  -j, --json    output stats as JSON formatted string
:::  -h, --help    display this help text
EOM
    exit 0
}

if [ $# = 0 ]; then
  # Turns off the cursor
  # (From Pull request #8 https://github.com/jpmck/PADD/pull/8)
  setterm -cursor off
  trap "{ setterm -cursor on ; echo "" ; exit 0 ; }" INT TERM EXIT

  clear

  console_width=$(tput cols)
  console_height=$(tput lines)

  SizeChecker

  StartupRoutine ${padd_size}

  # Run PADD
  clear
  NormalPADD
  cd "$oldpath" > /dev/null || exit
fi

for var in "$@"; do
  case "$var" in
    "-j" | "--json"  ) OutputJSON;;
    "-h" | "--help"  ) DisplayHelp;;
    *                ) exit 1;;
  esac
done
