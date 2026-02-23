# SPDX-FileCopyrightText: 2022-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Testing settings options
Force Tags          gui-setup  lenovo-x1  darter-pro

Resource            ../../resources/gui-vm_keywords.resource
Resource            ../../resources/gui_keywords.resource
Resource            ../../resources/setup_keywords.resource

Test Timeout        15 minutes

*** Variables ***
${KEYBOARD_CONFIG}      /home/${USER_LOGIN}/.config/cosmic/com.system76.CosmicComp/v1/xkb_config
${ORIGINAL_KEYBOARD}    /tmp/xkb_config_${USER_LOGIN}.bak


*** Test Cases ***

Complete Initial Setup
    [Documentation]   Complete the Cosmic Initial Setup
    [Setup]           Run Keywords   Open Initial Setup
    ...    AND   Start screen recording
    ...    AND   Save original timezone
    ...    AND   Save original keyboard
    
    # Accessibility
    Locate on screen  text   Accessibility   20
    Locate and click  image   ghaf-next.png   0.95

    Check page and open next   connected

    # Keyboard
    Locate on screen  text   keyboard
    Type string and press enter   "Finnish (classic)"
    Tab and enter     tabs=1
    Wait Until Keyword Succeeds  10s  1s   Verify keyboard language   fi
    Locate and click  image   ghaf-next.png   0.95   wiggle=True

    # Timezone
    Locate on screen  text   timezone
    Type string and press enter   Dubai
    Tab and enter     tabs=1
    Click

    # Personalize appearance
    Locate on screen  text   appearance

    # Switch to light theme
    Locate and click  text   light
    Run ydotool command   mousemove -x 0 -y -40
    Click
    Wait Until Keyword Succeeds  30s  1s   Verify theme   light

    # Switch to dark theme
    Locate on screen  image  launcher-light.png  0.90
    Locate and click  text   dark
    Run ydotool command   mousemove -x 0 -y -40
    Click
    Wait Until Keyword Succeeds  30s  1s   Verify theme   dark
    Locate and click  image   ghaf-next.png   0.95    wiggle=True

    # Layout configuration
    Locate on screen  text   layout

    # Switch to bottom panel
    Locate and click  text   configuration
    Run ydotool command   mousemove -x 30 -y 50
    Click
    Wait Until Keyword Succeeds  30s  1s  Verify layout   bottom

    # Switch to top panel
    Run ydotool command   mousemove -x -150 -y 0
    Click
    Wait Until Keyword Succeeds  30s  1s  Verify layout   top
    Locate and click  image   ghaf-next.png   0.95    wiggle=True

    # Click though the rest of the pages
    Check page and open next   workspaces
    Check page and open next   shortcuts
    Check page and open next   fast

    Check that ghaf-intro was launched
    Verify timezone   Asia/Dubai

    [Teardown]   Run Keywords   Move cursor to corner
    ...          AND   Kill Initial Setup
    ...          AND   Restore keyboard config
    ...          AND   Set timezone   ${ORIGINAL_TIMEZONE}
    ...          AND   Stop screen recording   ${TEST_STATUS}   ${TEST_NAME}

*** Keywords ***

Open Initial Setup
    Log out from laptop
    Switch to vm    ${GUI_VM}   user=${USER_LOGIN}
    Remove file     /home/${USER_LOGIN}/.config/cosmic-initial-setup-done   rc_match=skip
    Login to laptop   kill_setup=False

Check that ghaf-intro was launched
    [Setup]      Switch to vm    ${CHROME_VM}
    Check that the application was started   ghaf-intro  10
    [Teardown]   Run Keywords   Kill App By Name   ghaf-intro   sudo=True
    ...    AND   Switch to vm    ${GUI_VM}   user=${USER_LOGIN}

Check page and open next
    [Arguments]   ${page_name}
    Locate on screen  text   ${page_name}
    Click   wiggle=True

Save original timezone
    ${timezone}           Get timezone
    Set Suite Variable    ${ORIGINAL_TIMEZONE}   ${timezone}

Verify keyboard language
    [Documentation]   Get and return current keyboard layout from the COSMIC xkb config.
    [Arguments]       ${expected_language}
    ${output}         Run Command    cat ${KEYBOARD_CONFIG}
    ${matches}        Get Regexp Matches    ${output}    layout:\\s*\"([^\"]+)\"    1
    Should Be Equal   ${expected_language}  ${matches}[0]   Keyboard language is ${matches}[0], expected ${expected_language}

Save original keyboard
    [Documentation]   Save the current COSMIC keyboard config to a backup file and store the backup path.
    Run Command       cp ${KEYBOARD_CONFIG} ${ORIGINAL_KEYBOARD}

Restore keyboard config
    [Documentation]   Restore the COSMIC keyboard config from a backup file.
    Run Command       cp ${ORIGINAL_KEYBOARD} ${KEYBOARD_CONFIG}
    Run Command       rm -f ${ORIGINAL_KEYBOARD}

Verify theme
    [Arguments]   ${expected_theme}
    ${is_dark}    Run Command   cat /home/${USER_LOGIN}/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark
    ${theme}   Set Variable If  $is_dark == 'true'   dark   light
    Should Be Equal   ${expected_theme}   ${theme}   Theme is ${theme}, expected ${expected_theme}

Verify layout
    [Arguments]   ${layout}
    [Documentation]   Verify launcher position for the selected layout.
    IF   '${layout}' == 'top'
        Locate on screen    text    Workspaces   scale=3   iterations=3
    ELSE IF   '${layout}' == 'bottom'
        ${pass_status}  ${output}  Run Keyword And Ignore Error   Locate on screen   text   Workspaces   scale=3   iterations=3   debug_screenshot=False
        Should Be Equal   ${pass_status}   FAIL
    ELSE
        FAIL   Unsupported layout '${layout}'. Expected 'top' or 'bottom'.
    END
