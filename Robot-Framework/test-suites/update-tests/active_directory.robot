# SPDX-FileCopyrightText: 2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Verify Active Directory connectivity
Test Tags           active-directory  lenovo-x1  darter-pro

Resource            ../../resources/ssh_keywords.resource
Resource            ../../resources/device_control.resource
Resource            ../../resources/file_keywords.resource
Resource            ../../resources/update_keywords.resource
Resource            ../../resources/nixos_rebuild.resource

Suite Setup          Prepare Active Directory Rebuild
Suite Teardown       Restore Active Directory Rebuild


*** Test Cases ***

Confirm Active Directory connectivity
    [Documentation]    Navigate the interactive provisioning script and exit after its AD connectivity success message.
    [Setup]            Switch to vm  ${GUI_VM}
    [Timeout]          20 minutes
    TRY
        Elevate to superuser
        Log      Opening interactive user provisioning               console=True
        SSHLibrary.Write         user-provision
        SSHLibrary.Read Until    Join Active Directory domain
        Log      Selecting to join Active Directory domain           console=True
        SSHLibrary.Write Bare    \r
        SSHLibrary.Read Until    Select domain:
        SSHLibrary.Write Bare    \r
        Log      Domain selected, waiting for connectivity status    console=True
        Wait For AD Connectivity Result
    FINALLY
        # Press Ctrl+C to interrupt the script
        Run Keyword And Ignore Error    SSHLibrary.Write Bare    \x03
        SSHLibrary.Close Connection
    END

*** Keywords ***

Prepare Active Directory Rebuild
    Switch to vm              ${HOST}
    ${gen_before}             Get current generation
    Set Suite Variable        ${gen_before}
    Elevate to superuser
    Run Nix Shell             git
    Clone Ghaf Repository     ${REPOSITORY_PATH}   pull/ad-gpo  # ${COMMIT_HASH}
    Edit File                 ${REPOSITORY_PATH}/modules/reference/profiles/mvp-user-trial.nix  homed-user.enable = true;  homed-user.enable = false;
    Edit File                 ${REPOSITORY_PATH}/modules/reference/profiles/mvp-user-trial.nix  ad-users.enable = false;  ad-users.enable = true;
    Edit File                 ${REPOSITORY_PATH}/modules/reference/profiles/mvp-user-trial.nix  Reference services and personalization
    ...                       { systemd.services.user-provision-interactive.enable = lib.mkForce false; }  ${False}
    Run Nixos Rebuild         ${REPOSITORY_PATH}  intel-laptop-debug   login=False

Restore Active Directory Rebuild
    IF  '${SUITE_STATUS}'=='FAIL'
        Hard Reboot Device And Connect
    END
    Switch to vm    ${HOST}
    Run Keyword And Ignore Error    Remove Ghaf Repository    ${REPOSITORY_PATH}
    Roll back to original generation
    Soft Reboot Device And Connect
    Login to laptop

Wait For AD Connectivity Result
    [Documentation]    Keep terminal output in the keyword log and report a concise connectivity failure.
    TRY
        SSHLibrary.Read Until    AD server reachable:
    EXCEPT    *Cannot connect to AD backend*    type=GLOB
        FAIL    User provisioning could not connect to the configured LDAP/LDAPS backend
    EXCEPT    *Cannot reach AD server:*    type=GLOB
        FAIL    User provisioning could not ping the configured AD server
    EXCEPT    AS    ${error}
        FAIL    Active Directory connectivity test failed: ${error}
    ELSE
        Log    Connection to Active Directory server confirmed   console=True
    END
