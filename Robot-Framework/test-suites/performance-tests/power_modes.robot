# SPDX-FileCopyrightText: 2022-2025 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Testing power consumption with different power modes on Lenovo-X1
Force Tags          performance   power-modes   lenovo-x1

Resource            ../../resources/gui_keywords.resource
Resource            ../../resources/gui-vm_keywords.resource
Resource            ../../resources/power_meas_keywords.resource
Resource            ../../resources/setup_keywords.resource
Resource            ../../resources/ssh_keywords.resource
Library             ../../lib/output_parser.py
Library             JSONLibrary

*** Variables ***
${POWERSAVE_LIMIT}       10000
${ORIGINAL_POWERMODE}    ${EMPTY}


*** Test Cases ***

Power modes
    [Documentation]   Measure power consumption with different power modes.
    ...               Confirm that consumption on powersave < balanced < performance.
    ...               Confirm that consumption on powersave is smaller than ${POWERSAVE_LIMIT}.
    [Setup]           Test Setup
    [Teardown]        Test Teardown

    Wait   30

    Start power measurement  ${BUILD_ID}   timeout=1500
    Switch to vm   ${GUI_VM}  user=${USER_LOGIN}

    ${powersave_power}     Measure power consumption of a power mode   gui-powersave

    ${balanced_power}      Measure power consumption of a power mode   gui-balanced

    ${performance_power}   Measure power consumption of a power mode   gui-performance

    Generate power plot    ${BUILD_ID}   Powersave-Balanced-Performance
    Stop recording power

    Should Be True   ${powersave_power} < ${balanced_power} < ${performance_power}
    Should Be True   ${powersave_power} < ${POWERSAVE_LIMIT}


*** Keywords ***

Test Setup
    [Timeout]    5 minutes
    ${availability}   Check variable availability  RPI_IP_ADDRESS
    IF  ${availability}==False   SKIP   Power measurement agent IP address not defined. Skipping the test
    Prepare Test Environment
    Stop swayidle
    ${active_mode}     Get active power mode
    Set Suite Variable   ${ORIGINAL_POWERMODE}   ${active_mode}

Test Teardown
    Set brightness   100%
    Set power mode   ${ORIGINAL_POWERMODE}
    Log out from laptop

Measure power consumption of a power mode
    [Arguments]      ${mode}

    Set power mode   ${mode}
    Set brightness   100%

    Wait                     15
    Set timestamp            starttime
    Wait                     60
    Set timestamp            endtime

    Get power record         ${BUILD_ID}.csv
    ${average_power}         Calculate average power over interval   ${BUILD_ID}   ${starttime}   ${endtime}
    Log                      Average power with ${mode} was ${average_power}   console=True
    RETURN                   ${average_power}

Set power mode
    [Arguments]        ${mode}
    [Setup]            Switch to vm   ${GUI_VM}
    Log                Setting power mode to ${mode}   console=True
    Execute Command    tuned-adm profile ${mode}   sudo=True  sudo_password=${PASSWORD}
    ${active_mode}     Get active power mode
    Should Contain     ${active_mode}   ${mode}

Get active power mode
    ${active_mode}     Execute Command   tuned-adm active
    RETURN   ${active_mode}
