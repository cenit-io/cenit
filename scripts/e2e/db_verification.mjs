import { execSync } from 'node:child_process';

/**
 * Verifies if a record exists in MongoDB using docker exec.
 * @param {string} recordName The name of the record to search for.
 * @returns {Object} { found: boolean, collection: string | null }
 */
export function verifyRecordDeletion(recordName) {
    console.log(`Verifying deletion of record: ${recordName}`);
    try {
        const query = `
            let found = false;
            let foundCol = null;
            db.getCollectionNames().forEach(col => {
                if (col.includes('_') && !col.startsWith('tmp_') && !col.startsWith('admin_') && col !== 'cenit_tokens') {
                    let record = db.getCollection(col).findOne({ name: '${recordName}' });
                    if (record) {
                        found = true;
                        foundCol = col;
                    }
                }
            });
            if (found) {
                print('FOUND_IN:' + foundCol);
            } else {
                print('CLEAN');
            }
        `;
        const result = execSync(`docker exec cenit-mongo_server-1 mongosh cenit --quiet --eval "${query.replace(/"/g, '\\"').replace(/\n/g, ' ')}"`, { encoding: 'utf8' }).trim();

        if (result === 'CLEAN') {
            return { found: false, collection: null };
        } else if (result.startsWith('FOUND_IN:')) {
            return { found: true, collection: result.replace('FOUND_IN:', '') };
        }
    } catch (e) {
        console.error('Error verifying record deletion:', e.message);
    }
    return { found: true, collection: 'unknown (error)' }; // Assume it exists if we can't check
}

/**
 * Verifies if a Data Type exists and optionally validates its schema.
 * @param {string} namespace 
 * @param {string} name 
 * @returns {Object} { found: boolean, collection: string | null, valid: boolean }
 */
export function verifyDataType(namespace, name) {
    console.log(`Verifying Data Type: ${namespace} | ${name}`);
    try {
        const query = `
            let foundCol = null;
            let foundDt = null;
            db.getCollectionNames().forEach(col => {
                if (col.endsWith('_setup_data_types') && !col.startsWith('tmp_')) {
                    let dt = db.getCollection(col).findOne({ namespace: '${namespace}', name: '${name}' });
                    if (dt) {
                        foundCol = col;
                        foundDt = dt;
                    }
                }
            });
            if (foundDt) {
                let valid = (foundDt.schema || foundDt.snippet_id || foundDt.schema_id) ? true : false;
                print('FOUND:' + foundCol + '|' + valid);
            } else {
                print('NOT_FOUND');
            }
        `;
        const result = execSync(`docker exec cenit-mongo_server-1 mongosh cenit --quiet --eval "${query.replace(/"/g, '\\"').replace(/\n/g, ' ')}"`, { encoding: 'utf8' }).trim();

        if (result === 'NOT_FOUND') {
            return { found: false, collection: null, valid: false };
        } else if (result.startsWith('FOUND:')) {
            const [_, rest] = result.split('FOUND:');
            const [col, validStr] = rest.split('|');
            return { found: true, collection: col, valid: validStr === 'true' };
        }
    } catch (e) {
        console.error('Error verifying Data Type:', e.message);
    }
    return { found: true, collection: 'unknown (error)', valid: false };
}
