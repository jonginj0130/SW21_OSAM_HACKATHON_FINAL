import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/request/request.dart';
import 'package:mypt/googleTTS/voice.dart';
import '../utils/function_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:mypt/models/workout_analysis.dart';
import 'package:mypt/models/workout_result.dart';
import 'dart:convert';

const Map<String, List<int>> jointIndx = {
  'right_elbow': [16, 14, 12],
  'right_hip': [12, 24, 26],
  'right_knee': [24, 26, 28]
};

class PushUpAnalysis implements WorkoutAnalysis {
  final Voice speaker = Voice();
  String _state = 'up'; // up, down, none

  Map<String, List<double>> _tempAngleDict = {
    'right_elbow': <double>[],
    'right_hip': <double>[],
    'right_knee': <double>[]
  };

  Map<String, List<int>> _feedBack = {
    'not_elbow_up': <int>[],
    'not_elbow_down': <int>[],
    'is_hip_up': <int>[],
    'is_hip_down': <int>[],
    'is_knee_down': <int>[],
    'is_speed_fast': <int>[]
  };

  int _count = 0;
  bool _detecting = false;
  bool _end = false;
  int targetCount;

  get count => _count;
  get feedBack => _feedBack;
  get tempAngleDict => _tempAngleDict;
  get detecting => _detecting;
  get end => _end;
  get state => _state;

  PushUpAnalysis({required this.targetCount});

  late int start;
  final List<String> _keys = jointIndx.keys.toList();
  final List<List<int>> _vals = jointIndx.values.toList();

  bool isStart = false;

