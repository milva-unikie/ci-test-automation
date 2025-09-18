# SPDX-FileCopyrightText: 2022-2025 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Library             ../lib/output_parser.py
Resource            ../resources/file_keywords.resource
Resource            ../resources/ssh_keywords.resource


*** Keywords ***

Start application in VM
    [Arguments]    ${app_name}   ${vm_name}   ${process_name}   ${exact_match}=false
    Check that appVM is running   ${vm_name}
    Switch to vm   ${GUI_VM}  user=${USER_LOGIN}
    Start XDG application   ${app_name}
    IF   '${vm_name}' != '${GUI_VM}'   Switch to vm   ${vm_name}
    Check that the application was started    ${process_name}   exact_match=${exact_match}

Check that appVM is running
    [Arguments]    ${vm_name}
    Switch to vm      ghaf-host
    Verify service status   range=15  service=microvm@${vm_name}.service
    ${pid}            Find pid by name     microvm@${vm_name}
    ${runtime_str}    Execute Command      ps -o etimes= -p ${pid}[0]
    ${runtime}        Convert To Integer   ${runtime_str}
    # givc-services are not running right after the VM has started.
    # This gives them time to start before app launch is tried.
    IF    $runtime < 15
        Log       ${vm_name} started ${runtime} seconds ago, waiting until it has been running for 15 seconds   console=True
        ${wait}   Evaluate    max(0, 15 - ${runtime})
        Sleep     ${wait}
    END

Start XDG application
    [Arguments]      ${app_name}
    Log To Console   ${\n}Starting ${app_name}
    ${app_name}      Check application name  ${app_name}
    ${output}        Execute Command    cat /run/current-system/sw/share/applications/${app_name}.desktop
    ${path}          Get App Path From Desktop  ${output}
    Execute Command  nohup sh -c 'WAYLAND_DISPLAY=wayland-1 ${path}' > output.log 2>&1 &

Check that the application was started
    [Arguments]          ${app_name}  ${range}=2  ${exact_match}=false
    FOR   ${i}   IN RANGE  ${range}
        @{found_pids}        Find pid by name    ${app_name}  ${exact_match}
        Set Global Variable  @{APP_PIDS}  @{found_pids}
        ${status}    Run Keyword And Return Status   Should Not Be Empty  ${APP_PIDS}
        IF    ${status}    BREAK
        Sleep   1
    END
    Should Not Be Empty  ${APP_PIDS}  ${app_name} is not started
    Log To Console       ${app_name} is started

Check that the application is not running
    [Arguments]          ${app_name}  ${range}=2  ${exact_match}=false
    ${pids}=  Set Variable  ${EMPTY}
    FOR   ${i}   IN RANGE  ${range}
        ${keyword_status}  ${pids}  Run Keyword And Ignore Error   Find pid by name    ${app_name}  ${exact_match}
        Set Global Variable  @{APP_PIDS}  @{pids}
        ${status}    Run Keyword And Return Status   Should Be Empty  ${pids}
        IF    ${status}    BREAK
        Sleep   1
    END
    Should Be Empty   ${pids}   ${app_name} is still running
    Log To Console    ${app_name} not running

Launch Cosmic Term
    Start application in VM   com.system76.CosmicTerm   ${GUI_VM}   cosmic-term   exact_match=true

Log and remove app output
    [Documentation]    Specify the VM from which the app was started and the user (the owner of the file)
    [Arguments]   ${file}    ${vm}    ${user}=ghaf
    Switch to vm  ${vm}    ${user}
    ${output}     Execute Command    cat ${file}
    Log           ${output}
    Remove file   ${file}

Log app vm journalctl
    [Documentation]    Specify the VM where the App is actually running
    [Arguments]   ${vm}
    Switch to vm  ${vm}
    ${output}     Execute Command    journalctl
    Log           ${output}

Get Falcon LLM Name
    ${output}            Execute Command     cat '/run/current-system/sw/share/applications/Falcon AI.desktop'
    ${line}              Get Lines Containing String  ${output}  Exec=
    ${path}              Set Variable  ${line[5:]}
    ${llm_name_raw}      Execute Command  cat ${path} | grep LLM_NAME | head -n 1
    # LLM_NAME="falcon3:10b" -> falcon3:10b
    ${tmp}               Fetch From Right  ${llm_name_raw}  =
    ${LLM_NAME}          Set Variable  ${tmp[1:-1]}
    Set Global Variable  ${LLM_NAME}

Check application name
    [Documentation]  Check written format of application
    [Arguments]  ${app_name}
    ${app_name}  Strip String  ${app_name}  characters="'
    ${output}    Execute Command    ls /run/current-system/sw/share/applications/
    ${app}       Get Regexp Matches  ${output}  (?im)${app_name}
    RETURN  '${app}[0]'
