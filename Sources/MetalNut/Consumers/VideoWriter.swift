//
//  VideoWriter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2020/05/22.
//

import AVFoundation
import Photos

/* add Audio */
public protocol AudioEncodingTarget {
    func activateAudioTrack()
    func processAudioBuffer(_ sampleBuffer:CMSampleBuffer)
}

public protocol VideoWriterDelegate {
    func currentDuration(duration: CMTime)
}

public class VideoWriter: ImageConsumer, AudioEncodingTarget {
    
    
    public var delegate: VideoWriterDelegate?
    
    let assetWriter:AVAssetWriter
    let assetWriterVideoInput:AVAssetWriterInput
    var assetWriterAudioInput:AVAssetWriterInput?

    let assetWriterPixelBufferInput:AVAssetWriterInputPixelBufferAdaptor
    
    let size:CGSize
    
    private var isRecording = false
    private var videoEncodingIsFinished = false
    private var audioEncodingIsFinished = false
    private var startTime:CMTime?
    private var previousFrameTime = CMTime.negativeInfinity
    private var previousAudioTime = CMTime.negativeInfinity
    private var encodingLiveVideo:Bool
    private var pixelBuffer:CVPixelBuffer? = nil
    
    private var renderPipelineState: MTLRenderPipelineState!

    var transform:CGAffineTransform {
        get {
            return assetWriterVideoInput.transform
        }
        set {
            assetWriterVideoInput.transform = newValue
        }
    }

    public var frameTime:CMTime?    // add Current recording time
    
    public init(URL:Foundation.URL, size:CGSize, fileType:AVFileType = AVFileType.mov) throws {
        self.size = size
        assetWriter = try AVAssetWriter(url:URL, fileType:fileType)
        
        assetWriterVideoInput = AVAssetWriterInput(mediaType:AVMediaType.video, outputSettings:[
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : size.width,
            AVVideoHeightKey : size.height,
            AVVideoCompressionPropertiesKey : [
                AVVideoAverageBitRateKey : 4166400,
            ],
            ])
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        encodingLiveVideo = true
        
        let sourcePixelBufferSetting = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey: size.width, kCVPixelBufferHeightKey: size.height ] as [String: Any]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:assetWriterVideoInput, sourcePixelBufferAttributes: sourcePixelBufferSetting)
        assetWriter.add(assetWriterVideoInput)
        
        renderPipelineState = MetalDevice.generateRenderPipelineState(vertexFunctionName: "oneInputVertex", fragmentFunctionName: "passthroughFragment", operationName: "VideoWriter")
        
    }
    
    public func startRecording(transform:CGAffineTransform? = nil) {
        if let transform = transform {
            assetWriterVideoInput.transform = transform
        }
        startTime = nil
        self.isRecording = self.assetWriter.startWriting()
    }
    
    public func finishRecording(_ completionCallback:((AVAsset?, CMTime?) -> ())? = nil) {
        self.isRecording = false
        if (self.assetWriter.status == .completed || self.assetWriter.status == .cancelled || self.assetWriter.status == .unknown) {
            DispatchQueue.global().async{
                print("in finishRecording completionCallback")
                completionCallback?(nil, nil)
            }
            return
        }
        if ((self.assetWriter.status == .writing) && (!self.videoEncodingIsFinished)) {
            self.videoEncodingIsFinished = true
            self.assetWriterVideoInput.markAsFinished()
        }
        if ((self.assetWriter.status == .writing) && (!self.audioEncodingIsFinished)) {
            self.audioEncodingIsFinished = true
            self.assetWriterAudioInput?.markAsFinished()
        }
        
        // Why can't I use ?? here for the callback?
        if let callback = completionCallback {
            self.assetWriter.finishWriting {
                let url = self.assetWriter.outputURL
                let asset = AVAsset(url: url)
                callback(asset, self.startTime!)
            }
        } else {
            self.assetWriter.finishWriting{}
        }
    }
    public func newTextureAvailable(_ texture: Texture, from source: ImageSource) {
        guard isRecording else { return }
		guard case .videoFrame(let frameTime) = texture.type,
			frameTime != previousFrameTime else { return }
        
        guard let pixelBufferPool = assetWriterPixelBufferInput.pixelBufferPool else { return }
        
        if (startTime == nil) {
            if (assetWriter.status != .writing) {
                assetWriter.startWriting()
            }
            print("newTextureAvailable assetWriter startSession")
            assetWriter.startSession(atSourceTime: frameTime)
            startTime = frameTime
        }
        
        self.frameTime = frameTime
        
        guard (assetWriterVideoInput.isReadyForMoreMediaData || (!encodingLiveVideo)) else {
            debugPrint("Had to drop a frame at time \(frameTime)")
            return
        }
        
        let duration = CMTimeSubtract(frameTime, self.startTime!)
        delegate?.currentDuration(duration: duration)
        
        var mPixelbuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &mPixelbuffer)
        guard status == kCVReturnSuccess, let pixelbuffer = mPixelbuffer else { return }
        
        CVPixelBufferLockBaseAddress(pixelbuffer, [])
        
        renderIntoPixelBuffer(pixelbuffer, texture: texture)
        
        if (!assetWriterPixelBufferInput.append(pixelbuffer, withPresentationTime:frameTime)) {
            print("Problem appending pixel buffer at time: \(frameTime)")
        }
        
        CVPixelBufferUnlockBaseAddress(pixelbuffer, [])
    }
    
    private func renderIntoPixelBuffer(_ pixelBuffer:CVPixelBuffer, texture:Texture) {
        guard let pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Could not get buffer bytes")
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
		let commandBuffer = MetalDevice.sharedCommandQueue.makeCommandBuffer()
		let outputTexture = Texture(device: MetalDevice.sharedDevice, width: Int(self.size.width), height: Int(self.size.height), type: texture.type)
		commandBuffer?.renderQuad(pipelineState: renderPipelineState, inputTexture: texture, outputTexture: outputTexture)
		commandBuffer?.commit()
		commandBuffer?.waitUntilCompleted()
        
        let region = MTLRegionMake2D(0, 0, outputTexture.metalTexture.width, outputTexture.metalTexture.height)
        outputTexture.metalTexture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
    }
    
    
    /* add audio */
    // MARK: -
    // MARK: Audio support
    
    public func activateAudioTrack() {
        assetWriterAudioInput = AVAssetWriterInput(mediaType:AVMediaType.audio, outputSettings:[
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey : 2,
            AVSampleRateKey : 44100.0,
            AVEncoderBitRateKey: 192000])
        assetWriter.add(assetWriterAudioInput!)
        assetWriterAudioInput?.expectsMediaDataInRealTime = true
    }
    
    public func processAudioBuffer(_ sampleBuffer:CMSampleBuffer) {
        guard let assetWriterAudioInput = assetWriterAudioInput, (assetWriterAudioInput.isReadyForMoreMediaData || (!self.encodingLiveVideo)) else {
            return
        }
        
        if (!assetWriterAudioInput.append(sampleBuffer)) {
            print("Trouble appending audio sample buffer")
        }
    }
    
    public func add(source: ImageSource) {}
    public func remove(source: ImageSource) {}
    
}

