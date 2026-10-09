# SPDX-FileCopyrightText: 2022-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Validates that individual VM failures are isolated and do not impact
...                 the availability, performance, or security of other VMs or the host system.
Test Tags           vm-isolation  lenovo-x1  darter-pro  dell-7330

Resource            ../../resources/app_keywords.resource
Resource            ../../resources/setup_keywords.resource
Resource            ../../resources/ssh_keywords.resource
Resource            ../../resources/service_keywords.resource

Suite Setup     VM Isolation Suite Setup

*** Test Cases ***

Stopping one VM does not affect others
    [Documentation]     Run application in some VM, stop another VM and check
    ...                 that it doesn't affect the first VM and app running
    [Tags]              SP-T286
    [Template]          Stopping one VM does not affect another
    ${Slack}            ${BUSINESS_VM}
    ${App Store}        ${CHROME_VM}
    ${Gala}             ${MEDIA_VM}
    ${Google Chrome}    ${COMMS_VM}
    [Teardown]          Ensure Robot sudoers is installed in all VMs   skip_boot_check=True

VM Nix store matches its provided closure
    [Documentation]    Compare each VM's visible store paths with the paths provided to its MicroVM process
    [Tags]             SP-T505
    [Template]         VM Nix store matches its provided closure
    FOR    ${vm}    IN    @{VM_LIST}
        ${vm}
    END

Host system path is not visible in VMs
    [Documentation]    Verify that the host's current system closure root does not leak into any VM
    [Tags]             SP-T506
    [Setup]            Set Host system path
    [Template]         Host system path is not visible in VMs
    FOR    ${vm}    IN    @{VM_LIST}
        ${vm}
    END

VM store paths are not available in other VMs
    [Documentation]    Verify that store paths do not leak from one VM to another
    [Tags]             SP-T507
    [Template]         VM store paths are not available in other VMs
    ${App Store}
    ${COSMIC System Monitor}
    ${Element}
    ${VPN}

*** Keywords ***

VM Isolation Suite Setup
    @{VM_LIST}    Get VM list
    Set Suite Variable    @{VM_LIST}

Stopping one VM does not affect another
    [Arguments]     ${app_key}   ${another_vm}
    Should Not Be Equal       ${app_key}[VM]    ${another_vm}    App is running in the VM that is going to be stopped
    Start App in VM           ${app_key}   always_check_vm=True
    Stop VM                   ${another_vm}
    ${state}  ${substate}     Verify service status  service=microvm@${app_key}[VM].service  expected_state=active  expected_substate=running
    Check that App is running in VM     ${app_key}   range=5
    [Teardown]    Run Keywords   Restart VM   ${another_vm}   start_only=True   restore_sudoers=False
    ...                    AND   Kill App in VM   ${app_key}   log_file=${APP_OUTPUT_FILE}   status=${KEYWORD_STATUS}

Stop VM
    [Documentation]         Try to stop VM and verify it stopped
    [Arguments]             ${vm}
    Switch to vm            ${HOST}
    Log                     Going to stop ${vm}    console=True
    Run Command             systemctl stop microvm@${vm}.service  sudo=True  timeout=120
    Sleep    3
    ${state}  ${substate}   Verify service status  service=microvm@${vm}.service  expected_state=inactive  expected_substate=dead
    Log                     ${vm} is ${substate}    console=True

VM Nix store matches its provided closure
    [Arguments]    ${vm}
    Switch to vm   ${HOST}
    ${provided_closure_hash}    Run Command   grep -ao 'paths=[^:]*' /proc/$(pgrep -f 'microvm@${vm} run' | head -1)/cmdline | cut -d= -f2 | xargs cat | sed 's|/nix/store/||' | sort | sha256sum

    Switch to vm    ${vm}
    ${visible_store_hash}    Run Command   ls /nix/.ro-store | grep -v '^lost+found$' | sort | sha256sum

    Should Be Equal    ${visible_store_hash}    ${provided_closure_hash}   ${vm} visible Nix store does not match the closure provided by the host

Set Host system path
    [Setup]   Switch to vm    ${HOST}
    ${host_system_path}    Run Command            basename "$(readlink /run/current-system)"
    Should Not Be Empty    ${host_system_path}    Failed to resolve the host's current system path
    Set Test Variable      ${HOST_SYSTEM_PATH}    ${host_system_path}

Host system path is not visible in VMs
    [Arguments]    ${vm}
    Switch to vm   ${vm}
    # For control check that VM sees its own closure
    ${vm_path}    Run Command    basename "$(readlink /run/current-system)"
    Check file exists           /nix/.ro-store/${vm_path}
    # Check that VM does not see host closure
    Check file doesn't exist    /nix/.ro-store/${HOST_SYSTEM_PATH}

VM store paths are not available in other VMs
    [Arguments]    ${app_key}
    FOR    ${vm}    IN    @{VM_LIST}
        Switch to vm   ${vm}
        ${paths}    Count visible store paths matching    ${app_key}[process_name]
        IF   '${vm}' == '${app_key}[VM]'
            Run Keyword And Continue On Failure
            ...    Should Be True    ${paths} > 0    Expected ${vm} to contain ${app_key}[process_name] store paths, found ${paths}
        ELSE
            Run Keyword And Continue On Failure
            ...    Should Be Equal As Integers    ${paths}    0     ${app_key}[VM] store paths leaked into ${vm}
        END
    END

Count visible store paths matching
    [Arguments]   ${pattern}
    ${count}      Run Command    ls /nix/.ro-store | grep -ci -- '${pattern}' || true
    Run Command    ls /nix/.ro-store | grep '${pattern}' || true   # For debugging
    RETURN        ${count}