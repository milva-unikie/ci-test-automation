# SPDX-FileCopyrightText: 2022-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Testing time synchronization
Test Tags           timesync

Library             ../../lib/TimeLibrary.py
Resource            ../../resources/common_keywords.resource
Resource            ../../resources/ssh_keywords.resource
Resource            ../../resources/wifi_keywords.resource
Resource            ../../resources/service_keywords.resource


*** Variables ***
${wrong_time}       01/11/23 11:00:00 UTC
${pre_change_time}  ${EMPTY}
${error_msg}        Unrecoverable error detected. Please collect any data possible and then kill the guest


*** Test Cases ***

Host time resynchronizes after RTC drift
    [Documentation]   Stop timesyncd, force host RTC drift, then verify time resynchronizes after restarting timesyncd.
    [Tags]            SP-T97  lenovo-x1  darter-pro  dell-7330  orin-agx  orin-agx-64  orin-nx  fmo

    Switch to vm   ${HOST}
    Check that time is synchronized and correct

    Stop timesync daemon
    Set RTC time  ${wrong_time}
    ${time_changed}  Run Keyword And Return Status  Wait Until Keyword Succeeds  5s  1s  Check that universal time on device matches expected   ${wrong_time}
    IF  ${time_changed} != True
        FAIL    Failed to set RTC time
    END
    Start timesync daemon
    Check that time is synchronized and correct

    [Teardown]  Timesync Teardown

VMs resynchronize time after internet is restored
    [Documentation]   Force incorrect VM time without internet, then verify resynchronization after internet is restored.
    [Tags]            SP-T217  lenovo-x1  darter-pro  dell-7330
    [Setup]           VM Time Update Setup
    Check that time is correct in all VMs
    FOR    ${vm}    IN    @{VM_LIST}
        Run Keyword And Continue On Failure   Set wrong time    ${vm}
    END
    Wait Until Keyword Succeeds   60s   1s   Check that time is correct in all VMs

*** Keywords ***

VM Time Update Setup
    @{VM_LIST}      Get VM list
    Remove Values From List  ${VM_LIST}   ${ADMIN_VM}
    Set Suite Variable       @{VM_LIST}

Timesync Teardown
     [Timeout]      2 minutes
     Switch to vm   ${HOST}
     Set RTC from system clock
     Start timesync daemon

Set wrong time
    [Documentation]   Disable internet, change time in vm, restart timesyncd, check that time was changed to wrong, enable internet
    [Arguments]       ${vm}
    Switch to vm      ${vm}
    ${time_before}    Get Device Universal Time
    Block internet traffic
    Set system time           ${wrong_time}
    Restart timesync daemon
    ${time_after}      Get Device Universal Time
    Compare two times  ${time_before}   ${time_after}   tolerance_seconds=600   should_match=False
    [Teardown]         Unblock internet traffic

Check that time is correct in all VMs
    [Documentation]    Check that time was synchronized in all VMs
    FOR    ${vm}    IN    @{VM_LIST}
        Switch to vm    ${vm}
        Run Keyword And Continue On Failure   Check that time is synchronized and correct
    END

Stop timesync daemon
    Run Command            systemctl stop systemd-timesyncd.service  sudo=True
    Verify service status  service=systemd-timesyncd.service  expected_state=inactive  expected_substate=dead

Start timesync daemon
    Run Command            systemctl start systemd-timesyncd.service  sudo=True
    Verify service status  service=systemd-timesyncd.service  expected_state=active  expected_substate=running
    Run Command            timedatectl -a

Restart timesync daemon
    Run Command            systemctl restart systemd-timesyncd.service  sudo=True
    Verify service status  service=systemd-timesyncd.service  expected_state=active  expected_substate=running
    Run Command            timedatectl -a

