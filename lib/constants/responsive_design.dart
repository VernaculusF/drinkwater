import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Класс для адаптивного дизайна под разные диагонали экранов
class ResponsiveDesign {
  late BuildContext context;
  late MediaQueryData mediaQuery;
  late double screenWidth;
  late double screenHeight;
  late double devicePixelRatio;
  
  /// Категория устройства
  late DeviceType deviceType;
  
  ResponsiveDesign(BuildContext ctx) {
    context = ctx;
    mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    devicePixelRatio = mediaQuery.devicePixelRatio;
    deviceType = _getDeviceType();
  }
  
  /// Определение типа устройства по диагонали
  DeviceType _getDeviceType() {
    // Диагональ в дюймах
    final diagonal = (screenWidth * screenWidth + screenHeight * screenHeight) /
        math.sqrt(screenWidth * screenWidth + screenHeight * screenHeight);
    
    if (screenWidth < 500) {
      return DeviceType.phone;
    } else if (screenWidth < 900) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// Размер кнопки "ВЫПИЛ" в зависимости от экрана
  double get buttonSize {
    switch (deviceType) {
      case DeviceType.phone:
        // На телефонах: 35-45% ширины экрана, но не менее 140 и не более 250
        final size = screenWidth * 0.4;
        return size.clamp(140, 250);
      case DeviceType.tablet:
        return screenWidth * 0.35;
      case DeviceType.desktop:
        return 300;
    }
  }
  
  /// Размер шрифта для главного счётчика
  double get counterFontSize {
    switch (deviceType) {
      case DeviceType.phone:
        return screenWidth < 350 ? 48 : 64;
      case DeviceType.tablet:
        return 80;
      case DeviceType.desktop:
        return 96;
    }
  }
  
  /// Размер шрифта для кнопки "ВЫПИЛ"
  double get buttonFontSize {
    switch (deviceType) {
      case DeviceType.phone:
        return screenWidth < 350 ? 18 : 28;
      case DeviceType.tablet:
        return 36;
      case DeviceType.desktop:
        return 40;
    }
  }
  
  /// Размер шрифта для обычного текста
  double get bodyFontSize {
    switch (deviceType) {
      case DeviceType.phone:
        return 14;
      case DeviceType.tablet:
        return 16;
      case DeviceType.desktop:
        return 18;
    }
  }
  
  /// Размер шрифта для заголовков
  double get headingFontSize {
    switch (deviceType) {
      case DeviceType.phone:
        return 20;
      case DeviceType.tablet:
        return 28;
      case DeviceType.desktop:
        return 32;
    }
  }
  
  /// Padding для основного контента
  double get mainPadding {
    switch (deviceType) {
      case DeviceType.phone:
        return 16;
      case DeviceType.tablet:
        return 24;
      case DeviceType.desktop:
        return 32;
    }
  }
  
  /// Padding для горизонтального направления
  double get horizontalPadding {
    switch (deviceType) {
      case DeviceType.phone:
        return screenWidth < 350 ? 12 : 20;
      case DeviceType.tablet:
        return 32;
      case DeviceType.desktop:
        return 48;
    }
  }
  
  /// Высота прогресс-бара
  double get progressBarHeight {
    switch (deviceType) {
      case DeviceType.phone:
        return 20;
      case DeviceType.tablet:
        return 28;
      case DeviceType.desktop:
        return 32;
    }
  }
  
  /// Интервал между элементами
  double get spacing {
    switch (deviceType) {
      case DeviceType.phone:
        return 12;
      case DeviceType.tablet:
        return 16;
      case DeviceType.desktop:
        return 20;
    }
  }
  
  /// Является ли это мобильным устройством (< 600dp)
  bool get isMobile => screenWidth < 600;
  
  /// Является ли это планшетом
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  
  /// Является ли это ландшафтной ориентацией
  bool get isLandscape => mediaQuery.orientation == Orientation.landscape;
  
  /// Является ли это портретной ориентацией
  bool get isPortrait => mediaQuery.orientation == Orientation.portrait;
}

enum DeviceType {
  phone,
  tablet,
  desktop,
}
