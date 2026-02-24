import 'package:yandex_mobileads/mobile_ads.dart';
import '../constants/app_constants.dart';

/// Сервис для управления рекламой Яндекс РСЯ
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  BannerAd? _bannerAd;
  bool _isInitialized = false;
  bool _isBannerLoaded = false;

  /// Инициализация SDK Яндекс РСЯ
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await MobileAds.initialize();
      _isInitialized = true;
      AppConstants.debugLog('✅ Яндекс РСЯ SDK инициализирован');
    } catch (e) {
      AppConstants.debugLog('⚠️ Ошибка инициализации Яндекс РСЯ: $e');
    }
  }

  /// Создать баннер
  /// [adUnitId] - ID рекламного блока из Яндекс РСЯ
  /// [onAdLoaded] - callback при успешной загрузке
  /// [onAdFailedToLoad] - callback при ошибке загрузки
  BannerAd createBanner({
    required String adUnitId,
    BannerAdSize? adSize,
    void Function()? onAdLoaded,
    void Function(String error)? onAdFailedToLoad,
  }) {
    if (!_isInitialized) {
      AppConstants.debugLog('⚠️ AdService не инициализирован. Вызовите init() первым.');
    }

    final size = adSize ?? const BannerAdSize.sticky(width: 320);
    AppConstants.debugLog('📢 Создаем баннер. adUnitId=$adUnitId, size=${size.width}x${size.height}');

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      adSize: size,
      adRequest: const AdRequest(),
      onAdLoaded: () {
        _isBannerLoaded = true;
        AppConstants.debugLog('✅ Баннер загружен');
        onAdLoaded?.call();
      },
      onAdFailedToLoad: (error) {
        _isBannerLoaded = false;
        AppConstants.debugLog('⚠️ Ошибка загрузки баннера: ${error.description}');
        onAdFailedToLoad?.call(error.description);
      },
    );

    return _bannerAd!;
  }

  /// Загрузить баннер
  Future<void> loadBanner() async {
    if (_bannerAd == null) {
      AppConstants.debugLog('⚠️ Баннер не создан. Вызовите createBanner() первым.');
      return;
    }

    try {
      _bannerAd!.loadAd(adRequest: const AdRequest());
    } catch (e) {
      AppConstants.debugLog('⚠️ Ошибка загрузки баннера: $e');
    }
  }

  /// Проверка, загружен ли баннер
  bool get isBannerLoaded => _isBannerLoaded;

  /// Уничтожить баннер (освободить ресурсы)
  void disposeBanner() {
    _bannerAd?.destroy();
    _bannerAd = null;
    _isBannerLoaded = false;
    AppConstants.debugLog('🗑️ Баннер уничтожен');
  }

  /// Получить текущий баннер
  BannerAd? get bannerAd => _bannerAd;
}
