//
//  DataManager.swift
//  PhotoMix
//
//  Created by Chuang HsuanChih on 8/14/15.
//  Copyright (c) 2015 Hsuan-Chih Chuang. All rights reserved.
//

import UIKit

class DataManager: NSObject {
    
    static let manager = DataManager()
   
    private func userDocumentDirectory() -> String {
        let userDocumentDirectory = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        return userDocumentDirectory[0] as! String
    }
    
    private func archivePath() -> String {
        return self.userDocumentDirectory() + "CanvasArchive"
    }
    
    func hasValidArchive()->Bool {
        return NSFileManager.defaultManager().fileExistsAtPath(self.archivePath())
    }
    
    func invalidateArchive() {
        let archivePath = self.archivePath()
        if NSFileManager.defaultManager().fileExistsAtPath(archivePath) {
            NSFileManager.defaultManager().removeItemAtPath(archivePath, error: nil)
        }
    }
    
    func archiveCanvas(canvas:UIView) {
        
        // Invalidate archive
        self.invalidateArchive()
        
        // Archive views to CanvasArchive
        let archiveData = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWithMutableData: archiveData)
        var index = 0
        for view in canvas.subviews {
            archiver.encodeObject(view, forKey: String(index))
            index++
        }
        archiver.finishEncoding()
        let status = archiveData.writeToFile(self.archivePath(), atomically: true)
    }
    
    func unarchiveCanvas()->NSArray? {
        
        let archivePath = self.archivePath()
        if NSFileManager.defaultManager().fileExistsAtPath(archivePath) {
            let unarchiver = NSKeyedUnarchiver(forReadingWithData: NSData(contentsOfFile: archivePath)!)
            let viewArray = NSMutableArray()
            var index = 0
            var view: AnyObject? = unarchiver.decodeObjectForKey(String(index))
            while view != nil {
                let touchView = view as! TouchView
                touchView.restoreProperties()
                viewArray.addObject(touchView)
                index++
                view = unarchiver.decodeObjectForKey(String(index))
            }
            unarchiver.finishDecoding()
            return viewArray
        }
        return nil
    }
}
