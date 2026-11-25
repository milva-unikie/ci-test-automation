# SPDX-FileCopyrightText: 2022-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0


*** Settings ***
Documentation       Testing power options

Resource            ../../resources/common_keywords.resource
Resource            ../../resources/device_control.resource
Resource            ../../resources/gui-vm_keywords.resource
Resource            ../../resources/gui_keywords.resource
Resource            ../../resources/measurement_keywords.resource
Resource            ../../resources/serial_keywords.resource
Resource            ../../resources/setup_keywords.resource
Resource            ../../resources/ssh_keywords.resource

Test Setup          GUI Power Test Setup
Test Teardown       GUI Power Test Teardown

Test Tags           gui-power  lenovo-x1  darter-pro


*** Variables ***
${SHUTDOWN_LIMIT}              25
${REBOOT_LIMIT}                90
${LOGIN_LIMIT}                 10
${LOGIN_TIME_AFTER_REBOOT}     ${EMPTY}


*** Test Cases ***
Suspend and wake up from power menu
    [Documentation]   Suspend the device via GUI taskbar suspend icon and wake up.
    ...               Logs device power consumption during the test
    ...               if power measurement tooling is set.
    [Tags]            SP-T492  lab-only
    Start power measurement       ${BUILD_ID}   timeout=180
    # Connect back to gui-vm after power measurement has been started
    Switch to vm    ${GUI_VM}   user=${USER_LOGIN}

    Select power menu option   x=815   y=120
    Confirm suspension and wake up the device

    Generate power plot           ${BUILD_ID}   ${TEST NAME}
    Stop recording power

Lock and Unlock from power menu
    [Documentation]   Lock the screen via GUI power menu lock icon and check that the screen is locked.
    ...               Unlock lock screen by typing the password and check that desktop is available.
    [Tags]            SP-T493
    Select power menu option   text=Lock
    ${lock}           Check if locked   iterations=3   debug_screenshot=True
    IF  not ${lock}   FAIL    Failed to lock the screen
    Unlock
    Wait for desktop readiness

Lock screen with shortcut
    [Documentation]   Lock the screen via shortcut and verify locked state.
    ...               Unlock lock screen by typing the password and check that desktop is available.
    [Tags]            SP-T401
    Press Key(s)      LEFTMETA+ESC
    ${lock}           Check if locked   iterations=3   debug_screenshot=True
    IF  not ${lock}   FAIL    Failed to lock the screen
    Unlock
    Wait for desktop readiness

Reboot from power menu
    [Documentation]   Reboot the device via GUI power menu reboot icon.
    ...               Check that it shuts down. Check that it turns on and boots to login screen.
    [Tags]            SP-T494  lab-only
    Select power menu option   x=870   y=120   confirmation=True
    ${start_time}     Get Time    epoch
    Verify shutdown via network
    Connect After Reboot   soft_reboot=True
    ${end_time}       Get Time    epoch
    Login to laptop
    ${elapsed}        Evaluate    ${end_time} - ${start_time}
    Log               Reboot took ${elapsed} seconds   console=True

    IF    ${elapsed} > ${REBOOT_LIMIT}
        Skip If Gui-vm Timed Out On Previous Boot   message=Reboot took too long: ${elapsed} seconds (expected < ${REBOOT_LIMIT})
    END
    Should Not Be True    ${elapsed} > ${REBOOT_LIMIT}    msg=Reboot took too long: ${elapsed} seconds (expected < ${REBOOT_LIMIT})

Shutdown from power menu
    [Documentation]   Shutdown the device via GUI power menu shutdown icon.
    ...               Check that it shuts down and then wakes up with a short power button press.
    [Tags]            SP-T495  lab-only
    Select power menu option   x=925   y=120   confirmation=True

    ${start_time}     Get Time    epoch
    ${end_time}       Wait Until Device Is Down
    ${elapsed}        Evaluate    ${end_time} - ${start_time}
    Log               Shutdown took ${elapsed} seconds   console=True
    #  Wait time extended from 10 to 20 due to SSRCSP-9231
    IF    ${elapsed} <= ${SHUTDOWN_LIMIT}
        ${wait_time}  Evaluate    ${SHUTDOWN_LIMIT} - ${elapsed} + 20
        Wait          ${wait_time}
    ELSE
        Wait          20
    END
    Turn Laptop On
    Connect After Reboot
    Login to laptop
    Set Suite Variable    ${LOGIN_TIME_AFTER_REBOOT}    ${LOGIN_TIME}

    IF    ${elapsed} > ${SHUTDOWN_LIMIT}
        Skip If Gui-vm Timed Out On Previous Boot   message=Shutdown took too long: ${elapsed} seconds (expected < ${SHUTDOWN_LIMIT})
    END
    Should Not Be True    ${elapsed} > ${SHUTDOWN_LIMIT}    msg=Shutdown took too long: ${elapsed} seconds (expected < ${SHUTDOWN_LIMIT})

