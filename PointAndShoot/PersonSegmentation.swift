//
//  PersonSegmentation.swift
//  PointAndShoot
//
//  Person segmentation and silhouette generation using Vision
//

import Foundation
import Vision
import CoreImage
import UIKit

class PersonSegmentationHelper {
    
    // MARK: - Properties
    
    private var segmentationRequest: VNGeneratePersonSegmentationRequest?
    private let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    ])
    
    // MARK: - Initialization
    
    init() {
        setupRequest()
    }
    
    private func setupRequest() {
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest?.qualityLevel = .balanced
        segmentationRequest?.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }
    
    // MARK: - Segmentation
    
    /// Generate person segmentation mask from a pixel buffer
    func generateSegmentationMask(from pixelBuffer: CVPixelBuffer,
                                  orientation: CGImagePropertyOrientation,
                                  completion: @escaping (CVPixelBuffer?) -> Void) {
        
        guard let request = segmentationRequest else {
            completion(nil)
            return
        }
        
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                
                if let observation = request.results?.first as? VNPixelBufferObservation {
                    completion(observation.pixelBuffer)
                } else {
                    completion(nil)
                }
            } catch {
                print("Person segmentation error: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Silhouette Generation
    
    /// Creates a colored silhouette image from a segmentation mask
    func createSilhouetteImage(from pixelBuffer: CVPixelBuffer, color: UIColor) -> UIImage? {
        
        // Step 1: Create CIImage from the segmentation mask
        let maskImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = maskImage.extent
        
        // Step 2: Extract color components from UIColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Step 3: Use CIBlendWithMask filter (built-in, not deprecated)
        // This blends a solid color image with transparency using the mask
        
        // Create a solid color image
        let ciColor = CIColor(red: red, green: green, blue: blue, alpha: alpha)
        let colorImage = CIImage(color: ciColor).cropped(to: extent)
        
        // Create a transparent background
        let clearImage = CIImage(color: CIColor.clear).cropped(to: extent)
        
        // Use the mask to blend color with transparency
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            print("Failed to create CIBlendWithMask filter")
            return nil
        }
        
        blendFilter.setValue(colorImage, forKey: kCIInputImageKey)
        blendFilter.setValue(clearImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = blendFilter.outputImage else {
            print("Failed to apply blend filter")
            return nil
        }
        
        // Step 4: Crop to original dimensions
        let croppedImage = outputImage.cropped(to: extent)
        
        // Step 5: Convert to CGImage
        guard let cgImage = ciContext.createCGImage(croppedImage, from: extent) else {
            print("Failed to create CGImage")
            return nil
        }
        
        // Step 6: Convert to UIImage
        return UIImage(
            cgImage: cgImage,
            scale: UIScreen.main.scale,
            orientation: .up
        )
    }
}

// MARK: - Silhouette Data Model

struct PersonSilhouette {
    let playerID: UUID
    let image: UIImage
    let frame: CGRect  // Frame in screen coordinates
}

