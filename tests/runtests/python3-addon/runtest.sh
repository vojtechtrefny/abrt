#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of python3-addon
#   Description: tests the functionality of the ABRT Python 3 exception handler
#   Author: Richard Marko <rmarko@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc. All rights reserved.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 3 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. /usr/share/beakerlib/beakerlib.sh
. ../aux/lib.sh

TEST="python3-addon"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartSetup
        check_prior_crashes

        TmpDir=$(mktemp -d)
        pushd $TmpDir
        rlAssertRpm "abrt-addon-python3"
    rlPhaseEnd

    rlPhaseStartTest
        prepare
        generate_python3_exception
        wait_for_hooks
        get_crash_path

        check_dump_dir_attributes $crash_PATH

        rlRun "abrt-cli info $crash_PATH | grep will_python3_raise" 0 "abrt-cli info should contain will_python3_raise"
        rlRun "abrt-cli info $crash_PATH | grep 'Python'" 0 "abrt-cli info should contain 'Python'"
        rlRun "abrt-cli rm $crash_PATH"
    rlPhaseEnd

    rlPhaseStartTest "RequireAbsolutePath test"
        AASPD_CONF="/etc/abrt/abrt-action-save-package-data.conf"
        PYTHON_CONF="/etc/abrt/plugins/python3.conf"
        rlFileBackup $AASPD_CONF $PYTHON_CONF

        CRASH_PY="crash.py"
        cat > $CRASH_PY << EOF
#!/usr/bin/python3
1/0
EOF
        rlRun "chmod +x $CRASH_PY" 0

        rlRun "augtool set /files${AASPD_CONF}/ProcessUnpackaged yes" 0
        rlRun "augtool set /files${PYTHON_CONF}/RequireAbsolutePath yes" 0

        prepare
        rlRun "./$CRASH_PY" 1
        sleep 10
        rlAssert0 "No crash recorded" $(abrt-cli list | wc -l)

        rlRun "augtool set /files${PYTHON_CONF}/RequireAbsolutePath no" 0

        prepare
        rlRun "./$CRASH_PY" 1
        wait_for_hooks
        get_crash_path
        check_dump_dir_attributes $crash_PATH
        rlAssertGrep "./$CRASH_PY" ${crash_PATH}/executable

        rlFileRestore # $AASPD_CONF $PYTHON_CONF
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore
        rlRun "abrt-cli rm $crash_PATH"
        popd # TmpDir
        rm -rf $TmpDir
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd
