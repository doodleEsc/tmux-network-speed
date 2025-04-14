#!/bin/bash -

get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value="$(tmux show-option -gqv "$option")"
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

get_speed_output() {
	local interface="$1"

	if is_osx; then
		netstat -bn -I $interface 2>/dev/null | grep "<Link#" | awk '{print $7 " " $10}'
	else
		# Check if interface exists in /proc/net/dev
		if grep -q -w "$interface" /proc/net/dev 2>/dev/null; then
			grep -w "$interface" /proc/net/dev | awk '{print $2 " " $10}'
		else
			# Return "0 0" for non-existent interfaces
			echo "0 0"
		fi
	fi
}

is_osx() {
	[ $(uname) == "Darwin" ]
}
