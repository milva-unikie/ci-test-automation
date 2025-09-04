# SPDX-FileCopyrightText: 2022-2025 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       GUI tests

Library             ../../lib/GuiTesting.py   ${OUTPUT_DIR}/outputs/gui-temp/
Resource            ../../resources/setup_keywords.resource
Resource            ../../resources/gui_keywords.resource

Suite Setup         GUI Tests Setup
Suite Teardown      GUI Tests Teardown
Test Timeout        5 minutes


*** Keywords ***

GUI Tests Setup
    [Timeout]    5 minutes
    Prepare Test Environment   enable_dnd=True
    Save gui icons and icon path

    # There's a bug that occasionally causes the app menu to freeze on Cosmic, especially on the first login. 
    # Logging out once before running tests helps reduce the chances of it happening. (SSRCSP-6684)
    Log out and verify   disable_dnd=True
    Log in, unlock and verify   enable_dnd=True

GUI Tests Teardown
    [Timeout]    5 minutes
    Clean Up Test Environment   disable_dnd=True

Save gui icons and icon path
    [Documentation]       Save the icons that are used in multiple gui test cases
    ...                   Save path to icons
    Log To Console        Saving commonly used gui test icons
    ${ICONS}              Execute Command   find $(echo $XDG_DATA_DIRS | tr ':' ' ') -type d -name "icons" 2>/dev/null
    Set Global Variable   ${ICONS}
    Get icon              ${ICONS}/hicolor/scalable/apps  com.system76.CosmicAppLibrary.svg  crop=0  background=black  output_filename=launcher.png
    Get icon              ${ICONS}/Papirus/24x24/symbolic/actions  window-close-symbolic.svg  crop=0  background=white  output_filename=window-close.png
    Negate app icon       ${GUI_TEMP_DIR}/window-close.png  ${GUI_TEMP_DIR}/window-close-neg.png
    Get icon              ${ICONS}/Cosmic/scalable/actions  system-search-symbolic.svg  crop=0  background=white  output_filename=search.png
    Negate app icon       ${GUI_TEMP_DIR}/search.png  ${GUI_TEMP_DIR}/search-neg.png
    Get icon              ${ICONS}/Papirus/24x24/actions  system-shutdown.svg  crop=0  background=black  output_filename=power.png
    Get icon              ${ICONS}/Cosmic/scalable/actions  system-lock-screen-symbolic.svg  background=black  output_filename=lock.png
