# 345678901234567890123456789012345678901234567890123456789012345678901234567890
#
# shUtils.sh - Basic administration utilities tested and maintained for use in
#	all POSIX shells, especially Dash and minimal Bourne Shell like ones.

AreShellArgumentsAvailable='eval [ -n "$*" ]'

REGEX_ALPHA='[A-Za-z]'
REGEX_ALPHANUMERIC='[A-Za-z0-9]'
REGEX_DECIMAL='[0-9]'
REGEX_HEXADECIMAL='[0-9a-fA-F]'
REGEX_NUMERIC='[0-9]+\.?[0-9]*'
REGEX_OCTAL='[0-7]'
REGEX_PERLW='[0-9_A-Za-z]'
# https://en.wikipedia.org/wiki/Universally_unique_identifier
REGEX_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'


ROOTID=0

# ### Labels

IELBL="INTERNAL ERROR"
PELBL="PROGRAMMER ERROR"
UELBL="UNEXPECTED ERROR" # PROGRAMMER ERROR when customers are around
VELBL="VALIDATION ERROR"

# 345678901234567890123456789012345678901234567890123456789012345678901234567890
# ## Elemental Procedures

has_UUID() {
	local _vA=$1
	echo -n $_vA | grep -Eq $REGEX_UUID
	return $?
}

is_alphabetic() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_ALPHA+$"
	return $?
}

is_alphanumeric() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_ALPHANUMERIC+$"
	return $?
}

is_decimal() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_DECIMAL+$"
	return $?
}

is_hex() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_HEXADECIMAL+$"
	return $?
}

is_interactive() {
	# POSIX is apparently to use case for this kind of pattern matching:
	case $- in
	  *i*) return 0;;
		*) return 1;;
	esac
}

is_numeric() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_NUMERIC+$"
	return $?
}

is_octal() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_OCTAL+$"
	return $?
}

is_perlw() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_PERLW+$"
	return $?
}

if [ -z "$THISSCRIPT" ]
then
    # To fix this, define the "THISSCRIPT" identifier as a scriptwide,
    # variable, before sourcing this shUtils shell library, with the
    # value of your script's name, the same as $0 shows.
    echo -n "WARNING:  Identifier 'THISSCRIPT' is not defined.  " 1>&2
    echo "Without it you cannot use the is_source_included procedure." 1>&2
else
    is_source_included() {
        rstr=`echo $0 | grep $THISSCRIPT`
        if [ -z $rstr ]
        then
            return 0
        fi
        return 1
    }
fi

is_UUID() {
	local _vA=$1
	echo -n $_vA | grep -Eqw "^$REGEX_UUID+$"
	return $?
}

# ## Compound Procedures

exit_unless_interactive() {
	local _rCode=$1
	if is_interactive; then
		return $_rCode
	else
		exit $_rCode
	fi
}

find_systemd_dir() {
	local FailureSeverityLabel=ERROR
	if [ -n "$1" ]
	then
		FailureSeverityLabel=FATAL 
	fi

    # Various distributions has different paths for systemd unit files ...

    if pidof systemd 1> /dev/null 2> /dev/null; then
        # Be sure systemctl lives where we expect it to
        if [ ! -f /bin/systemctl ]; then
            echo "$FailureSeverityLabel: Unable to locate systemctl program" 1>&2
            exit 1
        fi

        # Find systemd unit directory
        for p in "/usr/lib/systemd/system" "/lib/systemd/system"; do
            if [ -d "$p" ]; then
                echo ${p}
                return 0
            fi
        done

        # Didn't find unit directory, that's fatal
        echo "$FailureSeverityLabel: Unable to resolve systemd unit directory!" 1>&2
		exit_unless_interactive 1
    else
        return 1
    fi
}

has_root_privileges() {
    if [ `id -u` -eq $ROOTID ]; then
		return 0
	fi
    return 1
}

validate_UUID() {
	local _vA=$1
	if is_UUID $_vA
    then
		echo $_vA
		return 0
	fi
	echo "$VELBL:  $_fSpec is NOT a UUID." 1>&2
	exit_unless_interactive 1
}

validate_directory() {
	local _vA=$1
	if [ -d "$_vA" ]; then
		echo $_vA 
		return 0
	fi
	echo "$VELBL:  NO directory '$_vA' is found." 1>&2
	exit_unless_interactive 1
}

validate_directory_with_UUID() {
	local _vA=$1

	if [ -d $_vA ]; then
		if has_UUID $_vA
        then
			echo $_vA
            return 0
		fi
	fi
	echo "$VELBL:  NOT directory or NO UUID found in '$_vA'." 1>&2
	exit_unless_interactive 1
}

validate_exists() {
	local _vA=$1
	if [ -e "$_vA" ]; then
		echo $_vA 
		return 0
	fi
	echo "$VELBL:  $_vA NOT found." 1>&2
	exit_unless_interactive 1
}

validate_file_has_nonblank_line_count() {
	local _fSpec=$1
	local _requiredcount=$2
	local _boolOnly=$3
	nblcount=`cat $_fSpec | grep -v '^ *$' | wc -l`
	if [ "$_requiredcount" -eq "$nblcount" ]; then
		return 0
	fi
	if [ -z "$_boolOnly" ]; then
		s1="$_fSpec had incorrect non-blank line count of $nblcount."
		s2="Should have been $_requiredcount."
		echo "ERROR:  $s1  $s2"
	fi
	exit_unless_interactive 1
}

validate_file_has_line_pattern() {
	local _fSpec=$1
	local _pattA="$2"
	local _boolOnly=$3
	cat $_fSpec | grep -Eq "^$_pattA$"
	if [ $? -eq 0 ]; then
		return 0
	fi
	if [ -z "$_boolOnly" ]; then
		echo "ERROR:  $_fSpec missing required pattern '$_pattA'."
	fi
	exit_unless_interactive 1
}

validate_file_has_pattern() {
	local _fSpec=$1
	local _pattA="$2"
	local _boolOnly=$3
	cat $_fSpec | grep -Eq "$_pattA"
	if [ $? -eq 0 ]; then
		return 0
	fi
	if [ -z "$_boolOnly" ]; then
		echo "ERROR:  $_fSpec missing required pattern '$_pattA'."
	fi
	exit_unless_interactive 1
}

validate_has_root_privileges() {
    _callingPoint=$1
    if has_root_privileges
    then
        return 0
    fi
    echo "ERROR:  $_callingPoint requires root privileges."
    echo "No changes performed."
	exit_unless_interactive 1
}

validate_regular_file() {
	local _vA=$1
	if [ -f "$_vA" ]; then
		echo $_vA 
		return 0
	fi
	echo "$VELBL:  NO regular file '$_vA' is found." 1>&2
	exit_unless_interactive 1
}

validate_regular_file_with_UUID() {
	local _vA=$1

	if [ -f $_vA ]; then
		if has_UUID $_vA
        then
			echo $_vA
            return 0
		fi
	fi
	exit_unless_interactive 1
}

#2345678901234567890123456789012345678901234567890123456789012345678901234567890
# End of shUtils.sh
