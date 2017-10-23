#! /bin/sh
# shUtils/test_shUtils.sh

export THISSCRIPT=test_shUtils.sh
if [ -f `which uuidgen` ]
then
	.  ./shUtils.sh
else
	echo "FATAL:  Must have uuidgen facility available."
	exit 99
fi

OSType=Unknown
if [ -n `grep -i centos /etc/issue` ]; then
    OSType=CentOS
elif [ -n `grep -i debian /etc/issue` ]; then
    OSType=Debian
elif [ -n `grep -i ubuntu /etc/issue` ]; then
    OSType=Ubuntu
fi
    
# ### Tool Procedures

`shopt -s expand_aliases 2>/dev/null`

TESTSCRIPTPATH=/tmp/testscript.sh
alias StartOfTmpTestScript='cat <<EndOfTmpTestScript >$TESTSCRIPTPATH'

createTmpDir() {
    if [ -n "$GLOBAL_TMPNAME" ]; then
        m="Existing GLOBAL_TMPNAME value indicates previous temporary folder not properly destroyed."
        echo "FATAL:  $m" >&2
        exit 99
    fi
    GLOBAL_XID=`uuidgen`
    GLOBAL_TMPNAME="/tmp/$GLOBAL_XID"
    mkdir -p $GLOBAL_TMPNAME
}

dateTmpFile() {
    if [ -n "$GLOBAL_TMPNAME" ]; then
        m="Existing GLOBAL_TMPNAME value indicates previous temporary folder not properly destroyed."
        echo "FATAL:  $m" >&2
        exit 99
    fi
    GLOBAL_XID=`uuidgen`
    GLOBAL_TMPNAME="/tmp/$GLOBAL_XID"
    date > $GLOBAL_TMPNAME
}

destroyTmpTestScript() {
    rm $TESTSCRIPTPATH
}

destroyTmpDir() {
    if [ -z "$GLOBAL_TMPNAME" ]; then
        m="Non-Existant GLOBAL_TMPNAME value indicates temporary folder already destroyed."
        echo "WARNING:  $m" >&2
        return
    fi
    if [ -e "$GLOBAL_TMPNAME" -a -e "$GLOBAL_TMPNAME/../.." ]; then
        # If you are not two deep, it can't be good.
        rm -rf $GLOBAL_TMPNAME
        GLOBAL_TMPNAME=
    else
        echo "ERROR:  $GLOBAL_TMPNAME problematic."
        exit 99
    fi
}

destroyTmpFile() {
    if [ -z "$GLOBAL_TMPNAME" ]; then
        m="Non-Existant GLOBAL_TMPNAME value indicates temporary folder already destroyed."
        echo "WARNING:  $m" >&2
        return
    fi
    rm $GLOBAL_TMPNAME
    GLOBAL_TMPNAME=
}

runErrStifleTmpTestScript() {
    _tsArg="$1"
	chmod 0755 $TESTSCRIPTPATH
    TTS_RESULT=`$TESTSCRIPTPATH $_tsArg 2>/dev/null`
}

runTmpTestScript() {
    _tsArg="$1"
	chmod 0755 $TESTSCRIPTPATH
    TTS_RESULT=`$TESTSCRIPTPATH $_tsArg`
}

sourceTmpTestScript() {
    _tsArg="$1"
    TTS_RESULT=`. $TESTSCRIPTPATH $_tsArg`
}

touchTmpFile() {
    if [ -n "$GLOBAL_TMPNAME" ]; then
        m="Existing GLOBAL_TMPNAME value indicates previous temporary folder not properly destroyed."
        echo "FATAL:  $m" >&2
        exit 99
    fi
    GLOBAL_XID=`uuidgen`
    GLOBAL_TMPNAME="/tmp/$GLOBAL_XID"
    touch $GLOBAL_TMPNAME
}

# ### Elemental Procedures

