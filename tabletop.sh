#!/bin/bash

###############  tabletop.sh :: a script for tablet options  #################
# first attempt at tablet control script.  It might be too monolithic, but the
# idea is to provide control over the following:
# ** screen orientation, etc.  Especially important during lectures when you
#    want the internal display to be upside down, but the external right-side
#    up.  But also, sometimes it is nice to have the letter-layout for general
#    note taking.
# ** touchscreen controls.  When you are going to take notes, it is kind of
#    annoying to have your palm writing as well as the pen.  We should be able
#    to disable that at the right times.
# ** power saving.  Enabling powersave for the tablet will make it harder to
#    use, but if you are just using the notebook as a notebook, it can save a
#    fair amount of energy.
#
# Note: this script depends on the following:
# * xrandr
# * xsetwacom
# * root privileges, if you want to set power options.
##############################################################################

#######  Configuration  #######

# Your default (internal) output name (in xrandr-speak)
internal="LVDS1"
# Your list of external outputs to test for
externals='VGA1 HDMI1 HDMI2'

# We will need to determine the various tablet input devices so that we
# can control their orientation when rotating our display.  Experience
# shows that these id's are not static, and change across boots.
tabdevlist=$(xsetwacom list devices)
idstylus=$(echo "$tabdevlist" | grep -i "stylus" | \
	grep -o '\<id:[[:space:]]*[0-9]\+\>')
idstylus=${idstylus//[^0-9]/}
# echo "The stylus id is $idstylus"
idtouch=$(echo "$tabdevlist" | grep -i "touch" | \
	grep -o '\<id:[[:space:]]*[0-9]\+\>')
idtouch=${idtouch//[^0-9]/}
# echo "The touch id is $idtouch"
ideraser=$(echo "$tabdevlist" | grep -i "eraser" | \
	grep -o '\<id:[[:space:]]*[0-9]\+\>')
ideraser=${ideraser//[^0-9]/}
# echo "The eraser id is $ideraser"

# for the X220T, you will need to find the id of the trackpoint, so that you
# can disable it when the tablet is folded (failing to do so can lead to very
# erratic behavior of the stylus, as the trackpoint is triggered when you
# press on the tablet.  Thanks to Daniel German for figuring this out.) There
# is probably a better way to do this via acpid; I think the tablet being
# rotated will generate some sort of event.  You can browse the interrupts in
# /sys/firmware/acpi/interrupts/ but I'm not sure this is the way to go.
# Pretty sure it is not, actually.  For now, we will just manually disable the
# trackpoint whenever you invert the screen, or rotate the screen.  We'll set
# -G to re-enable trackpoint.
# Try to auto-detect the trackpoint.  Note: you have to be very specific with
# the query, since there might be an external keyboard with trackpoint, which
# you would NOT want to disable at this time.
trackpointid=$(xinput list | grep "PS/2 IBM TrackPoint" | \
	grep -o '\<id=[0-9]\+\>')
trackpointid=${trackpointid//[^0-9]/}

###############################


tabletop_usage()
{
cat << EOF
usage: tabletop [OPTIONS]

Modifies various tablet-related settings, including power management,
display orientation, and controls for toggling the touchscreen, pen, etc.

OPTIONS:
   -h           Show this message
   -i           Invert the internal display
   -I           Set internal display to normal orientation
   -r           Rotate internal display 90 degrees, cc
   -t           Enable finger touch (does not affect stylus)
   -T           Disable finger touch (does not affect stylus)
   -p           Enable powersaving for the tablet
   -P           Disable powersaving for the tablet
   -m           Map the tablet events to the internal display.  This can be
                useful if an external display is connected which has a
                different size than the screen you're writing on.
   -v           Verbose (print more stuff)
   -G           G, as in GTFO.  This option tries to turn off any external
                monitors that are connected, and switch the internal monitor
                back to its normal default state.

EXAMPLES:
   If during a lecture, you have an external display that you would like
   to write on, you could invert your internal display (to avoid having to
   physically rotate your computer), disable the touchscreen (so that your
   palm does not register events when you write) and disable powersaving so
   that the tablet stays more responsive, all with the following command:

		   tabletop -iTP

EOF
}


while getopts "hiIrtTpPmvG" OPTION
do
	case $OPTION in
	h)
		tabletop_usage
		exit 0
		;;
	i)
		invert=1
		;;
	I)
		invert=0
		;;
	r)
		rotate=1
		;;
	t)
		fingertouch="on"
		;;
	T)
		fingertouch="off"
		;;
	p)
		# "auto" as in "auto suspend"
		powermgmt="auto"
		;;
	P)
		# here, "on" means the device is on.  I.e.,
		# power management is off.
		powermgmt="on"
		;;
	m)
		mapoutput=1
		;;
	v)
		verbose=1
		;;
	G)
		gtfo=1
		;;
	?)
		tabletop_usage
		exit 0
		;;
	esac
