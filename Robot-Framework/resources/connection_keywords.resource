# SPDX-FileCopyrightText: 2022-2025 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Resource            ../config/variables.robot


*** Keywords ***
Configure wifi
    [Arguments]         ${netvm_ssh}  ${SSID}  ${passw}
    Switch Connection   ${netvm_ssh}
    Log To Console      Configuring Wifi
    Set Log Level       NONE
    Execute Command     nmcli dev wifi connect ${SSID} password ${passw}   sudo=True    sudo_password=${PASSWORD}
    Set Log Level       INFO

Remove Wifi configuration
    [Arguments]         ${SSID}
    Switch Connection   ${netvm_ssh}
    Log To Console      Removing Wifi configuration
    ${stdout}  ${stderr}  ${rc}=  Execute Command  nmcli connection delete id ${SSID}
    ...   sudo=True   sudo_password=${PASSWORD}   return_stdout=True   return_stderr=True   return_rc=True
    Should Be Equal As Integers    ${rc}    0

Turn OFF WiFi
    [Arguments]         ${SSID}
    Switch Connection   ${netvm_ssh}
    Log To Console      Turning off Wifi
    Execute Command     nmcli con down id ${SSID}   sudo=True    sudo_password=${PASSWORD}

Turn ON WiFi
    [Arguments]         ${SSID}
    Switch Connection   ${netvm_ssh}
    Log To Console      Turning on Wifi
    Execute Command     nmcli con up id ${SSID}    sudo=True    sudo_password=${PASSWORD}

Initialize Variables And Connect
    [Documentation]  Initialize variables. Connect to device and start logging
    Close All Connections
    Set Variables   ${DEVICE}
    Run Keyword If  "${DEVICE_IP_ADDRESS}" == "NONE"    Get ethernet IP address
    ${port_22_is_available}     Check if ssh is ready on device   timeout=60
    IF  ${port_22_is_available} == False
        FAIL    Failed because port 22 of device was not available, tests can not be run.
    END
    ${CONNECTION}        Connect to ghaf host
    Set Global Variable  ${CONNECTION}
