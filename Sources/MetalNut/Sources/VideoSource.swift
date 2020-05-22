//
//  VideoSource.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2020/01/23.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import AVFoundation

public typealias VideoSourceProgress = (CMTime) -> Void
public typealias VideoSourceCompletion = (Bool) -> Void

/// Video source reading video frame and providing Metal texture
public class VideoSource {
    /// Image consumers
    public var consumers: [ImageConsumer] {
        lock.wait()
        let c = _consumers
        lock.signal()
        return c
    }
    private var _consumers: [ImageConsumer]
    
    private let url: URL
    private let lock: DispatchSemaphore
    
    private var asset: AVAsset!
    private var assetReader: AVAssetReader!
    private var videoOutput: AVAssetReaderTrackOutput!
    
    private var audioOutput: AVAssetReaderTrackOutput!
    private var lastAudioBuffer: CMSampleBuffer?
	private var displayLink: CADisplayLink?
	
	var progress: VideoSourceProgress?
	var completion: VideoSourceCompletion?
    
    /// Audio consumer processing audio sample buffer.
    /// Set this property to nil (default value) if not processing audio.
    /// Set this property to a given audio consumer if processing audio.
    public var audioEncodingTarget: AudioEncodingTarget? {
		didSet {
			audioEncodingTarget?.activateAudioTrack()
		}
    }
    
    /// Whether to process video with the actual rate. False by default, meaning the processing speed is faster than the actual video rate.
    public var playWithVideoRate: Bool {
        get {
            lock.wait()
            let p = _playWithVideoRate
            lock.signal()
            return p
        }
        set {
            lock.wait()
            _playWithVideoRate = newValue
            lock.signal()
        }
    }
    private var _playWithVideoRate: Bool
    
    private var lastSampleFrameTime: CMTime!
    private var lastActualPlayTime: Double!
    
    private var textureCache: CVMetalTextureCache!
    
    public init?(url: URL) {
        _consumers = []
        self.url = url
        lock = DispatchSemaphore(value: 1)
        _playWithVideoRate = true
		initializeTextureCache()
    }
    
