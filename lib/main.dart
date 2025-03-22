import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraScreen(cameras: cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: true,
    ),
  );
  final poseDetector = PoseDetector(options: PoseDetectorOptions());
  String result = "Aim and Shoot!";
  int score = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.cameras[0], ResolutionPreset.medium);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void captureAndDetect() async {
    setState(() {
      _isProcessing = true;
    });

    XFile imageFile = await _controller.takePicture();
    detectHit(imageFile.path);

    // Set a timeout duration (e.g., 5 seconds)
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isProcessing = false;
    });
  }

  void detectHit(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Face> faces = await faceDetector.processImage(inputImage);
    final List<Pose> poses = await poseDetector.processImage(inputImage);

    final double crosshairX = MediaQuery.of(context).size.width / 2;
    final double crosshairY = MediaQuery.of(context).size.height / 2;
    final double threshold = 50.0; 

    bool hitHead = false;
    bool hitBody = false;

    for (var face in faces) {
      final faceCenterX = face.boundingBox.center.dx;
      final faceCenterY = face.boundingBox.center.dy;
      if ((faceCenterX - crosshairX).abs() < threshold && (faceCenterY - crosshairY).abs() < threshold) {
        hitHead = true;
        break;
      }
    }

    for (var pose in poses) {
      PoseLandmark? leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      PoseLandmark? rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      PoseLandmark? chest = pose.landmarks[PoseLandmarkType.leftShoulder] != null && pose.landmarks[PoseLandmarkType.rightShoulder] != null
          ? PoseLandmark(
          x: (pose.landmarks[PoseLandmarkType.leftShoulder]!.x + pose.landmarks[PoseLandmarkType.rightShoulder]!.x) / 2,
          y: (pose.landmarks[PoseLandmarkType.leftShoulder]!.y + pose.landmarks[PoseLandmarkType.rightShoulder]!.y) / 2,
          z: (pose.landmarks[PoseLandmarkType.leftShoulder]!.z + pose.landmarks[PoseLandmarkType.rightShoulder]!.z) / 2,
          type: PoseLandmarkType.leftShoulder, likelihood: 1.0,
        )
          : null;
      PoseLandmark? leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      PoseLandmark? rightHip = pose.landmarks[PoseLandmarkType.rightHip];
      PoseLandmark? leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
      PoseLandmark? rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

      List<PoseLandmark?> bodyLandmarks = [leftShoulder, rightShoulder, chest, leftHip, rightHip, leftKnee, rightKnee];
      
      for (var landmark in bodyLandmarks) {
        if (landmark != null) {
          final bodyX = landmark.x;
          final bodyY = landmark.y;
          if ((bodyX - crosshairX).abs() < threshold && (bodyY - crosshairY).abs() < threshold) {
            hitBody = true;
            break;
          }
        }
      }
    }

    // Determine final result
    if (hitHead) {
      setState(() {
        result = "Headshot! +10 Points";
        score += 10;
      });
    } else if (hitBody) {
      setState(() {
        result = "Body Shot! +5 Points";
        score += 5;
      });
    } else {
      setState(() {
        result = "Missed! No Points";
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    faceDetector.close();
    poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Laser Game")),
      body: Stack(
        children: [
          Positioned.fill(
            child: _controller.value.isInitialized
                ? CameraPreview(_controller)
                : Center(child: CircularProgressIndicator()),
          ),
          Center(
            child: Icon(Icons.add_circle_outline, size: 50, color: Colors.red),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
                children: [
                Text(result, style: TextStyle(fontSize: 20, color: Colors.white)),
                Text("Score: $score", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.yellow)),
                ElevatedButton(
                  onPressed: _isProcessing ? null : captureAndDetect,
                  child: _isProcessing ? CircularProgressIndicator() : Text("Shoot!"),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
    );
  }
}
