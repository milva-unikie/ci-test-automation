# SPDX-FileCopyrightText: 2022-2025 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Testing settings options
Force Tags          gui   gui-settings

Library             ../../lib/TimeLibrary.py
Resource            ../../resources/app_keywords.resource
Resource            ../../resources/gui_keywords.resource
Resource            ../../resources/ssh_keywords.resource


*** Test Cases ***

Change timezone in settings
    [Documentation]   Open COSMIC Settings app and change timezone
    [Tags]            timezone   lenovo-x1
    [Setup]           Set timezone to UTC
    #Execute Command    timedatectl set-timezone UTC  sudo=True  sudo_password=${PASSWORD}
    Get icon           ${ICONS}/hicolor/48x48/apps  com.system76.CosmicSettings.svg  background=black  output_filename=settings.png

    Set timezone to UTC

    Locate and click   image  ./settings.png  0.95
    Sleep   3
    Tab and enter   tabs=1
    Locate and click   image  search-neg.png  0.90  1 
    Type string and press enter   zone
    Tab and enter   tabs=5
    Tab and enter   tabs=9
    Type string and press enter   Helsinki
    Tab and enter   tabs=1
    Type string and press enter   ${PASSWORD}   confidential=True

    ${timezone}     Get timezone
    Should Be Equal As Strings    ${timezone}    Europe/Helsinki
    [Teardown]      Set timezone to UTC

    # Move cursor to corner
    # Locate and click   image  ./window-close-neg.png  0.8
    # Locate and click   text   UTC

    # Sleep   3
    # Locate and click   text   Time
    # Tab and enter   tabs=2
    # Tab and enter   tabs=1
    # Tab and enter   tabs=6
    # Tab and enter   tabs=2
    # Type string and press enter   Helsinki
    # Tab and enter   tabs=1
    # Type string and press enter   ${PASSWORD}   confidential=True
    # Locate and click   text   UTC


*** Keywords ***

Launch Cosmic Settings
    Start XDG application   com.system76.CosmicSettings
    Check that the application was started    cosmic-settings  exact_match=true

Set timezone to UTC
    Execute Command    timedatectl set-timezone UTC  sudo=True  sudo_password=${PASSWORD}
    ${timezone}        Get timezone
    Should Be Equal As Strings    ${timezone}    UTC

Get timezone
    ${output}      Execute Command    timedatectl -a
    ${_}  ${_}  ${_}  ${device_time_zone}  ${_}   Parse time info  ${output}
    RETURN   ${device_time_zone}