    /// Starts reading and processing video frame
    ///
    /// - Parameter completion: a closure to call after processing; The parameter of closure is true if succeed processing all video frames, or false if fail to processing all the video frames (due to user cancel or error)
    public func start(progress: VideoSourceProgress? = nil, completion: VideoSourceCompletion? = nil) {
        lock.wait()
        let isReading = (assetReader != nil)
        lock.signal()
        if isReading {
            print("Should not call \(#function) while asset reader is reading")
            return
        }
		self.progress = progress
		self.completion = completion
		
        let asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            guard let self = self else { return }
            if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded,
                asset.tracks(withMediaType: .video).first != nil {
                DispatchQueue.global().async { [weak self] in
                    guard let self = self else { return }
                    self.lock.wait()
                    self.asset = asset
                    if self.prepareAssetReader() {
                        self.lock.signal()
                        self.startDisplayLink()
                    } else {
                        self.reset()
                        self.lock.signal()
                    }
                }
            } else {
                self.safeReset()
            }
        }
    }
    
    /// Cancels reading and processing video frame
    public func cancel() {
        lock.wait()
        if let reader = assetReader,
            reader.status == .reading {
            reader.cancelReading()
            reset()
        }
        lock.signal()
    }
    
    private func safeReset() {
        lock.wait()
        reset()
        lock.signal()
    }
    
    private func reset() {
        asset = nil
        assetReader = nil
        videoOutput = nil
        audioOutput = nil
        lastAudioBuffer = nil
		progress = nil
		completion = nil
    }
    
    private func prepareAssetReader() -> Bool {
        guard let reader = try? AVAssetReader(asset: asset),
            let videoTrack = asset.tracks(withMediaType: .video).first else { return false }
        assetReader = reader
        videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA])
        videoOutput.alwaysCopiesSampleData = false
        if !assetReader.canAdd(videoOutput) { return false }
        assetReader.add(videoOutput)
        
        if audioEncodingTarget != nil,
            let audioTrack = asset.tracks(withMediaType: .audio).first {
            audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey : kAudioFormatLinearPCM])
            audioOutput.alwaysCopiesSampleData = false
            if !assetReader.canAdd(audioOutput) { return false }
            assetReader.add(audioOutput)
        }
        return true
    }
	
	
	@discardableResult
    private func initializeTextureCache() -> Bool {
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MetalDevice.sharedDevice, nil, &textureCache)
        return result == kCVReturnSuccess
    }
	
	private func startDisplayLink() {
		lock.wait()
        guard let reader = assetReader,
            reader.status == .unknown,
            reader.startReading() else {
            reset()
            lock.signal()
            return
        }
        lock.signal()
		displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink))
		displayLink?.preferredFramesPerSecond = 30
		displayLink?.add(to: .main, forMode: .common)
	}
	
	private func stopDisplayLink() {
		displayLink?.invalidate()
		displayLink = nil
	}
	
	@objc
	private func updateDisplayLink() {
		let useVideoRate = _playWithVideoRate
		var sleepTime: Double = 0
		guard assetReader.status == .reading,
			let sampleBuffer = self.videoOutput.copyNextSampleBuffer() else {
				stopDisplayLink()
				if let consumer = self.audioEncodingTarget,
					let audioBuffer = self.lastAudioBuffer {
					consumer.processAudioBuffer(audioBuffer)
				}
				
				while let consumer = self.audioEncodingTarget,
					assetReader.status == .reading,
					self.audioOutput != nil,
					let audioBuffer = self.audioOutput.copyNextSampleBuffer() {
						consumer.processAudioBuffer(audioBuffer)
				}
				var finish = false
				if self.assetReader != nil {
					self.reset()
					finish = true
				}
				completion?(finish)
				return
		}
		let sampleFrameTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
		if useVideoRate {
			if let lastFrameTime = self.lastSampleFrameTime,
				let lastPlayTime = self.lastActualPlayTime {
				let detalFrameTime = CMTimeGetSeconds(CMTimeSubtract(sampleFrameTime, lastFrameTime))
				let detalPlayTime = CACurrentMediaTime() - lastPlayTime
				if detalFrameTime > detalPlayTime {
					sleepTime = detalFrameTime - detalPlayTime
					usleep(UInt32(1000000 * sleepTime))
				} else {
					sleepTime = 0
				}
			}
			self.lastSampleFrameTime = sampleFrameTime
			self.lastActualPlayTime = CACurrentMediaTime()
		}
		
		var currentAudioBuffer: CMSampleBuffer?
		if self.audioEncodingTarget != nil {
			if let last = self.lastAudioBuffer,
				CMTimeCompare(CMSampleBufferGetOutputPresentationTimeStamp(last), sampleFrameTime) <= 0 {
				// Process audio buffer
				currentAudioBuffer = last
				self.lastAudioBuffer = nil

			} else if self.lastAudioBuffer == nil,
				self.audioOutput != nil,
				let audioBuffer = self.audioOutput.copyNextSampleBuffer() {
				if CMTimeCompare(CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer), sampleFrameTime) <= 0 {
					// Process audio buffer
					currentAudioBuffer = audioBuffer
				} else {
					// Audio buffer goes faster than video
					// Process audio buffer later
					self.lastAudioBuffer = audioBuffer
				}
			}
		}
		if let audioBuffer = currentAudioBuffer { self.audioEncodingTarget?.processAudioBuffer(audioBuffer) }
		if let texture = createTexture(with: sampleBuffer) {
			print("ext 2")
			let output = Texture(mtlTexture: texture.metalTexture, type: texture.type)
			for consumer in consumers { consumer.newTextureAvailable(output, from: self) }
			progress?(sampleFrameTime)
		}
	}
    
    private func createTexture(with sampleBuffer: CMSampleBuffer) -> Texture? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
			let textureCache = textureCache else { return nil }
		let bufferWidth = CVPixelBufferGetWidth(imageBuffer)
		let bufferHeight = CVPixelBufferGetHeight(imageBuffer)
		let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
		var imageTexture: CVMetalTexture?
		let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, .bgra8Unorm, bufferWidth, bufferHeight, 0, &imageTexture)
		guard
			let unwrappedImageTexture = imageTexture,
			let textureRef = CVMetalTextureGetTexture(unwrappedImageTexture),
			result == kCVReturnSuccess
			else {
				return nil
		}
		return Texture(mtlTexture: textureRef, type: .videoFrame(timestamp: timestamp))
    }
}

extension VideoSource: ImageSource {
    @discardableResult
    public func add<T: ImageConsumer>(consumer: T) -> T {
        lock.wait()
        _consumers.append(consumer)
        lock.signal()
        consumer.add(source: self)
        return consumer
    }
    
    public func add(consumer: ImageConsumer, at index: Int) {
        lock.wait()
        _consumers.insert(consumer, at: index)
        lock.signal()
        consumer.add(source: self)
    }
    
    public func remove(consumer: ImageConsumer) {
        lock.wait()
        if let index = _consumers.firstIndex(where: { $0 === consumer }) {
            _consumers.remove(at: index)
            lock.signal()
            consumer.remove(source: self)
        } else {
            lock.signal()
        }
    }
    
    public func removeAllConsumers() {
        lock.wait()
        let consumers = _consumers
        _consumers.removeAll()
        lock.signal()
        for consumer in consumers {
            consumer.remove(source: self)
        }
    }
}
