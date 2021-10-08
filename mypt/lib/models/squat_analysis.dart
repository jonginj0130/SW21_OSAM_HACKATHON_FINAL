import '../utils.dart';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:mypt/models/workout_analysis.dart';

const Map<String, List<int>> jointIndx = {
  'right_hip': [12, 24, 26],
  'right_knee': [24, 26, 28]
};

class SquatAnalysis implements WorkoutAnalysis {
  Map<String, List<double>> _tempAngleDict = {
    'right_hip': <double>[],
    'right_knee': <double>[],
    'avg_hip_knee': <double>[],
  };

  Map<String, List<int>> _feedBack = {
    'is_relaxation': <int>[],
    'is_contraction': <int>[],
    'hip_knee_relation': <int>[],
    'is_knee_in': <int>[],
    'is_speed_good': <int>[]
  };

  bool isKneeOut = false;
  late double footLength;
  late double kneeX;
  late double toeX;

  late int start;
  List<String> _keys = jointIndx.keys.toList();
  List<List<int>> _vals = jointIndx.values.toList();
  String _state = 'up'; // up, down, none
  int _count = 0;
  int get count => _count;

  void detect(Pose pose) {
    // 포즈 추정한 관절값을 바탕으로 개수를 세고, 자세를 평가
    Map<PoseLandmarkType, PoseLandmark> landmarks = pose.landmarks;
    for (int i = 0; i < jointIndx.length; i++) {
      List<List<double>> listXyz = findXyz(_vals[i], landmarks);
      double angle = calculateAngle3DRight(listXyz);
      _tempAngleDict[_keys[i]]!.add(angle);
    }
    kneeX = landmarks[PoseLandmarkType.values[26]]!.x;
    toeX = landmarks[PoseLandmarkType.values[32]]!.x;
    footLength = getDistance(landmarks[PoseLandmarkType.values[32]]!,
        landmarks[PoseLandmarkType.values[30]]!);
    if ((toeX + footLength * 0.195) < kneeX) {
      isKneeOut = true;
    }
    double hipAngle = _tempAngleDict['right_hip']!.last;
    double kneeAngle = _tempAngleDict['right_knee']!.last;
    _tempAngleDict['avg_hip_knee']!.add((hipAngle + kneeAngle) / 2);

    bool isHipUp = hipAngle < 235;
    bool isHipDown = hipAngle > 245;
    bool isKneeUp = kneeAngle > 130;

    if (isHipUp && isKneeUp && (_state == 'down')) {
      int end = DateTime.now().second;
      _state = 'up';
      if (listMin(_tempAngleDict['right_hip']!) < 195) {
        _feedBack['is_relaxation']!.add(1);
      } else {
        _feedBack['is_relaxation']!.add(0);
      }
      if (listMax(_tempAngleDict['right_hip']!) > 270) {
        _feedBack['is_contraction']!.add(1);
      } else {
        _feedBack['is_contraction']!.add(0);
      }
      if (listMax(_tempAngleDict['avg_hip_knee']!) > 193) {
        _feedBack['hip_knee_relation']!.add(1);
      } else if (listMin(_tempAngleDict['avg_hip_knee']!) < 176) {
        _feedBack['hip_knee_relation']!.add(2);
      } else {
        _feedBack['hip_knee_relation']!.add(0);
      }
      if (isKneeOut) {
        _feedBack['is_knee_in']!.add(0);
      } else {
        _feedBack['is_knee_in']!.add(1);
      }
      if ((end - start) < 1) {
        _feedBack['is_speed_good']!.add(0);
      } else {
        _feedBack['is_speed_good']!.add(1);
      }
      _tempAngleDict['right_hip'] = <double>[];
      _tempAngleDict['right_knee'] = <double>[];
      _tempAngleDict['avg_hip_knee'] = <double>[];
      //개수 카운팅 부분
      ++_count;
      isKneeOut = false;
    } else if (isHipDown && !isKneeUp && _state == 'up') {
      _state = 'down';
      start = DateTime.now().second;
    }
  }

  List<int> workoutToScore() {
    List<int> score = [];
    int n = _feedBack.values.length;
    for (int i = 0; i < n; i++) {
      //_e는 pushups에 담겨있는 각각의 element
      int isRelaxation = _feedBack['is_relaxation']![i];
      int isContraction = _feedBack['is_contraction']![i];
      int isHipKneeGood = (_feedBack['hip_knee_relation']![i] == 0) ? 1 : 0;
      int isKneeIn = _feedBack['is_knee_in']![i];
      int isSpeedgood = _feedBack['is_speed_good']![i];
      score.add(isRelaxation * 10 +
          isContraction * 20 +
          isHipKneeGood * 50 +
          isKneeIn * 13 +
          isSpeedgood * 7);
    }
    return score;
  }
}