#!/usr/bin/env bash
set -euo pipefail

# This script verifies the database state after the E2E integration journey test.

CENIT_E2E_CLEANUP="${CENIT_E2E_CLEANUP:-1}"
NAMESPACE="${CENIT_E2E_JOURNEY_NAMESPACE:-E2E_INTEGRATION}"
DT_NAME="${CENIT_E2E_JOURNEY_DATATYPE_NAME:-Lead}"
RECORD_NAME="${CENIT_E2E_JOURNEY_RECORD_NAME:-John Lead E2E}"

echo "Running MongoDB verification for Integration Journey (CLEANUP=$CENIT_E2E_CLEANUP)..."

# Verification helper
check_exists() {
    local col_pattern="$1"
    local query="$2"
    local label="$3"
    
    local found=$(docker exec cenit-mongo_server-1 mongosh cenit --quiet --eval "
        let found = false;
        db.getCollectionNames().forEach(col => {
            if (col.endsWith('$col_pattern') && !col.startsWith('tmp_')) {
                let doc = db.getCollection(col).findOne($query);
                if (doc) {
                    print('FOUND:' + col);
                    found = true;
                }
            }
        });
        if (!found) print('NOT_FOUND');
    ")
    
    if [[ "$found" == "NOT_FOUND" ]]; then
        if [[ "$CENIT_E2E_CLEANUP" == "1" ]]; then
            echo "PASSED: $label cleaned up."
        else
            echo "ERROR: $label NOT FOUND but should exist." >&2
            return 1
        fi
    else
        if [[ "$CENIT_E2E_CLEANUP" == "1" ]]; then
            echo "ERROR: $label STILL EXISTS in ${found#FOUND:} but should have been cleaned up." >&2
            return 1
        else
            echo "PASSED: $label verified in ${found#FOUND:}."
        fi
    fi
    return 0
}

# 1. Data Type
check_exists "_setup_data_types" "{ namespace: '$NAMESPACE', name: '$DT_NAME' }" "Data Type"

# 2. Template
check_exists "_setup_templates" "{ namespace: '$NAMESPACE', name: 'Lead_to_CRM' }" "Template"

# 3. Flow
check_exists "_setup_flows" "{ namespace: '$NAMESPACE', name: 'Export_Leads' }" "Flow"

# 4. Record
check_exists "" "{ name: '$RECORD_NAME' }" "Record"

echo "Integration Journey MongoDB verification completed successfully."
