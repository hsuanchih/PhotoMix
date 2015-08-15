//
//  TouchView.swift
//  PhotoMix
//
//  Created by Chuang HsuanChih on 8/11/15.
//  Copyright (c) 2015 Hsuan-Chih Chuang. All rights reserved.
//

import UIKit

extension UITouch {
    
    func compareAddress(obj:AnyObject) -> NSComparisonResult {
        
        if unsafeAddressOf(self) < unsafeAddressOf(obj) {
            return NSComparisonResult.OrderedAscending
        }
        else if unsafeAddressOf(self) == unsafeAddressOf(obj) {
            return NSComparisonResult.OrderedSame
        }
        else {
            return NSComparisonResult.OrderedDescending
        }
    }
}

class TouchView: UIView {

    static let horizontalMargin:CGFloat = 30, verticalMargin:CGFloat = 10
    
    lazy var originalTransform = {
        return CGAffineTransformIdentity
    }()
    lazy var touchBeginPoints = {
        return CFDictionaryCreateMutable(nil, 0, nil, nil)
    }()
    
    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    
    override init(frame: CGRect){
        super.init(frame: frame)
        self.baseSetup()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.baseSetup()
    }
    
    
    // MARK: Restore view properties
    func restoreProperties() {
        originalTransform = self.transform
    }
    