done

# check for no options passsed.  if this is the case, then print the usage and
# exit.
if [[ $OPTIND == 1 ]]
then
	tabletop_usage
	exit 1
fi

# I don't think this is necessary in a stand-alone script.
unset OPTION
unset OPTARG
unset OPTSTRING
unset OPTIND
unset OPTERR


# when verbose is specified, try to pass that flag along to all the
# subroutines, and maybe echo some messages yourself.
if [[ $verbose = 1 ]]; then
	verbose="--verbose"
else
	verbose=""
fi

# if both invert and rotate are specified, we'll let invert take precedence.
# no particular reason, other than it is the less expensive operation.
if [[ $invert = 1 ]]; then
	# note that we do not attempt to set the resolution / mode; it is
	# assumed that this has already been done, and we don't want to
	# reset it here.
	xrandr $verbose --output $internal --rotate inverted
	xsetwacom $verbose set $idtouch Rotate half
	xsetwacom $verbose set $idstylus Rotate half
	xsetwacom $verbose set $ideraser Rotate half
	[[ -n $trackpointid ]] && xinput --disable $trackpointid
elif [[ $invert = 0 ]]; then
	xrandr $verbose --output $internal --rotate normal
	xsetwacom $verbose set $idtouch Rotate none
	xsetwacom $verbose set $idstylus Rotate none
	xsetwacom $verbose set $ideraser Rotate none
	[[ -n $trackpointid ]] && xinput --enable $trackpointid
elif [[ $rotate = 1 ]]; then
	# in this case, we do try to set the resolution, since that is the more
	# typical application (not likely to do this when attached to a mirrored
	# external display, right??)
	xrandr $verbose --output $internal --auto --rotate left
	xsetwacom $verbose set $idtouch Rotate ccw
	xsetwacom $verbose set $idstylus Rotate ccw
	xsetwacom $verbose set $ideraser Rotate ccw
	[[ -n $trackpointid ]] && xinput --disable $trackpointid
fi

# If you read the xsetwacom documentation carefully, you may be wondering
# why we have rotated every one of the devices.  After all, the manual
# states the following:
#
#   Rotation  is  a tablet-wide option: rotation of one tool affects all other
#   tools associated with the same tablet. When the tablet is physically
#   rotated, rotate any tool to the corresponding orientation.
#
# But that was a lie.  So we must rotate them all @_@


if [[ $mapoutput == 1 ]]; then
	# for each device, call map output.
	xsetwacom $verbose set $idtouch MapToOutput $internal
	xsetwacom $verbose set $idstylus MapToOutput $internal
	xsetwacom $verbose set $ideraser MapToOutput $internal
fi

[[ -n $fingertouch ]] && xsetwacom set $idtouch Touch $fingertouch

# Note: this requires sudo.
# Note: you have to find the right path; the path below is of course
# very specific to my machine.
[[ -n $powermgmt ]] && \
	echo "$powermgmt" > '/sys/bus/usb/devices/2-1.5/power/control'

# The GTFO option should try to turn off all other displays, and set the
# internal display to its preferred settings.  The following is adapted from
# the arch wiki.

if [[ -n $gtfo ]]; then
	# get info from xrandr
	XRANDR=`xrandr -q`
	EXECUTE="$verbose --output $internal --auto --rotate normal "

	for CURRENT in $externals ; do
		if [[ $XRANDR == *$CURRENT\ connected*  ]] # is connected
		then
			EXECUTE+="--output $CURRENT --off "
			# TODO: is it harmful to unconditionally turn off these
			# displays?  Probably not.  In case you need to make a
			# distinction, you can do so as follows:
			# if [[ $XRANDR == *$CURRENT\ connected\ \(* ]] # is disabled
			# then
			# 	# do nothing
			# else
			# 		EXECUTE+="--output $CURRENT --off "
			# fi
		fi
	done

	xrandr $EXECUTE
	# we also need to re-enable trackpoint:
	[[ -n $trackpointid ]] && xinput --enable $trackpointid
fi
