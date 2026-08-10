import 'dart:io';

import 'package:flutter/foundation.dart';

/// 플랫폼 판별. 지도 SDK와 소셜 로그인이 플랫폼마다 분기해야 해서 쓴다.
enum AppPlatform { web, android, ios, other }

AppPlatform currentPlatform() {
  if (kIsWeb) return AppPlatform.web;
  if (Platform.isAndroid) return AppPlatform.android;
  if (Platform.isIOS) return AppPlatform.ios;
  return AppPlatform.other;
}

// ─────────────────────────────────────────────────────────────
// 화면 비율 보정
//
// 디자이너는 390 × 779 크기의 시안 위에서 작업했다.
// 여기서 779는 상태바와 내비게이션 바를 뺀 "실제로 그릴 수 있는" 세로 길이다.
//
// 문제는 기기마다 이 값이 다르다는 것이다.
// 같은 400px 카드가 어떤 기기에서는 화면의 절반을, 어떤 기기에서는 3분의 2를 차지한다.
// 그래서 시안의 px를 그대로 쓰지 않고, 현재 기기의 실사용 영역 비율로 환산해서 쓴다.
// ─────────────────────────────────────────────────────────────

/// 시안 기준 크기. 이 값이 바뀌면 앱 전체의 레이아웃이 함께 움직인다.
const double design_width = 390;
const double design_height = 779;

/// 앱 시작 시 MediaQuery에서 한 번 채워 넣는다.
/// 상태바·내비게이션 바를 제외한 실사용 영역 크기다.
double available_screen_width = 0.0;
double available_screen_height = 0.0;

/// 시안의 세로 px를 현재 기기 비율로 환산한다.
double reHeight(double px) => available_screen_height * px / design_height;

/// 시안의 가로 px를 현재 기기 비율로 환산한다.
double reWidth(double px) => available_screen_width * px / design_width;

/// 글자 크기는 일부러 환산하지 않고 시안 값을 그대로 쓴다.
///
/// 작은 기기에서 본문까지 같이 줄이면 가독성이 먼저 무너졌다.
/// 레이아웃은 비율로 늘리고 글자는 고정하는 편이 실제 기기에서 더 나았다.
///
/// 다만 이 선택 때문에 OS의 글꼴 크기 설정을 따라가지 못한다.
/// 접근성 측면에서는 분명한 약점이고, 다시 만든다면 여기부터 손볼 것이다.
double reText(double sp) => sp;
