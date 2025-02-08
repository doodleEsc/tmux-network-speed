#!/bin/bash -

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CURRENT_DIR/helpers.sh"

default_download_color="#[fg=green]"
default_upload_color="#[fg=yellow]"

get_speed() {
	# Consts
	local THOUSAND=1024
	local MILLION=1048576

	local new=$1
	local current=$2
	local interval=$3
	local vel=0

	local format_string=$(get_tmux_option '@network_speed_format' "%05.2f")

	if [ ! "$current" -eq "0" ]; then
		vel=$(echo "$(($new - $current)) $interval" | awk '{print ($1 / $2)}')
	fi

	local vel_kb=$(echo "$vel" $THOUSAND | awk '{print ($1 / $2)}')
	local vel_mb=$(echo "$vel" $MILLION | awk '{print ($1 / $2)}')

	result=$(printf "%05.2f > 99.99\n" $vel_kb | bc -l)
	if [[ $result == 1 ]]; then
		local vel_mb_f=$(printf $format_string $vel_mb)
		printf "%s MB/s" $vel_mb_f
	else
		local vel_kb_f=$(printf $format_string $vel_kb)
		printf "%s KB/s" $vel_kb_f
	fi
}

# Multiple interfaces support
network_interfaces=$(get_tmux_option "@network_speed_interface" "en0")
IFS=',' read -ra interfaces <<<"$network_interfaces"

# Initialize cumulative variables
total_rx=0
total_tx=0
current_rx_total=0
current_tx_total=0

for interface in "${interfaces[@]}"; do
	# Trim whitespace from interface names
	interface=$(echo "$interface" | xargs)

	# Get current stored values
	current_tx=$(get_tmux_option "@network_speed_tx_$interface" 0)
	current_rx=$(get_tmux_option "@network_speed_rx_$interface" 0)

	# Get new speed output
	speed_output=$(get_speed_output "$interface")
	new_rx=$(echo "$speed_output" | awk '{print $1}')
	new_tx=$(echo "$speed_output" | awk '{print $2}')

	# Accumulate totals
	total_rx=$((total_rx + new_rx))
	total_tx=$((total_tx + new_tx))
	current_rx_total=$((current_rx_total + current_rx))
	current_tx_total=$((current_tx_total + current_tx))

	# Update stored values for this interface
	tmux set-option -gq "@network_speed_tx_$interface" $new_tx
	tmux set-option -gq "@network_speed_rx_$interface" $new_rx
done

# Get current time and calculate intervals
cur_time=$(date +%s)
last_update_time_tx=$(get_tmux_option '@network_speed_last_update_time_tx' 0)
interval_tx=$((cur_time - last_update_time_tx))
last_update_time_rx=$(get_tmux_option '@network_speed_last_update_time_rx' 0)
interval_rx=$((cur_time - last_update_time_rx))

# Calculate upload and download speeds
if [ $interval_tx -eq 0 ]; then
	upload_speed=$(get_tmux_option '@network_speed_last_speed_tx')
else
	upload_speed=$(get_speed $total_tx $current_tx_total $interval_tx)
	tmux set-option -gq "@network_speed_last_speed_tx" "$upload_speed"
	tmux set-option -gq "@network_speed_last_update_time_tx" $(date +%s)
fi

if [ $interval_rx -eq 0 ]; then
	download_speed=$(get_tmux_option '@network_speed_last_speed_rx')
else
	download_speed=$(get_speed $total_rx $current_rx_total $interval_rx)
	tmux set-option -gq "@network_speed_last_speed_rx" "$download_speed"
	tmux set-option -gq "@network_speed_last_update_time_rx" $(date +%s)
fi

# Get color options
download_color=$(get_tmux_option "@network_speed_download_color" "$default_download_color")
upload_color=$(get_tmux_option "@network_speed_upload_color" "$default_upload_color")

download_icon=$(get_tmux_option '@network_speed_download_icon' "↓")
upload_icon=$(get_tmux_option '@network_speed_upload_icon' "↑")

# Print result
printf "%s%s %s %s%s %s#[fg=default]" "$download_color" "$download_icon" "$download_speed" "$upload_icon" "$upload_color" "$upload_speed"
