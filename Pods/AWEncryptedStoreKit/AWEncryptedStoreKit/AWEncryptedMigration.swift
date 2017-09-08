//
//  AWEncryptedMigration.swift
//  AWEncryptedStoreKit
//
//  Created by Stephen Turner on 5/2/17.
//
//

import Foundation
import CoreData


public class AWEncryptedDataMigration {
    
    private let storeUrl: URL
    private let storeType: String

    public init(_ storeUrl:URL, storeType: String) {
        self.storeUrl = storeUrl
        self.storeType = storeType

    }
    
    //support stores of type NSSQLiteStoreType, NSBinaryStoreType
    public func canMigrateData() -> Bool {
        guard [NSSQLiteStoreType, NSBinaryStoreType].contains(storeType) else {
            log(warning: "cannot migrate data for storeType \(storeType)")
            return false
        }        
        return FileManager.default.fileExists(atPath: storeUrl.path)
    }
    
    private func migrateData(withModel model: NSManagedObjectModel, fromContext: NSManagedObjectContext,
                             toContext: NSManagedObjectContext) -> Bool {

        var migrated = true
        let cache = NSMutableDictionary()
        for entity in model.entities {
            guard let entityName = entity.name else {
                log(error:" failed to parse entitys name for entity: \(entity)")
                return false
            }
            do {
                let allEntityObjs = try fromContext.fetch(NSFetchRequest(entityName: entityName))
                
                for obj in allEntityObjs {
                    guard let mobj = obj as? NSManagedObject else {
                        log(error:" failed to cast to NSManagedObject for obj: \(obj)")
                        return false
                    }
                    _ = copyToTarget(source: mobj, targetContext: toContext, cache: cache)
                }
            }catch let e{
                log(error: "could not migrate data for entity \(entity), error=\(e)")
                migrated = false
            }
        }
        
        guard migrated else {
            return false
        }
        
        do{
            try toContext.save()
        }catch let e{
            migrated = false
            log(error: "could not migrate core data \(e)")
        }
        return migrated
    }
    
    
    private func copyToTarget(source: NSManagedObject, targetContext: NSManagedObjectContext, cache: NSMutableDictionary) -> NSManagedObject? {

        if let targetId = cache.object(forKey: source.objectID){
            log(debug: "found target in cache \(source.objectID)")
            
            guard let targetIdentifier = targetId as? NSManagedObjectID
                else {
                log(error:" failed to parse target identifier as NSManagedObjectID: \(targetId)")
                return nil
            }
            return targetContext.object(with: targetIdentifier)
        }
        
        let entityDesc = source.objectID.entity
        let attrKeys:[String] = entityDesc.attributesByName.keys.map({ key in
            return key
        })
        guard let entityName = entityDesc.name else {
            log(error:" failed to parse entitys name for entity: \(entityDesc)")
            return nil
        }
        let attrKeysAndVals = source.dictionaryWithValues(forKeys: attrKeys)
        log(debug: "creating target for source \(source.objectID)")
        let target = NSEntityDescription.insertNewObject(forEntityName: entityName, into: targetContext)
        target.setValuesForKeys(attrKeysAndVals)
        cache.setObject(target.objectID, forKey: source.objectID)
    
        for (name, rel) in entityDesc.relationshipsByName {
            if rel.isToMany {
                let targetMany = target.mutableSetValue(forKey: name)
                let srcMany = source.mutableSetValue(forKey: name)
                for obj in srcMany {
                    guard let srcObj = obj as? NSManagedObject else {
                        log(error:" failed to cast to NSManagedObject for srcObj: \(obj)")
                        return nil
                    }
                    if let targetObj = copyToTarget(source: srcObj, targetContext: targetContext, cache: cache) {
                        targetMany.add(targetObj)
                    }
                }
            } else {
                guard
                    let srcObj = source.value(forKey: name) as? NSManagedObject,
                    let targetObj = copyToTarget(source: srcObj, targetContext: targetContext, cache: cache) else {
                        log(error:" failed to migrate to target object from Source object: \(String(describing: source.value(forKey: name) as? NSManagedObject))")
                        return nil
                    }
                    target.setValue(targetObj, forKey: name)
                }
            }
    
        return target
    
    }
    

    
    
    public func migrateData(toCoordinator: NSPersistentStoreCoordinator) throws -> Bool {

        let targetModel = toCoordinator.managedObjectModel
        
        let srcCoordinator = NSPersistentStoreCoordinator(managedObjectModel: targetModel)
        
        _ = try srcCoordinator.addPersistentStore(ofType: self.storeType, configurationName: nil, at: self.storeUrl, options: nil)

        let srcContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        srcContext.persistentStoreCoordinator = srcCoordinator
        
        let targetContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        targetContext.persistentStoreCoordinator = toCoordinator
        
        let migrated = migrateData(withModel: targetModel, fromContext: srcContext, toContext: targetContext)
        
        try srcCoordinator.destroyPersistentStore(at: self.storeUrl, ofType: self.storeType, options: nil)
        _ = cleanup()
        return migrated
    }
    
    private func cleanup() -> Bool {
        var success = false
        do{
            try FileManager.default.removeItem(at: storeUrl)
            success = true
        }catch let e{
            log(error: "could not delete plain db \(e)")
        }
        return success
    }
    
    public func saveKey(_ key:String){
        let keyLoc = storeUrl.deletingLastPathComponent().appendingPathComponent("dbkey.txt")
        do{
            try key.write(to: keyLoc, atomically: false, encoding: String.Encoding.utf8)
        }catch let e{
            log(error: "could not save dbkey \(e)")
        }
        
    }
    
}
