//
//  Camera.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/05.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import AVFoundation

public class Camera: NSObject {
    
    private let lock = DispatchSemaphore(value: 1)
    
    /// Image consumers
    public var consumers: [ImageConsumer] {
        lock.wait()
        let c = _consumers
        lock.signal()
        return c
    }
    private var _consumers: [ImageConsumer]
    
    
    // capture session
    var captureSession: AVCaptureSession?
    
    // Processing Queue
    let cameraProcessingQueue = DispatchQueue.global()
    let audioProcessingQueue = DispatchQueue.global()
    let cameraFrameProcessingQueue = DispatchQueue(label: "com.thirtyninedegreesc.framework.MetalNut.cameraFrameProcessingQueue")
    let cameraPhotoProcessingQueue = DispatchQueue(label: "com.thirtyninedegreesc.framework.MetalNut.cameraPhotoProcessingQueue")
    
    // Device
    var audioDevice: AVCaptureDevice?
    var audioDeviceInput: AVCaptureDeviceInput?
    
    var frontCamera: AVCaptureDevice?
    var frontCameraInput: AVCaptureDeviceInput?
    
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    
    // Output
    var videoDataOutput: AVCaptureVideoDataOutput?
    var photoOutput: AVCapturePhotoOutput?
    var audioOutput: AVCaptureAudioDataOutput?
    
    var textureCache: CVMetalTextureCache?
    
    let minimumZoom: CGFloat = 1
    let maximumZoom: CGFloat = 3
    var lastZoomFactor: CGFloat = 1
    
    public var audioEncodingTarget: AudioEncodingTarget? {
        didSet {
            audioEncodingTarget?.activateAudioTrack()
        }
    }
    
    let sessionPreset: AVCaptureSession.Preset
    var cameraPosition: AVCaptureDevice.Position
    private var orientation: AVCaptureVideoOrientation
    
    public init(sessionPreset: AVCaptureSession.Preset, position: AVCaptureDevice.Position = .back, orientation: AVCaptureVideoOrientation = .portrait) throws {
        self.sessionPreset = sessionPreset
        self.cameraPosition = position
        self.orientation = orientation
        
        _consumers = []
        
        super.init()
        
        initializeTextureCache()
        
        createCaptureSession()
        try configureCaptureDevices()
        try configureDeviceInputs()
        try configureFrameOutput()
        try configureAudioOutput()
        try configurePhotoOutput()
        self.captureSession?.commitConfiguration()
    }
    
    public func startCapture() {
        if let session = self.captureSession, !session.isRunning {
            session.startRunning()
        }
    }
    
    public func stopCapture() {
        if let session = self.captureSession, session.isRunning {
            session.stopRunning()
        }
    }
}

/// MARK: - Public Methods
extension Camera {
    
    public func takePhoto(with settings: AVCapturePhotoSettings? = nil) {
        let settings = settings ?? AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    public func switchCameras() throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
        
        captureSession.beginConfiguration()
        
        func switchToFrontCamera() throws {
            
            guard let rearCameraInput = self.rearCameraInput, captureSession.inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else { throw CameraError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                
                self.cameraPosition = .front
                captureSession.outputs.first?.connections.first?.videoOrientation = self.orientation
                captureSession.outputs.first?.connections.first?.isVideoMirrored = true
            }
                
            else {
                throw CameraError.invalidOperation
            }
        }
        
        func switchToRearCamera() throws {
            
            guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput),
                let rearCamera = self.rearCamera else { throw CameraError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
                
                self.cameraPosition = .back
                captureSession.outputs.first?.connections.first?.videoOrientation = self.orientation
                captureSession.outputs.first?.connections.first?.isVideoMirrored = false
                if captureSession.outputs.first?.connections.first?.isVideoStabilizationSupported == true{
                    captureSession.outputs.first?.connections.first?.preferredVideoStabilizationMode = .auto
                }
            }
                
            else { throw CameraError.invalidOperation }
        }
        
        switch cameraPosition {
        case .front:
            try switchToRearCamera()
        case .back:
            try switchToFrontCamera()
        default:
            break
        }
        
        captureSession.commitConfiguration()
    }
    
    public func setFocusPoint(point: CGPoint) throws {
        
        guard let device = cameraPosition == .back ? self.rearCamera : self.frontCamera else { return }
        try device.lockForConfiguration()
        defer {
            device.unlockForConfiguration()
        }
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
        }
        
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = point
            device.exposureMode = .continuousAutoExposure
        }
    }
    
    public func currentPosition() -> AVCaptureDevice.Position {
        return cameraPosition
    }
    
    public func changeZoom(scale: CGFloat) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
        
        func setZoomFactor(device: AVCaptureDevice) {
            
            func minMaxZoom(_ factor: CGFloat) -> CGFloat {
                return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
            }
            
            let newScaleFactor = minMaxZoom(scale * lastZoomFactor)
            
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = newScaleFactor
            } catch {
                print(error)
            }
            
            lastZoomFactor = minMaxZoom(newScaleFactor)
        }
        
        switch cameraPosition {
        case .front:
            if let device = self.frontCamera {
                setZoomFactor(device: device)
            }
        case .back:
            if let device = self.rearCamera {
                setZoomFactor(device: device)
            }
        default:
            break
        }
    }
    
    public func changeBrightness(value: CGFloat) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
        
        func setBrightnessValue(device: AVCaptureDevice) {
            var newBias: Float = 0
            let minBias = device.minExposureTargetBias
            let maxBias = device.maxExposureTargetBias
            let range = maxBias - minBias
            let el = range / 100
            
            newBias = minBias + el * (Float(value) * 100)
            
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(newBias, completionHandler: nil)
            }catch {
                print(error)
            }
        }
        
        switch cameraPosition {
        case .front:
            if let device = self.frontCamera {
                setBrightnessValue(device: device)
            }
        case .back:
            if let device = self.rearCamera {
                setBrightnessValue(device: device)
            }
        default:
            break
        }
        
    }
}


