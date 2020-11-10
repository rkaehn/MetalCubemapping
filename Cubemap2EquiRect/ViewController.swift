//
//  ViewController.swift
//  Cubemap2EquiRect
//
//  Created by Mark Lim Pak Mun on 11/11/2020.
//  Copyright © 2020 Mark Lim Pak Mun. All rights reserved.
//

import Cocoa
import MetalKit
import AVFoundation

class ViewController: NSViewController {
    @IBOutlet var mtkView: MTKView!
    var renderer: Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        mtkView.framebufferOnly = false
        // Configure
        mtkView.colorPixelFormat = .rgba16Float
        mtkView.depthStencilPixelFormat = .depth32Float
        renderer = Renderer(view: mtkView,
                            device: device)

        // The instruction below is necessary.
        mtkView.delegate = renderer
        
        let size = mtkView.drawableSize
        // Ensure the view and projection matrices are setup
        renderer.mtkView(mtkView,
                         drawableSizeWillChange: size)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    override func viewDidAppear() {
        self.mtkView.window!.makeFirstResponder(self)
    }

    func heicData(from cgImage: CGImage?,
                  compressionQuality: Float) -> Data? {
         let destinationData = NSMutableData()

         guard
             let cgImage = cgImage,
             let destination = CGImageDestinationCreateWithData(destinationData,
                                                                AVFileType.heic as CFString,
                                                                1,
                                                                nil)
         else {
             return nil
         }

         let options = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
         CGImageDestinationAddImage(destination,
                                    cgImage,
                                    options as CFDictionary)
         CGImageDestinationFinalize(destination)

         return destinationData as Data
     }

    // The instantiated CGImage bpc=8, bpp=32 not rgba16
    func createCGImage(from ciImage: CIImage) -> CGImage? {
        let ciContext = CIContext()
        let cgRect = ciImage.extent
        let cgImage = ciContext.createCGImage(ciImage,
                                              from: cgRect,
                                              format: kCIFormatRGBA16,
                                              colorSpace: CGColorSpaceCreateDeviceRGB())
        return cgImage
    }

    func writeTexture(_ texture2D: MTLTexture,
                      with fileName: String,
                      at directoryURL: URL) {
        let name = fileName + ".heic"
        let url = directoryURL.appendingPathComponent(name)
        // Note: the pixel format of the mtl texture is rgba16Float.
        var ciImage = CIImage(mtlTexture: texture2D,
                              options: nil)!
        // We need to flip the image vertically.
        var transform = CGAffineTransform(translationX: 0.0,
                                          y: ciImage.extent.height)
        transform = transform.scaledBy(x: 2.0, y: -1.0)
        //ciImage = ciImage.transformed(by: transform, highQualityDownsample: true)
        ciImage = ciImage.transformed(by: transform)
        let cgImage = createCGImage(from: ciImage)
        let data = heicData(from: cgImage,
                            compressionQuality: 0.5)
        do {
            try data?.write(to: url)
        }
        catch let error {
            print("Can't save the compressed graphic file: \(error)")
        }
    }

    // As soon as the view of the equirectangular map appears, pressing
    // "s" or "S" will allow the user to save it as a graphic.
    override func keyDown(with event: NSEvent) {
        let chars = event.characters
        let index0 = chars?.startIndex
        if chars![index0!] == "s" || chars![index0!] == "S" {
            guard let texture = renderer.equiRectangularTexture
            else {
                super.keyDown(with: event)
                return
            }
            let op = NSSavePanel()
            op.canCreateDirectories = true
            op.nameFieldStringValue = "image"
            let buttonID = op.runModal()
            if buttonID == NSApplication.ModalResponse.OK {
                let fileName = op.nameFieldStringValue
                let folderURL = op.directoryURL!
                writeTexture(texture,
                             with: fileName,
                             at: folderURL)
            }
        }
        else {
            super.keyDown(with: event)
        }
    }
}