Log in after reboot
    [Documentation]   Check that login after reboot completes within the expected time.
    ...               Login time is measured in Shutdown from power menu to avoid unnecessary reboot.
    [Tags]            SP-T535  lab-only
    Skip If              $LOGIN_TIME_AFTER_REBOOT == '${EMPTY}'    Login time was not saved in previous test
    ${error_msg}         Set Variable   Login after reboot took too long: ${LOGIN_TIME_AFTER_REBOOT} seconds (expected < ${LOGIN_LIMIT})
    Should Not Be True   ${LOGIN_TIME_AFTER_REBOOT} > ${LOGIN_LIMIT}   msg=${error_msg}
    [Teardown]   Run Keyword If Test Failed   Run Keyword If   "storeDisk" in "${JOB}"   Run Keywords
    ...    Log Error   StoreDisk login   ${error_msg}   AND
    ...    SKIP   Known Issue: SSRCSP-9328 (${error_msg})

Log out and log in from power menu
    [Documentation]   Logout via GUI power menu icon and verify logged out state.
    ...               Login and verify that desktop is available.
    [Tags]            SP-T496
    Skip If    ${DISABLE_LOGOUT}    This test can't run when logging out is disabled
    Select power menu option   text=LogOut   confirmation=True
    ${logout_status}            Check if logged out
    Should Be True              ${logout_status}    Logout failed
    Log in, unlock and verify
    Should Not Be True          ${LOGIN_TIME} > ${LOGIN_LIMIT}    msg=Login took too long: ${LOGIN_TIME} seconds (expected < ${LOGIN_LIMIT})

Log out and log in with shortcut
    [Documentation]   Logout via logout shortcut and verify logged out state.
    ...               Login and verify that desktop is available.
    [Tags]            SP-T402
    Skip If    ${DISABLE_LOGOUT}    This test can't run when logging out is disabled
    Press Key(s)                LEFTMETA+LEFTSHIFT+ESC
    Locate on screen            text  Quit  10
    Tab and enter               tabs=1
    ${logout_status}            Check if logged out
    Should Be True              ${logout_status}    Logout failed
    Log in, unlock and verify
    Should Not Be True          ${LOGIN_TIME} > ${LOGIN_LIMIT}    msg=Login took too long: ${LOGIN_TIME} seconds (expected < ${LOGIN_LIMIT})

Suspend and wake up from lock screen
    [Documentation]   Suspend the device from lock screen suspend icon and wake up.
    [Tags]            SP-T245  lab-only
    Press Key(s)          LEFTMETA+ESC
    Locate on screen      image  ${LOCK_ICON}      0.95
    Locate and click      image  suspend-neg.png   0.95
    Confirm suspension and wake up the device


*** Keywords ***
GUI Power Test Setup
    ${gui_power_log_since}    BuiltIn.Get Time   epoch
    Set Test Variable         ${gui_power_log_since}
    Switch to vm    ${GUI_VM}   user=${USER_LOGIN}
    Start screen recording

GUI Power Test Teardown
    IF  $TEST_STATUS == 'FAIL' and 'took too long' not in $TEST_MESSAGE
        Hard Reboot Device And Connect
        IF    ${IS_AVAILABLE}
            ssh_keywords.Save log   ${GUI_VM}  ${gui_power_log_since}
            ssh_keywords.Save log   ${HOST}    ${gui_power_log_since}
            Switch to vm            ${GUI_VM}  user=${USER_LOGIN}
            Save screen recording   ${TEST_STATUS}   ${TEST_NAME}
        END
    ELSE
        Switch to vm    ${GUI_VM}   user=${USER_LOGIN}
        Stop screen recording   ${TEST_STATUS}   ${TEST_NAME}
    END

Skip If Gui-vm Timed Out On Previous Boot
    [Documentation]    Check if SSRCSP-9231 caused extended shutdown/reboot and skip the test if it did.
    [Arguments]    ${message}
    Switch to vm    ${HOST}
    ${timeout_log}    Run Command
    ...    journalctl -b -1 --no-pager | grep -F "microvm@gui-vm.service: Failed with result 'timeout'."
    ...    sudo=True    rc_match=skip
    IF    $timeout_log != ''
        Log Error    Gui-vm timeout    gui-vm timed out during the previous boot
        SKIP    Known issue: SSRCSP-9231 (gui-vm timed out during the previous boot) (${message})
    END
