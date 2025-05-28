import CloudKit

extension CloudKitService {
    /// Copy old Category records from the *private-default* zone into *SnapTaskZone*,
    /// then delete them from the default zone. Safe to run multiple times.
    func migrateLegacyCategoriesIfNeeded() {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: categoryRecordType, predicate: predicate)

        // ① Read from default zone
        privateDatabase.perform(query,
                                inZoneWith: nil as CKRecordZone.ID?) { [weak self]
                                                           (records: [CKRecord]?,
                                                            error: Error?) in
            guard let self, let records, error == nil, !records.isEmpty else { return }

            var newRecords: [CKRecord] = []
            var oldIDs: [CKRecord.ID] = []

            for old in records {
                // clone into custom zone
                let newID = CKRecord.ID(recordName: old.recordID.recordName, zoneID: self.zoneID)
                let cloned = CKRecord(recordType: self.categoryRecordType, recordID: newID)
                cloned["name"]  = old["name"]
                cloned["color"] = old["color"]
                cloned["categoryID"] = old["categoryID"]
                newRecords.append(cloned)
                oldIDs.append(old.recordID)
            }

            // ② Save clones & delete originals atomically
            let op = CKModifyRecordsOperation(recordsToSave: newRecords, recordIDsToDelete: oldIDs)
            op.savePolicy = .allKeys
            op.modifyRecordsCompletionBlock = { _, _, error in
                if let error { print("Migration error: \(error)") }
                else         { print("Migration completed, moved \(newRecords.count) categories") }
            }
            self.privateDatabase.add(op)
        }
    }
}