/// MARK: - Private Methods
extension Camera {
    
    @discardableResult
    private func initializeTextureCache() -> Bool {
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MetalDevice.sharedDevice, nil, &textureCache)
        return result == kCVReturnSuccess
    }
    
    private func createCaptureSession() {
            self.captureSession = AVCaptureSession()
            self.captureSession?.sessionPreset = self.sessionPreset
            self.captureSession?.beginConfiguration()
    }
        
        
    private func configureCaptureDevices() throws {
        let cameraSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        
        let cameras = cameraSession.devices.compactMap { $0 }
        guard !cameras.isEmpty else { throw CameraError.noCamerasAvailable }
        
        for camera in cameras {
            if camera.position == .front {
                self.frontCamera = camera
            }
            
            if camera.position == .back {
                self.rearCamera = camera
                
                try camera.lockForConfiguration()
                camera.focusMode = .continuousAutoFocus
                camera.unlockForConfiguration()
            }
        }
        
        let audioSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified)
        
        self.audioDevice = audioSession.devices.compactMap { $0 }.first
        
    }

    private func configureDeviceInputs() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        
        
        if self.cameraPosition == .back, let rearCamera = self.rearCamera {
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
            else { throw CameraError.inputsAreInvalid }
        } else if self.cameraPosition == .front, let frontCamera = self.frontCamera {
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
            else { throw CameraError.inputsAreInvalid }
        } else {
            throw CameraError.noCamerasAvailable
        }
        
        if let audioDevice = self.audioDevice {
            self.audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if captureSession.canAddInput(self.audioDeviceInput!) {
                captureSession.addInput(self.audioDeviceInput!)
            }
        }
    }


    private func configureFrameOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        
        // capture frame
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput?.videoSettings = [ kCVPixelBufferMetalCompatibilityKey as String: true,
                                           kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput?.alwaysDiscardsLateVideoFrames = true
        videoDataOutput?.setSampleBufferDelegate(self, queue: cameraProcessingQueue)
        guard captureSession.canAddOutput(videoDataOutput!) else { return }
        captureSession.addOutput(videoDataOutput!)
        guard let connection = videoDataOutput?.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = self.orientation
        connection.isVideoMirrored = cameraPosition == .front
//        guard connection.isVideoStabilizationSupported else{ return }
//        connection.preferredVideoStabilizationMode = .auto
    }
    
    private func configureAudioOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        
        // capture audio
        audioOutput = AVCaptureAudioDataOutput()
        audioOutput?.setSampleBufferDelegate(self, queue: audioProcessingQueue)
        audioOutput?.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
        guard captureSession.canAddOutput(audioOutput!) else { return }
        captureSession.addOutput(audioOutput!)
        
    }
    
    private func configurePhotoOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput!) else { return }
        captureSession.addOutput(photoOutput!)
        photoOutput?.connection(with: .video)?.videoOrientation = .portrait
    }
}

extension Camera: ImageSource {
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
    
    public func add(chain: ImageRelay) {
        for (idx, consumer) in consumers.enumerated() {
            chain.add(consumer: consumer, at: idx)
        }
        removeAllConsumers()
        add(consumer: chain, at: 0)
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

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoDataOutput {
			lock.wait()
			guard let texture = texture(with: sampleBuffer) else { return }
            cameraFrameProcessingQueue.async { [weak self] in
                guard let self = self else { return }
                for consumer in self.consumers { consumer.newTextureAvailable(texture, from: self) }
            }
			lock.signal()
            
        } else if output == audioOutput {
            self.processAudioSampleBuffer(sampleBuffer)
        }
    }
	
	public func texture(with sampleBuffer: CMSampleBuffer) -> Texture? {
		guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) ,
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
    
    public func processAudioSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        self.audioEncodingTarget?.processAudioBuffer(sampleBuffer)
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    /// willCapturePhotoFor가 호출된 이후 시스템에서 셔터 소리를 재생하려한다
    public func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // turn off the shutter sound
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if error != nil { return }
		stopCapture()
		defer {
			startCapture()
		}
        if let sampleBuffer = photoSampleBuffer {
			guard let texture = texture(with: sampleBuffer) else { return }
            let source = StaticImageSource(texture: texture.metalTexture)
            var filters: [BaseFilter] = [RotateFilter(angle: 90, fitSize: true)]
            source.add(consumer: filters.first!)

            if self.currentPosition() == .front{
                let flip = FlipFilter(horizontal: true, vertical: false)
                filters.last?.add(consumer: flip)
                filters.append(flip)
            }

			source.transmitTexture()

            if let output = filters.last?.outputTexture {
                let outputTexture = Texture(mtlTexture: output, type: .photo)
                cameraPhotoProcessingQueue.async { [weak self] in
                    guard let self = self else { return }
                    for consumer in self.consumers {
                        consumer.newTextureAvailable(outputTexture, from: self)
                    }
                }
			}
        }
    }
}

public extension Camera {
    enum CameraError: Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
}