  void detect(Pose pose) {
    // 포즈 추정한 관절값을 바탕으로 개수를 세고, 자세를 평가
    Map<PoseLandmarkType, PoseLandmark> landmarks = pose.landmarks;
    //포즈 추정한 관절값들을 가져오는 메서드
    try {
      for (int i = 0; i < jointIndx.length; i++) {
        List<List<double>> listXyz = findXyz(_vals[i], landmarks);
        double angle = calculateAngle2D(listXyz, direction: 1);

        _tempAngleDict[_keys[i]]!.add(angle);
      }
      double elbowAngle = _tempAngleDict['right_elbow']!.last;
      bool isElbowUp = (elbowAngle > 130);
      bool isElbowDown = (elbowAngle < 110);

      double hipAngle = _tempAngleDict['right_hip']!.last;
      bool hipCondition = (hipAngle > 140) && (hipAngle < 220);

      double kneeAngle = _tempAngleDict['right_knee']!.last;
      bool kneeCondition = kneeAngle > 130 && kneeAngle < 205;
      bool lowerBodyConditon = hipCondition && kneeCondition;
      if (!isStart && _detecting) {
        bool isPushUpAngle = elbowAngle > 140 &&
            elbowAngle < 190 &&
            hipAngle > 140 &&
            hipAngle < 190 &&
            kneeAngle > 125 &&
            kneeAngle < 180;
        if (isPushUpAngle) {
          speaker.sayStart();
          isStart = true;
        }
      }
      if (!isStart) {
        _tempAngleDict['right_elbow']!.removeLast();
        _tempAngleDict['right_hip']!.removeLast();
        _tempAngleDict['right_knee']!.removeLast();
      } else {
        if (isOutlierPushUps(_tempAngleDict['right_elbow']!, 0) ||
            isOutlierPushUps(_tempAngleDict['right_hip']!, 1) ||
            isOutlierPushUps(_tempAngleDict['right_knee']!, 2)) {
          _tempAngleDict['right_elbow']!.removeLast();
          _tempAngleDict['right_hip']!.removeLast();
          _tempAngleDict['right_knee']!.removeLast();
        } else {
          if (isElbowUp && (_state == 'down') && lowerBodyConditon) {
            int end = DateTime.now().second;
            _state = 'up';
            _count += 1;
            speaker.countingVoice(_count);
            //speaker.stopState();

            if (listMax(_tempAngleDict['right_elbow']!) > 160) {
              //팔꿈치를 완전히 핀 경우
              _feedBack['not_elbow_up']!.add(0);
            } else {
              //팔꿈치를 덜 핀 경우
              _feedBack['not_elbow_up']!.add(1);
            }

            if (listMin(_tempAngleDict['right_elbow']!) < 80) {
              //팔꿈치를 완전히 굽힌 경우
              _feedBack['not_elbow_down']!.add(0);
            } else {
              //팔꿈치를 덜 굽힌 경우
              _feedBack['not_elbow_down']!.add(1);
            }

            //푸쉬업 하나당 골반 판단
            if (listMin(_tempAngleDict['right_hip']!) < 160) {
              //골반이 내려간 경우
              _feedBack['is_hip_up']!.add(0);
              _feedBack['is_hip_down']!.add(1);
            } else if (listMax(_tempAngleDict['right_hip']!) > 250) {
              //골반이 올라간 경우
              _feedBack['is_hip_up']!.add(1);
              _feedBack['is_hip_down']!.add(0);
            } else {
              //정상
              _feedBack['is_hip_up']!.add(0);
              _feedBack['is_hip_down']!.add(0);
            }

            //knee conditon
            if (listMin(_tempAngleDict['right_knee']!) < 130) {
              //무릎이 내려간 경우
              _feedBack['is_knee_down']!.add(1);
            } else {
              //무릎이 정상인 경우
              _feedBack['is_knee_down']!.add(0);
            }

            //speed
            if ((end - start) < 1) {
              //속도가 빠른 경우
              _feedBack['is_speed_fast']!.add(1);
            } else {
              //속도가 적당한 경우
              _feedBack['is_speed_fast']!.add(0);
            }

            if (_feedBack['is_hip_down']!.last == 1) {
              //골반이 내려간 경우
              speaker.sayHipUp(_count);
            } else if (_feedBack['is_hip_up']!.last == 1) {
              //골반이 올라간 경우
              speaker.sayHipDown(_count);
            } else {
              if (_feedBack['is_knee_down']!.last == 1) {
                //무릎이 내려간 경우
                speaker.sayKneeUp(_count);
              } else {
                //무릎이 정상인 경우
                if (_feedBack['not_elbow_up']!.last == 0) {
                  // 팔꿈치를 완전히 핀 경우
                  if (_feedBack['not_elbow_down']!.last == 0) {
                    // 팔꿈치를 완전히 굽힌 경우
                    if (feedBack['is_speed_fast']!.last == 0) {
                      //속도가 적당한 경우
                      speaker.sayGood1(_count);
                    } else {
                      //속도가 빠른 경우
                      speaker.sayFast(_count);
                    }
                  } else {
                    //팔꿈치를 덜 굽힌 경우
                    speaker.sayBendElbow(_count);
                  }
                } else {
                  // 팔꿈치를 덜 핀 경우
                  speaker.sayStretchElbow(_count);
                }
              }
            }

            //초기화
            _tempAngleDict['right_elbow'] = <double>[];
            _tempAngleDict['right_hip'] = <double>[];
            _tempAngleDict['right_knee'] = <double>[];

            if (_count == targetCount) {
              stopAnalysingDelayed();
            }
          } else if (isElbowDown && _state == 'up' && lowerBodyConditon) {
            _state = 'down';
            start = DateTime.now().second;
          }
        }
      }
    } catch (e) {
      print("detect function에서 에러가 발생 : $e");
    }
  }

  List<int> workoutToScore() {
    List<int> score = [];
    int n = _count;
    for (int i = 0; i < n; i++) {
      //_e는 pushups에 담겨있는 각각의 element

      int isElbowUp = 1 - _feedBack['not_elbow_up']![i];
      int isElbowDown = 1 - _feedBack['not_elbow_down']![i];
      int isHipGood =
          (_feedBack['is_hip_up']![i] == 0 && _feedBack['is_hip_down']![i] == 0)
              ? 1
              : 0;
      int isKneeGood = 1 - _feedBack['is_knee_down']![i];
      int isSpeedGood = 1 - _feedBack['is_speed_fast']![i];
      score.add(isElbowUp * 25 +
          isElbowDown * 30 +
          isHipGood * 30 +
          isKneeGood * 8 +
          isSpeedGood * 7);
    }
    return score;
  }

