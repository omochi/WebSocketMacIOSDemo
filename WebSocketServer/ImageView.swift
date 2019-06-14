//
//  ImageView.swift
//  WebSocketServer
//
//  Created by omochimetaru on 2019/06/14.
//  Copyright © 2019 omochimetaru. All rights reserved.
//

import Cocoa

class ImageView: NSView {
    var image: NSImage? {
        didSet {
            layer!.contents = image
        }
    }
    
    var contentsGravity: CALayerContentsGravity = .resizeAspect {
        didSet {
            layer!.contentsGravity = contentsGravity
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        didInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        didInit()
    }
    
    private func didInit() {
        let layer = CALayer()
        self.layer = layer
        layer.contentsGravity = CALayerContentsGravity.resizeAspect
        self.wantsLayer = true
    }
}