    private func baseSetup() {
        
        self.userInteractionEnabled = true
        self.multipleTouchEnabled = true
        self.exclusiveTouch = true
        self.clipsToBounds = true
        self.layer.cornerRadius = 10
        self.layer.borderColor = UIColor.grayColor().CGColor
        self.layer.borderWidth = 1
        self.backgroundColor = UIColor(white: 1, alpha: 1)
    }
    
    
    // MARK: UIResponder touch event handling
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        var currentTouches = NSMutableSet(set: event.touchesForView(self)!)
        currentTouches.minusSet(touches)
        if currentTouches.count > 0 {
            self.updateOriginalTransformForTouches(currentTouches)
            self.cacheBeginPointForTouches(currentTouches)
        }
        self.cacheBeginPointForTouches(touches)
    }
    
    override func touchesMoved(touches: Set<NSObject>, withEvent event: UIEvent) {
        let incrementalTransform = self.incrementalTransformWithTouches(event.touchesForView(self)!)
        self.transform = CGAffineTransformConcat(originalTransform, incrementalTransform)
    }
    
    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        for touch in touches as! Set<UITouch> {
            if touch.tapCount >= 2 {
                self.superview!.bringSubviewToFront(self)
            }
        }
        self.updateOriginalTransformForTouches(event.touchesForView(self)!)
        self.removeTouchesFromCache(touches)
        var remainingTouches = NSMutableSet(set: event.touchesForView(self)!)
        remainingTouches.minusSet(touches)
        self.cacheBeginPointForTouches(remainingTouches)
    }
    
    override func touchesCancelled(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        self.touchesEnded(touches, withEvent: event)
    }
    
    
    // MARK: View transformation update
    private func updateOriginalTransformForTouches(touches:NSSet)->Void {
        
        if touches.count > 0 {
            
            let incrementalTransform = self.incrementalTransformWithTouches(touches)
            self.transform = CGAffineTransformConcat(originalTransform, incrementalTransform)
            originalTransform = self.transform
        }
    }
    
    private func incrementalTransformWithTouches(touches:NSSet)->CGAffineTransform {
        
        let sortedTouches = touches.allObjects as NSArray
        sortedTouches.sortedArrayUsingSelector(NSSelectorFromString("compareAddress:"))
        let numTouches = sortedTouches.count
        
        if numTouches == 0 {
            return CGAffineTransformIdentity
        }
        
        if numTouches == 1 {
            let touch = sortedTouches[0] as! UITouch
            let beginPoint = UnsafePointer<CGPoint>(CFDictionaryGetValue(touchBeginPoints, unsafeAddressOf(touch))).memory
            let currentPoint = touch.locationInView(self.superview)
            return CGAffineTransformMakeTranslation(currentPoint.x - beginPoint.x, currentPoint.y - beginPoint.y)
        }
        
        let touch1 = sortedTouches[0] as! UITouch, touch2 = sortedTouches[1] as! UITouch;
        var beginPoint1 = CGPointMake(0, 0)
        let dictValue1 = CFDictionaryGetValue(touchBeginPoints, unsafeAddressOf(touch1))
        if dictValue1 != nil {
            beginPoint1 = UnsafePointer<CGPoint>(dictValue1).memory
        }
        let currentPoint1 = touch1.locationInView(self.superview)
        
        var beginPoint2 = CGPointMake(0, 0)
        let dictValue2 = CFDictionaryGetValue(touchBeginPoints, unsafeAddressOf(touch2))
        if dictValue2 != nil {
            beginPoint2 = UnsafePointer<CGPoint>(dictValue2).memory
        }
        let currentPoint2 = touch2.locationInView(self.superview)
        
        let layerX = self.center.x, layerY = self.center.y;
        
        let x1 = beginPoint1.x - layerX, y1 = beginPoint1.y - layerY;
        let x2 = beginPoint2.x - layerX, y2 = beginPoint2.y - layerY;
        let x3 = currentPoint1.x - layerX, y3 = currentPoint1.y - layerY;
        let x4 = currentPoint2.x - layerX, y4 = currentPoint2.y - layerY;
        
        // Solve the system:
        //   [a b t1, -b a t2, 0 0 1] * [x1, y1, 1] = [x3, y3, 1]
        //   [a b t1, -b a t2, 0 0 1] * [x2, y2, 1] = [x4, y4, 1]
        
        let D = (y1-y2)*(y1-y2) + (x1-x2)*(x1-x2);
        if D < 0.1 {
            return CGAffineTransformMakeTranslation(x3-x1, y3-y1);
        }
        
        let a = (y1-y2)*(y3-y4) + (x1-x2)*(x3-x4);
        let b = (y1-y2)*(x3-x4) - (x1-x2)*(y3-y4);
        let tx = (y1*x2 - x1*y2)*(y4-y3) - (x1*x2 + y1*y2)*(x3+x4) + x3*(y2*y2 + x2*x2) + x4*(y1*y1 + x1*x1);
        let ty = (x1*x2 + y1*y2)*(-y4-y3) + (y1*x2 - x1*y2)*(x3-x4) + y3*(y2*y2 + x2*x2) + y4*(y1*y1 + x1*x1);
        
        return CGAffineTransformMake(a/D, -b/D, b/D, a/D, tx/D, ty/D);
    }
    
    private func cacheBeginPointForTouches(touches:NSSet)->Void {
        
        if touches.count > 0 {
            for touch in touches {
                var dictValue = UnsafeMutablePointer<CGPoint>(CFDictionaryGetValue(touchBeginPoints, unsafeAddressOf(touch)))
                if dictValue == nil {
                    dictValue = UnsafeMutablePointer<CGPoint>(malloc(sizeof(CGPoint)))
                    CFDictionarySetValue(touchBeginPoints, unsafeAddressOf(touch) , UnsafePointer<Void>(dictValue));
                }
                dictValue.memory = touch.locationInView(self.superview)
            }
        }
    }
    
    private func removeTouchesFromCache(touches:NSSet)->Void {
        
        for touch in touches as! Set<UITouch> {
            
            let dictValue = CFDictionaryGetValue(touchBeginPoints, unsafeAddressOf(touch))
            if dictValue != nil {
                let point = UnsafePointer<CGPoint>(dictValue)
                free(UnsafeMutablePointer<Void>(dictValue))
                CFDictionaryRemoveValue(touchBeginPoints, unsafeAddressOf(touch))
            }
        }
    }

}