test_are_shell_arguments_available() {
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
if \`\$AreShellArgumentsAvailable\`
then
	echo TRUE
else
	echo FALSE
fi
#End Disposable Test Script
EndOfTmpTestScript
    #runTmpTestScript ""
	#assertEquals "FALSE" "$TTS_RESULT"
    #runTmpTestScript "1"
	#assertEquals "TRUE" "$TTS_RESULT"
    #runTmpTestScript "1 2 3 4 5 6"
	#assertEquals "TRUE" "$TTS_RESULT"
    #sourceTmpTestScript ""
	#assertEquals "FALSE" "$TTS_RESULT"
    #sourceTmpTestScript "1"
	#assertEquals "FALSE" "$TTS_RESULT"
    #sourceTmpTestScript "1 2 3 4 5 6"
	#assertEquals "FALSE" "$TTS_RESULT"
exit 0
    destroyTmpTestScript
}

test_has_UUID() {
	xid=`uuidgen`
	assertTrue "has_UUID $xid"
	assertFalse "has_UUID 12345"
}

test_is_interactive() {
    assertFalse is_interactive
}

test_is_alphabetic() {
    assertTrue "is_alphabetic aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpP"
    assertTrue "is_alphabetic abcd"
    assertFalse "is_alphabetic 1234"
    assertFalse "is_alphabetic '.15>;:'"
	xid=`uuidgen`
    assertFalse "is_alphabetic $xid"
}

test_is_alphanumeric() {
    assertTrue "is_alphanumeric 1"
    assertTrue "is_alphanumeric a"
    assertTrue "is_alphanumeric aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpP"
    assertTrue "is_alphanumeric abcd"
    assertTrue "is_alphanumeric 1234"
    assertFalse "is_alphanumeric '.15>;:'"
	xid=`uuidgen`
    assertFalse "is_alphanumeric $xid"
    anstr=`uuidgen | tr -d '-'`
    assertTrue "is_alphanumeric $anstr"
}

test_is_decimal() {
    assertTrue "is_decimal 1"
    assertTrue "is_decimal 1234567890"
    assertFalse "is_decimal 1234567890."
    assertFalse "is_decimal a"
    assertFalse "is_decimal aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpP"
    assertFalse "is_decimal abcd"
    assertFalse "is_alphanumeric '.15>;:'"
	xid=`uuidgen`
    assertFalse "is_decimal $xid"
    anstr=`uuidgen | tr -d '-'`
    assertFalse "is_decimal $anstr"
}

test_is_hex() {
    assertTrue "is_hex F"
    assertTrue "is_hex 1"
    assertTrue "is_hex 1234567890"
    assertFalse "is_hex 1234567890."
    assertTrue "is_hex a"
    assertFalse "is_hex aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpP"
    assertTrue "is_hex abcd"
    assertFalse "is_hex '.15>;:'"
	xid=`uuidgen`
    assertFalse "is_hex $xid"
    anstr=`uuidgen | tr -d '-'`
    assertTrue "is_hex $anstr"
}

test_is_numeric() {
    assertFalse "is_numeric F"
    assertTrue "is_numeric 1"
    assertTrue "is_numeric 1234567890"
    assertTrue "is_numeric 1234567890."
    assertFalse "is_numeric a"
    assertFalse "is_numeric aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpP"
    assertFalse "is_numeric abcd"
    assertFalse "is_numeric '.15>;:'"
    assertTrue "is_numeric '0.15'"
    assertTrue "is_numeric 0.15"
	xid=`uuidgen`
    assertFalse "is_numeric $xid"
    anstr=`uuidgen | tr -d '-'`
    assertFalse "is_numeric $anstr"
}

test_is_octal() {
    assertTrue "is_octal 01234567"
    assertFalse "is_octal F"
    assertTrue "is_octal 1"
    assertFalse "is_octal 1234567890"
    assertFalse "is_octal 1234567890."
    assertFalse "is_octal a"
    assertFalse "is_octal aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpP"
    assertFalse "is_octal abcd"
    assertFalse "is_octal '.15>;:'"
    assertFalse "is_octal '0.15'"
    assertFalse "is_octal 0.15"
	xid=`uuidgen`
    assertFalse "is_octal $xid"
    anstr=`uuidgen | tr -d '-'`
    assertFalse "is_octal $anstr"
}

test_is_perlw() {
    assertTrue "is_perlw 01234567"
    assertTrue "is_perlw F"
    assertTrue "is_perlw 1"
    assertTrue "is_perlw 1234567890"
    assertFalse "is_perlw 1234567890."
    assertTrue "is_perlw a"
    assertTrue "is_perlw aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpP"
    assertTrue "is_perlw abcd_"
    assertFalse "is_perlw '.15>;:'"
    assertFalse "is_perlw '0.15'"
    assertFalse "is_perlw 0.15"
	xid=`uuidgen`
    assertFalse "is_perlw $xid"
    anstr=`uuidgen | tr -d '-'`
    assertTrue "is_perlw $anstr"
}

test_is_UUID() {
	xid=`uuidgen`
    assertTrue "is_UUID $xid"
    assertFalse "is_UUID 01234567"
    assertFalse "is_UUID F"
    assertFalse "is_UUID 1234567890"
    assertFalse "is_UUID a"
    assertFalse "is_UUID '.15>;:'"
    anstr=`uuidgen | tr -d '-'`
    assertFalse "is_UUID $anstr"
    md5sum=`md5sum ./shUtils.sh`
    assertFalse "is_UUID $md5sum"
}

# ### Compound Procedures

test_exit_unless_interactive() {
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
tproc() {
    echo -n TWO
    exit_unless_interactive
}
echo -n ONE
tproc
echo -n THREE
#End Disposable Test Script
EndOfTmpTestScript
    runTmpTestScript
	assertEquals "ONETWO" "$TTS_RESULT"
    sourceTmpTestScript
	assertEquals "ONETWO" "$TTS_RESULT"
    destroyTmpTestScript
}

test_find_systemd_dir() {
    r=`find_systemd_dir`
    etr=`ps auxw | grep systemd`
    if [ $OSType = "Ubuntu" ]; then
        assertEquals '' $r
    fi
}

test_has_root_privileges() {
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
if has_root_privileges
then
    echo TRUE
else
    echo FALSE
fi
#End Disposable Test Script
EndOfTmpTestScript
    runTmpTestScript
	assertEquals FALSE $TTS_RESULT
    sudoRunTmpTestScript
	assertEquals TRUE $TTS_RESULT
    destroyTmpTestScript
}

test_validate_UUID() {
	xid=`uuidgen`
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
v1=\`validate_UUID $xid\`
echo -n \$v1
v2=\`validate_UUID NOTAUUID\`
echo -n \$v2
#End Disposable Test Script
EndOfTmpTestScript
    runErrStifleTmpTestScript
	assertEquals $xid $TTS_RESULT
    destroyTmpTestScript
}

test_validate_directory() {
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
v1=\`validate_directory $GLOBAL_TMPNAME\`
echo -n "\$v1"
v2=\`validate_directory NOPE\`
echo -n "\$v2"
#End Disposable Test Script
EndOfTmpTestScript
    createTmpDir
    runErrStifleTmpTestScript
	assertEquals $GLOBAL_TMPNAME $TTS_RESULT
    destroyTmpTestScript
    destroyTmpDir
}

test_validate_directory_with_UUID() {
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
v1=\`validate_directory_with_UUID $GLOBAL_TMPNAME\`
echo -n "\$v1"
v2=\`validate_directory_with_UUID $xid\`
echo -n "\$v2"
#End Disposable Test Script
EndOfTmpTestScript
    createTmpDir
    runErrStifleTmpTestScript
	assertEquals $GLOBAL_TMPNAME $TTS_RESULT
    destroyTmpTestScript
    destroyTmpDir
}

test_validate_exists() {
    dateTmpFile
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
v1=\`validate_exists $GLOBAL_TMPNAME\`
echo -n "\$v1"
rm $GLOBAL_TMPNAME
mkdir $GLOBAL_TMPNAME
v2=\`validate_exists $GLOBAL_TMPNAME\`
echo -n "\$v2"
rmdir $GLOBAL_TMPNAME
v3=\`validate_exists $GLOBAL_TMPNAME\`
echo -n "\$v3"
#End Disposable Test Script
EndOfTmpTestScript
    runErrStifleTmpTestScript
	assertEquals "$tmpd$tmpd" $TTS_RESULT
    destroyTmpTestScript
    GLOBAL_TMPNAME=
}

test_validate_file_has_nonblank_line_count() {
	blankfile=/tmp/blankfile
	onelinefile=/tmp/onelinefile
	tenlinefile=/tmp/tenlinefile
	touch $blankfile
	echo one>$onelinefile
	cat <<EOTENLINES >$tenlinefile
one
two
three
four
five
six
seven
eight
nine
ten

EOTENLINES
	assertTrue "validate_file_has_nonblank_line_count $blankfile 0 TRUE"
	assertTrue "validate_file_has_nonblank_line_count $onelinefile 1 TRUE"
	assertTrue "validate_file_has_nonblank_line_count $tenlinefile 10 TRUE"
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
echo -n "BEFORE"
validate_file_has_nonblank_line_count $onelinefile 45 TRUE
echo -n "AFTER"
#End Disposable Test Script
EndOfTmpTestScript
    runErrStifleTmpTestScript
	assertEquals "BEFORE" $r
    destroyTmpTestScript
    rm -f $blankfile $onelinefile $tenlinefile
}

test_validate_file_has_line_pattern() {
	onelinefile=/tmp/onelinefile
	tenlinefile=/tmp/tenlinefile
	echo one>$onelinefile
	cat <<EOTENLINES >$tenlinefile
one
two three four


five
six seven eight nine



ten
EOTENLINES
	assertTrue "validate_file_has_line_pattern $onelinefile one TRUE"
	assertTrue "validate_file_has_line_pattern $tenlinefile one TRUE"
	assertTrue "validate_file_has_line_pattern $tenlinefile 'six seven eight nine' TRUE"
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
echo -n "BEFORE"
validate_file_has_line_pattern $onelinefile NOTINTHERE TRUE
echo -n "AFTER"
#End Disposable Test Script
EndOfTmpTestScript
    dateTmpFile
    runErrStifleTmpTestScript
	assertEquals "BEFORE" $TTS_RESULT
    destroyTmpTestScript
    rm -f $onelinefile $tenlinefile
}

test_validate_file_has_pattern() {
	onelinefile=/tmp/onelinefile
	tenlinefile=/tmp/tenlinefile
	echo one>$onelinefile
	cat <<EOTENLINES >$tenlinefile
one
two three four


five
six seven eight nine



ten
EOTENLINES
	assertTrue "validate_file_has_pattern $onelinefile one TRUE"
	assertTrue "validate_file_has_pattern $tenlinefile one TRUE"
	assertTrue "validate_file_has_pattern $tenlinefile 'three' TRUE"
	assertTrue "validate_file_has_pattern $tenlinefile 'seven eight' TRUE"
	assertTrue "validate_file_has_pattern $tenlinefile 'six seven eight nine' TRUE"
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
echo -n "BEFORE"
validate_file_has_pattern $onelinefile NOTINTHERE TRUE
echo -n "AFTER"
#End Disposable Test Script
EndOfTmpTestScript
    dateTmpFile
    runErrStifleTmpTestScript
	assertEquals "BEFORE" $TTS_RESULT
    destroyTmpTestScript
    rm -f $onelinefile $tenlinefile
}

test_validate_regular_file() {
    createTmpDir
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
v1=\`validate_regular_file $tmpd\`
echo -n "\$v1"
v2=\`validate_regular_file NOPE\`
echo -n "\$v2"
#End Disposable Test Script
EndOfTmpTestScript
    dateTmpFile
    runErrStifleTmpTestScript
	assertEquals $GLOBAL_TMPNAME $TTS_RESULT
    destroyTmpTestScript
    destroyTmpDir
}

test_validate_regular_file_with_UUID() {
    createTmpDir
	StartOfTmpTestScript
#!/bin/sh
#Begin Disposable Test Script
THISSCRIPT=$0
.  $PWD/shUtils.sh
v1=\`validate_regular_file_with_UUID $tmpd\`
echo -n "\$v1"
v2=\`validate_regular_file_with_UUID $xid\`
echo -n "\$v2"
#End Disposable Test Script
EndOfTmpTestScript
    dateTmpFile
    runErrStifleTmpTestScript
	assertEquals $GLOBAL_TMPNAME $TTS_RESULT
    destroyTmpTestScript
    destroyTmpDir
}

. shunit2

# End of shUtils/test_shUtils.sh