  @override
  void startDetecting() {
    _detecting = true;
  }

  Future<void> startDetectingDelayed() async {
    speaker.sayStartDelayed();
    await Future.delayed(const Duration(seconds: 8), () {
      startDetecting();
    });
  }

  void stopDetecting() {
    _detecting = false;
  }

  void stopAnalysing() {
    _end = true;
  }

  Future<void> stopAnalysingDelayed() async {
    stopAnalysing();
    await Future.delayed(const Duration(seconds: 1), () {
      speaker.sayEnd();
    });
  }

  WorkoutResult makeWorkoutResult() {
    CollectionReference user_file =
        FirebaseFirestore.instance.collection('user_file');
    var currentUser = FirebaseAuth.instance.currentUser;
    String userUid = currentUser!.uid;

    List<int> feedbackCounts = <int>[]; // sum of feedback which value is 1
    for (String key in _feedBack.keys.toList()) {
      int tmp = 0;
      for (int i = 0; i < _count; i++) {
        tmp += _feedBack[key]![i];
      }
      feedbackCounts.add(tmp);
    }
    WorkoutResult workoutResult = WorkoutResult(
        user: '00', // firebase로 구현
        uid: userUid, // firebase로 구현
        workoutName: 'push_up',
        count: _count,
        score: workoutToScore(),
        feedbackCounts: feedbackCounts);
    return workoutResult;
  }

  void saveWorkoutResult() async {
    WorkoutResult workoutResult = makeWorkoutResult();
    String json = jsonEncode(workoutResult);
    print(json);

    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    CollectionReference exerciseDB =
        FirebaseFirestore.instance.collection('exercise_DB');

    Future<void> exercisestart() {
      // Call the user's CollectionReference to add a new user
      print("streamstart");
      return exerciseDB
          .doc()
          .set(workoutResult.toJson())
          .then((value) => print("json added"))
          .catchError((error) => print("Failed to add json: $error"));
    }

    WidgetsFlutterBinding.ensureInitialized();
    Firebase.initializeApp();

    var currentUser = FirebaseAuth.instance.currentUser;
    String uid_name = currentUser!.uid;
    int new_pushup = workoutResult.toJson()['score'];
    print(uid_name);

    CollectionReference leaderboard =
        FirebaseFirestore.instance.collection('leaderboard_DB');

    var docSnapshot = await leaderboard.doc(uid_name).get();
    Map<String, dynamic>? data = docSnapshot.data() as Map<String, dynamic>?;
    int old_pushup = data!['push_up'];
    int old_score = data['score'];

    if (new_pushup > old_pushup) {
      int new_score = new_pushup - old_pushup + old_score;
      leaderboard
          .doc(uid_name)
          .update({'push_up': new_pushup, 'score': new_score});
    }

    exercisestart();

    print("streamend");
    // CollectionReference users = FirebaseFirestore.instance.collection('users');
    // firebase로 workoutResult 서버로 보내기 구현

    // JsonStore jsonStore = JsonStore();
    // // store json
    // await jsonStore.setItem(
    //   'workout_result_${workoutResult.id}',
    //   workoutResult.toJson()
    // );
    // // increment analysis counter value
    // Map<String, dynamic>? jsonCounter = await jsonStore.getItem('analysis_counter');
    // AnalysisCounter analysisCounter = jsonCounter != null ? AnalysisCounter.fromJson(jsonCounter) : AnalysisCounter(value: 0);
    // analysisCounter.value++;
    // await jsonStore.setItem(
    //   'analysis_counter',
    //   analysisCounter.toJson()
    // );
  }
}
