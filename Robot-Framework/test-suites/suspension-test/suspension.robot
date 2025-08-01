# SPDX-FileCopyrightText: 2022-2025 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Testing automatic suspension of Lenovo-X1
Force Tags          regression   suspension
Resource            ../../resources/ssh_keywords.resource
Resource            ../../config/variables.robot
Resource            ../../resources/common_keywords.resource
Resource            ../../resources/gui_keywords.resource
Resource            ../../resources/device_control.resource
Resource            ../../resources/connection_keywords.resource
Resource            ../../resources/power_meas_keywords.resource
Library             ../../lib/output_parser.py
Library             JSONLibrary

*** Test Cases ***

Automatic suspension
    [Documentation]   Wait and check that
    ...               in the beginning brightness is 96000
    ...               in 4 min - the screen dims (brightness is 24000)
    ...               in 5 min - the screen locks (brightness is 24000)
    ...               in 7,5 min - screen turns off
    ...               in 15 min - the laptop is suspended
    ...               in 5 min press the button and check that laptop woke up
    [Tags]            SP-T162   lenovo-x1
    [Setup]           Test setup

    Check the screen state   on
    Check screen brightness  ${max_brightness}

    Start power measurement       ${BUILD_ID}   timeout=1500
    Connect
    Switch to vm    gui-vm
    Set start timestamp

    Wait     240
    Check screen brightness  ${dimmed_brightness}

    Wait     10

    Check the screen state   on
    Wait    50
    ${locked}         Check if locked
    Should Be True    ${locked}
    
    Wait     150
    Check the screen state   off

    Wait     460

    Check that device is suspended
    Wait     300
    Wake up device
    Generate power plot           ${BUILD_ID}   ${TEST NAME}
    Stop recording power

*** Keywords ***

Test setup
    Start swayidle
    Get expected brightness values
    Set display to max brightness
    Move cursor

Wait
    [Arguments]     ${sec}
    ${time}         Get Time
    Log To Console  ${time}: waiting for ${sec} sec
    Sleep           ${sec}

Get expected brightness values
    ${device}     Execute Command    ls /sys/class/backlight/
    ${max}        Execute Command    cat /sys/class/backlight/${device}/max_brightness
    Set Test Variable  ${max_brightness}     ${max}
    Log To Console     Max brightness value is ${max}
    ${int_max}         Convert To Integer    ${max}
    ${dimmed}          Evaluate   __import__('math').ceil(${int_max} / 4)
    Log To Console     Dimmed brightness is expected to be ~${dimmed}
    Set Test Variable  ${dimmed_brightness}  ${dimmed}

Set display to max brightness
    ${current_brightness}    Get screen brightness   log_brightness=False
    IF   ${current_brightness} != ${max_brightness}
        Log To Console    Brightness is ${current_brightness}, setting it to the maximum
        ${output}     Execute Command    ls /nix/store | grep brightnessctl | grep -v .drv
        ${output}     Execute Command    /nix/store/${output}/bin/brightnessctl set 100%   sudo=True  sudo_password=${PASSWORD}
        ${current_brightness}    Get screen brightness
        Should be Equal As Numbers    ${current_brightness}   ${max_brightness}
    END

Check screen brightness
    [Arguments]       ${brightness}    ${timeout}=60
    # 10 second timeout should be enough, but for some reason sometimes dimming the screen takes longer.
    # To prevent unnecessary fails timeout has been increased.
    FOR  ${i}  IN RANGE  ${timeout}
        ${output}     Get screen brightness  log_brightness=False
        Log To Console    Check ${i}: Brightness is ${output}
        ${status}     Run Keyword And Return Status  Should be Equal As Numbers   ${output}  ${brightness}
        IF  ${status}
            BREAK
        ELSE
            Sleep    1
        END
    END
    IF  ${status} == False    FAIL    The screen brightness is ${output}, expected ${brightness}

Check the screen state
    [Arguments]         ${state}
    [Setup]       Switch to vm    gui-vm  user=${USER_LOGIN}
    ${output}           Execute Command    ls /nix/store | grep wlopm | grep -v .drv
    ${output}  ${err}   Execute Command    WAYLAND_DISPLAY=wayland-1 /nix/store/${output}/bin/wlopm    return_stderr=True
    Log To Console      Screen state: ${output}
    Should Contain      ${output}    ${state}
    [Teardown]    Switch to vm    gui-vm

Check that device is suspended
    ${device_not_available}  Run Keyword And Return Status  Wait Until Keyword Succeeds  15s  2s  Check If Ping Fails
    IF  ${device_not_available} == True
        Log To Console  Device is suspended
    ELSE
        Log To Console  Device is available
        FAIL    Device was not suspended
    END

Wake up device
    Log To Console    Pressing the power button...
    Press Button      ${SWITCH_BOT}-ON
    Check If Device Is Up    range=120
    IF    ${IS_AVAILABLE} == False
        FAIL  The device did not start
    ELSE
        Log To Console  The device started
    END