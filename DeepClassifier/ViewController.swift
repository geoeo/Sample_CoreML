//
//  ViewController.swift
//  DeepClassifier
//
//  Created by Marc Haubenstock on 03/08/2017.
//  Copyright © 2017 Marc Haubenstock. All rights reserved.
//

import UIKit
import AVKit
import Vision
import os.log

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {
  
  
  let oslog : OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "unknown", category: "OSLOG - ViewController")
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    // Start up camera
    let captureSession = AVCaptureSession()
    captureSession.sessionPreset = AVCaptureSession.Preset.photo
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
    
    captureSession.addOutput(videoDataOutput)
    
    guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
    guard let captureInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
    
    captureSession.addInput(captureInput)
    captureSession.startRunning()
    
    // bind capture session to UI frame
    let previewLawyer = AVCaptureVideoPreviewLayer(session: captureSession)
    view.layer.addSublayer(previewLawyer)
    previewLawyer.frame = view.frame
    
  }
  
  
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
  
    
        let model = MobileNet() // 224 input size
//        let model = Resnet50() //224
//    let model = SqueezeNet() // 227 input size
    
    guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    guard let pixelBufferResize = resizeImage(image: pixelBuffer, width: 224, height: 224) else {
      return
      
    }
    
    if let prediction = try? model.prediction(image: pixelBufferResize) {
      print(prediction.classLabel)
    }
    
    
  }
  
  
  func resizeImage(image: CVPixelBuffer, width:Int,height:Int) -> CVPixelBuffer? {
    
    let ci_image = CIImage(cvPixelBuffer: image)
    let context = CIContext()
    
    guard let cgImg = context.createCGImage(ci_image, from: ci_image.extent) else {
      os_log("resizeImage: %@", log: self.oslog, type: .fault, "Could not create cg img")
      return nil
    }
    
    guard let cgContext = CGContext(data: nil,width: width,height: height,bitsPerComponent: cgImg.bitsPerComponent,bytesPerRow: cgImg.bytesPerRow,space: cgImg.colorSpace!,bitmapInfo: cgImg.bitmapInfo.rawValue) else {
      os_log("resizeImage: %@", log: self.oslog, type: .fault, "Could not create cgContext")
      
      return nil
    }
    
    
    cgContext.interpolationQuality = .high
    cgContext.draw(cgImg, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImgResized = cgContext.makeImage() else {
      os_log("writeARFrameToDisk: %@", log: self.oslog, type: .fault, "Unable to generate resized image")
      return nil
    }
    
    
    let imageResize = UIImage(cgImage: cgImgResized)
    return UIImageToPixelBuffer(image : imageResize)
    
  }
  
  // https://www.hackingwithswift.com/whats-new-in-ios-11
  func UIImageToPixelBuffer(image : UIImage) ->CVPixelBuffer?{
    
    
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard (status == kCVReturnSuccess) else { return nil}
    
    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
    
    context?.translateBy(x: 0, y: image.size.height)
    context?.scaleBy(x: 1.0, y: -1.0)
    
    UIGraphicsPushContext(context!)
    image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    
    return pixelBuffer
    
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
}

