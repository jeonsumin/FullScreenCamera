//
//  ViewController.swift
//  FullScreenCamera
//
//  Created by joonwon lee on 28/04/2019.
//  Copyright © 2019 com.joonwon. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController {
    // TODO: 초기 설정 (카메라를 생성할때 필요한 초기 설정 세팅)
    // - captureSession
    // - AVCaptureDeviceInput
    // - AVCapturePhotoOutput
    // - Queue > 비디오 관련 프로세싱은 Queue 에서 일어날 수 있게 커스텀 Queue
    // - AVCaptureDevice DiscoverySession > 카메라를 찾을 때 조건
    let captureSession = AVCaptureSession()
    var videoDeviceInput: AVCaptureDeviceInput!
    let photoOutput = AVCapturePhotoOutput()
    let sessionQueue = DispatchQueue(label: "session Queue")
    let videoDeviceDescoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera
                                                                                     , .builtInWideAngleCamera
                                                                                     , .builtInTrueDepthCamera]
                                                                       , mediaType: .video
                                                                       , position: .unspecified)
    
    // UI Set
    @IBOutlet weak var photoLibraryButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var blurBGView: UIVisualEffectView!
    @IBOutlet weak var switchButton: UIButton!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: 초기 설정 구성하기
        previewView.session = captureSession
        sessionQueue.async {
            self.setupSession()
            self.startSession()
        }
        setupUI()
        
        
    }
    
    func setupUI() {
        photoLibraryButton.layer.cornerRadius = 10
        photoLibraryButton.layer.masksToBounds = true
        photoLibraryButton.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        photoLibraryButton.layer.borderWidth = 1
        
        captureButton.layer.masksToBounds = true
        captureButton.layer.cornerRadius = captureButton.bounds.height/2
        
        blurBGView.layer.masksToBounds = true
        blurBGView.layer.cornerRadius = blurBGView.bounds.height/2
        
    }
    
    //앞 뒤 카메라 토글 버튼
    @IBAction func switchCamera(sender: Any) {
        // TODO: 카메라는 1개 이상이어야함
        guard videoDeviceDescoverySession.devices.count > 1 else {
            return
        }
        // TODO: 반대 카메라 찾아서 재설정
        // - 1. 반대 카메라 찾기
        // - 2. 새로운 디바이를 가지고 세션 업데이트
        // - 3. 카메라 토글 버튼 업데이트
        
        // 카메라 찾기
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device //현재 잡혀진 비디오디바이스
            let currentPosition = currentVideoDevice.position //앞 카메라인지 뒤카메라인지
            let isFront = currentPosition == .front
            let preferredPosition: AVCaptureDevice.Position = isFront ? .back : .front // 앞카메라일 경우 뒤 카메라를 가져오고 뒤 카메라일경우 앞 카메라 가져온다.
            
            let devices = self.videoDeviceDescoverySession.devices
            var newVideoDevice: AVCaptureDevice?
            
            newVideoDevice = devices.first(where: { (device) -> Bool in
                return preferredPosition == device.position
            })
            
            //update capture session
            if let newDevice = newVideoDevice {
                do{
                let videoDeviceInput = try AVCaptureDeviceInput(device: newDevice)
                    
                    self.captureSession.beginConfiguration()
                    self.captureSession.removeInput(self.videoDeviceInput)
                    
                    // add new device input
                    if self.captureSession.canAddInput(videoDeviceInput){
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    }else{
                        self.captureSession.addInput(videoDeviceInput)
                    }
                    self.captureSession.commitConfiguration()
                    
                    DispatchQueue.main.async {
                        self.updateSwitchCameraIcon(position: preferredPosition)
                    }
                }catch let error{
                    print("switchCamera func error :: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    func updateSwitchCameraIcon(position: AVCaptureDevice.Position) {
        // TODO: Update ICON
        switch position {
        case .front:
            let image = #imageLiteral(resourceName: "ic_camera_front")
            switchButton.setImage(image, for: .normal)
        case .back:
            let image = #imageLiteral(resourceName: "ic_camera_rear")
            switchButton.setImage(image, for: .normal)
        default:
            break
        }
        
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        // TODO: photoOutput의 capturePhoto 메소드
        // orientation
        // photooutputsetting
        
        //캡쳐 세션에서 사진을 찍는걸 요청한다.
        let videoPreviewLayerOrientation = self.previewView.videoPreviewLayer.connection?.videoOrientation
        sessionQueue.async {
            let connection = self.photoOutput.connection(with: .video)
            connection?.videoOrientation = videoPreviewLayerOrientation!
            
            //사진 찍는 것을 요청
            let setting = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: setting, delegate: self)
        }
        
    }
    
    
    func savePhotoLibrary(image: UIImage) {
        // TODO: capture한 이미지 포토라이브러리에 저장
        
        // 사용자 권한 요청
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // 저장
                PHPhotoLibrary.shared().performChanges ({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { (success, error) in
                    print("이미지 저장 완료 \(success)")
                }

            }else{
                // 다시 요청
            print("권한을 아직 받지 못했습니다.")
            }
        }
    }
}


extension CameraViewController {
    // MARK: - Setup session and preview
    func setupSession() {
        // TODO: captureSession 구성하기
        // - presetSetting 하기 >> 미디어 캡쳐를 할때 사진을 찍을 수 있고 영상을 찍을 수 있으며 해상도도 정할수 있으니 presetSetting을 해줘야함
        // - beginConfiguration
        // - Add Video Input
        // - Add Photo Output
        // - commitConfiguration
        
        // begin 과 commit 안에서 구성이 진행 되어야한다.
        
        captureSession.sessionPreset = .photo
        captureSession.beginConfiguration() //구성 시작
        
        //Add Video Input
        //var defaultVideoDevice : AVCaptureDevice?
        
        guard let camera = videoDeviceDescoverySession.devices.first else {
            captureSession.commitConfiguration()
            return
            
        }
        do{
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoDeviceInput){
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            }else {
                captureSession.commitConfiguration()
                return
            }
            
        }catch let error{
            captureSession.commitConfiguration()
            print("error ::: \(error.localizedDescription)")
            return
        }
        
        //add photo output
        //photoOutput에 어떤 형식으로 표시해줄지
        photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
        if captureSession.canAddOutput(photoOutput){
            captureSession.addOutput(photoOutput)
        }else{
            captureSession.commitConfiguration()
            return
        }
        
        
        
        captureSession.commitConfiguration() //구성 완료
        
        
        
        
        
    }
    
    
    
    func startSession() {
        // TODO: session Start
        sessionQueue.async {
            //capturesession이 진행중이 아닐경우에만 시작한다.
            if !self.captureSession.isRunning{
                self.captureSession.startRunning()
            }
        }
        
    }
    
    func stopSession() {
        // TODO: session Stop
        sessionQueue.async {
            // 시작 중일 경우에 멈추라고 호출 
            if self.captureSession.isRunning {
                
                self.captureSession.stopRunning()
            }
        }
        
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // TODO: capturePhoto delegate method 구현
        guard error  == nil else { return }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else{ return }
        self.savePhotoLibrary(image: image)
        
    }
    
}