Check that time is synchronized and correct
    [Documentation]   Check that current system time on the device is synchronized and correct (time tolerance = 30 sec)
    [Arguments]       ${timezone}=UTC
    ${output}         Run Command    timedatectl -a
    ${_}  ${_}  ${_}  ${_}  ${is_synchronized}   Parse time info  ${output}
    Should Be True    ${is_synchronized}    Time was not synchronized!

    ${current_time}   Get current time   ${timezone}
    Check that universal time on device matches expected   ${current_time}    tolerance_seconds=30
    Check that universal time and local time match

Set RTC time
    [Arguments]     ${time}
    ${pre_change_time}    Get Time	epoch
    Set Test Variable     ${pre_change_time}  ${pre_change_time}
    Log             Setting time ${time} to RTC     console=True
    Run Command     hwclock --set --date="${time}"  sudo=True
    Sleep    3
    Run Command     hwclock -s  sudo=True
    Run Command     timedatectl -a

Check that universal time on device matches expected
    [Documentation]     Check that current universal time on the device is equal to expected time within time tolerance.
    [Arguments]         ${expected_time}   ${tolerance_seconds}=None   ${should_match}=True
    ${universal_time}   Get Device Universal Time
    ${expected_time}    Convert To UTC  ${expected_time}
    IF    '${tolerance_seconds}' == 'None'
        ${now}                   Get Time  epoch
        ${tolerance_seconds}     Evaluate  ${now} - ${pre_change_time}
    END
    Compare two times   ${universal_time}    ${expected_time}    tolerance_seconds=${tolerance_seconds}    should_match=${should_match}

Check that universal time and local time match
    [Documentation]    Check that local and universal time are synced on the device
    ${output}          Run Command    timedatectl -a
    ${local_time}  ${universal_time}  ${rtc_time}  ${device_time_zone}  ${is_synchronized}    Parse time info  ${output}
    ${local_time_utc}  Convert To UTC  ${local_time}
    ${time_close}      Is time close  ${universal_time}  ${local_time_utc}  tolerance_seconds=1
    Should Be True     ${time_close}

Compare two times
    [Documentation]   Compare current device time against expected time with a tolerance.
    [Arguments]       ${time1}    ${time2}    ${tolerance_seconds}=30    ${should_match}=True
    Log               Comparing times ${time1} and ${time2}, tolerance_seconds=${tolerance_seconds}, should_match=${should_match}    console=True
    ${time_close}     Is time close      ${time1}    ${time2}    tolerance_seconds=${tolerance_seconds}
    IF    ${should_match}
        Should Be True        ${time_close}    Time was not changed, expected close to: ${time2}, in fact: ${time1}
    ELSE
        Should Not Be True    ${time_close}    Time was not changed, expected to differ from: ${time2}, in fact: ${time1}
    END

Get Device Universal Time
    ${output}         Run Command    timedatectl -a
    ${local_time}  ${universal_time}  ${rtc_time}  ${device_time_zone}  ${is_synchronized}   Parse time info  ${output}
    RETURN   ${universal_time}

Set RTC from system clock
    [Documentation]   Set the Hardware Clock from the System Clock
    Run Command       hwclock -w  sudo=True
    Run Command       timedatectl -a

Set system time
    [Arguments]         ${time}
    Log                 Setting system time to ${time}   console=True
    Run Command         date -s '${time}'  sudo=True
    Run Command         timedatectl -a

Block internet traffic
    Run Command    sh -c "iptables -I OUTPUT -p udp --dport 123 -j DROP & iptables -I OUTPUT -p tcp -m multiport --dports 80,443 -j DROP & iptables -I OUTPUT -p udp -m multiport --dports 80,443 -j DROP & wait"    sudo=True

Unblock internet traffic
    Run Command    sh -c "iptables -D OUTPUT -p udp --dport 123 -j DROP & iptables -D OUTPUT -p tcp -m multiport --dports 80,443 -j DROP & iptables -D OUTPUT -p udp -m multiport --dports 80,443 -j DROP & wait"    sudo=True
