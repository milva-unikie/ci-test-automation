# SPDX-FileCopyrightText: 2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Resource            ../resources/ssh_keywords.resource
Resource            ../resources/setup_keywords.resource
Resource            ../resources/device_control.resource

*** Variables ***
${REPOSITORY_PATH}   /persist/ghaf


*** Keywords ***

Run Nixos Rebuild
    [Arguments]      ${repo_path}  ${target_name}  ${interrupt}=${EMPTY}   ${login}=${IS_LAPTOP}
    ${no_output_timeout}  Set Variable    240
    ${no_output_start}    Set Variable    ${EMPTY}
    Elevate to superuser
    Run Nix Shell    git
    Write            cd ${repo_path}
    Sleep            0.5
    ${output}        SSHLibrary.Read
    Log To Console   Starting nixos-rebuild and monitoring build output
    Write            nixos-rebuild --flake .#${target_name} boot
    ${rebuild_ok}    Set Variable  ${False}
    FOR   ${i}  IN RANGE  300
        ${output}               SSHLibrary.Read
        IF  'exit status 1' in $output
            FAIL  error in nixos-rebuild
        END
        IF  ${i} > 0 and '[nix-shell:' in $output
            Log To Console      .
            Log To Console      nixos-rebuild finished
            ${rebuild_ok}    Set Variable  ${True}
            BREAK
        END
        # May have to answer "y" to multiple y/N questions
        IF  '(y/N)' in $output
            Write   y
            Sleep   0.5
        END
        IF  $output == '${EMPTY}'
            IF  $no_output_start == '${EMPTY}'
                ${no_output_start}      Get current timestamp
                Log To Console          No output
            ELSE
                ${current_time}         Get current timestamp
                ${no_output_time}       DateTime.Subtract Date From Date   ${current_time}  ${no_output_start}  exclude_millis=True
                IF  ${no_output_time} > ${no_output_timeout}
                    FAIL   nixos-rebuild was running without output ${no_output_timeout}s\nMight be stuck. Interrupting.
                END
            END
            Wait Until Keyword Succeeds  15s  3s  Verify Ping Host  ${DEVICE_IP_ADDRESS}  expected_status=${True}
            Sleep                   10
            Log To Console          .   no_newline=true
        ELSE
            ${no_output_start}      Set Variable    ${EMPTY}
            Log To Console          Output received
            Sleep                   10
        END
        IF  $interrupt != '${EMPTY}' and '${interrupt}' in $output
            Log To Console           Interrupting nixos-rebuild
            ${ctrl_c}                Evaluate    chr(int(3))
            SSHLibrary.Write Bare    ${ctrl_c}
            SSHLibrary.Read Until    [nix-shell:
            RETURN
        END
    END
    IF  not ${rebuild_ok}
        FAIL  nixos-rebuild didn't finish successfully withing the given time
    END
    Soft Reboot Device And Connect
    Run Keyword If    ${login}    Login to laptop

Clone Ghaf Repository
    [Arguments]               ${repo_path}    ${commit}=${EMPTY}
    Log To Console            Cloning ghaf repository
    Run Keyword And Ignore Error    Remove Ghaf Repository    ${repo_path}
    SSHLibrary.Read
    Write                     git clone https://github.com/gngram/ghaf.git ${repo_path}  # https://github.com/tiiuae/ghaf.git
    SSHLibrary.Read Until     Cloning
    Wait Until Keyword Succeeds    120s    1s    SSHLibrary.Read Until     [nix-shell:
    Sleep                     0.5
    Write                     cd ${repo_path}
    IF  $commit != '${EMPTY}' and $commit != 'NONE'
        Log                       Checking out commit ${commit}  console=True
        Write                     git checkout ${commit}
        #SSHLibrary.Read Until     HEAD is now at
        SSHLibrary.Read Until     [nix-shell:
    END

Remove Ghaf Repository
    [Arguments]    ${repo_path}
    Run Command     rm -rf ${repo_path}   sudo=True
