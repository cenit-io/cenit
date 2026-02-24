#!/usr/bin/env bash
set -euo pipefail

# This script verifies the database state after the E2E contact flow test.
# It checks if the "Contact" record and Data Type were handled correctly based on cleanup settings.

CENIT_E2E_CLEANUP="${CENIT_E2E_CLEANUP:-1}"
NAMESPACE="E2E_CONTACT_FLOW"
NAME="Contact"
RECORD_NAME="John Contact E2E"

echo "Running MongoDB verification (CLEANUP=$CENIT_E2E_CLEANUP)..."

# 1. Verification of Data Type (multi-collection aware)
DT_SEARCH=$(docker exec cenit-mongo_server-1 mongosh cenit --quiet --eval "
    let foundCol = null;
    let foundDt = null;
    db.getCollectionNames().forEach(col => {
        if (col.endsWith('_setup_data_types') && !col.startsWith('tmp_')) {
            let dt = db.getCollection(col).findOne({ namespace: '$NAMESPACE', name: '$NAME' });
            if (dt) {
                foundCol = col;
                foundDt = dt;
            }
        }
    });
    if (foundDt) {
        print('FOUND:' + foundCol + '|' + JSON.stringify(foundDt));
    } else {
        print('NOT_FOUND');
    }
")

if [[ "$DT_SEARCH" == "NOT_FOUND" ]]; then
    if [[ "$CENIT_E2E_CLEANUP" == "1" ]]; then
        echo "Cleanup verification PASSED: Data Type '$NAMESPACE | $NAME' not found (as expected)."
    else
        echo "ERROR: Data Type $NAMESPACE | $NAME not found in any collection." >&2
        exit 1
    fi
else
    COL_NAME=$(echo "$DT_SEARCH" | cut -d: -f2- | cut -d'|' -f1)
    DT_JSON=$(echo "$DT_SEARCH" | cut -d'|' -f2-)
    
    if [[ "$CENIT_E2E_CLEANUP" == "1" ]]; then
        echo "ERROR: Data Type $NAMESPACE | $NAME still exists in $COL_NAME but should have been cleaned up." >&2
        exit 1
    else
        echo "Data Type '$NAMESPACE | $NAME' verified in collection: $COL_NAME"
        
        # Schema Validation: Check for embedded schema OR snippet reference
        SCHEMA_VALID=$(docker exec cenit-mongo_server-1 mongosh cenit --quiet --eval "
            let dt = $DT_JSON;
            if (dt && (dt.schema || dt.snippet_id || dt.schema_id)) {
                print('VALID');
            } else {
                print('INVALID');
            }
        ")
        if [[ "$SCHEMA_VALID" == "VALID" ]]; then
            echo "Schema validation PASSED: Data Type has a defined schema or snippet reference."
        else
            echo "ERROR: Schema validation FAILED for Data Type '$NAMESPACE | $NAME' (no schema or snippet_id)." >&2
            exit 1
        fi
    fi
fi

# 2. Verify record cleanup (multi-collection aware)
# We search for the record name in all collections except system ones.
RECORD_SEARCH=$(docker exec cenit-mongo_server-1 mongosh cenit --quiet --eval "
    let found = false;
    db.getCollectionNames().forEach(col => {
        if (col.includes('_') && !col.startsWith('tmp_') && !col.startsWith('admin_') && col !== 'cenit_tokens') {
            let record = db.getCollection(col).findOne({ name: '$RECORD_NAME' });
            if (record) {
                print('FOUND_IN:' + col);
                found = true;
            }
        }
    });
    if (!found) print('CLEAN');
")

if [[ "$CENIT_E2E_CLEANUP" == "1" ]]; then
    if [[ "$RECORD_SEARCH" == "CLEAN" ]]; then
        echo "Cleanup verification PASSED: Record '$RECORD_NAME' not found in any related collection."
    else
        echo "ERROR: Record '$RECORD_NAME' still exists in collection: ${RECORD_SEARCH#FOUND_IN:}" >&2
        exit 1
    fi
else
    if [[ "$RECORD_SEARCH" != "CLEAN" ]]; then
        echo "Record verification PASSED: Record '$RECORD_NAME' exists in collection: ${RECORD_SEARCH#FOUND_IN:}"
    else
        echo "ERROR: Record '$RECORD_NAME' not found but should exist (CLEANUP=$CENIT_E2E_CLEANUP)." >&2
        exit 1
    fi
fi

echo "MongoDB verification completed successfully."
