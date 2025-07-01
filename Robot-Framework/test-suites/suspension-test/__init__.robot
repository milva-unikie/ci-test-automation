# SPDX-FileCopyrightText: 2022-2025 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation       Suspension test
Resource            ../../config/variables.robot
Resource            ../../resources/common_keywords.resource
Suite Setup         Set Variables   ${DEVICE}
Suite Teardown      Close All Connections