#!/usr/bin/env python3
"""
Генератор иконок приложения для Android из изображения 512x512
"""

from PIL import Image
import os

# Размеры иконок для разных плотностей пикселей
SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

# Пути
ICON_SOURCE = 'assets/vodichki_icon_512.png'
BASE_PATH = 'android/app/src/main/res'

def main():
    # Проверка источника
    if not os.path.exists(ICON_SOURCE):
        print(f"❌ Файл {ICON_SOURCE} не найден!")
        return False
    
    # Открываем исходное изображение
    try:
        img = Image.open(ICON_SOURCE)
        print(f"✅ Загружено изображение: {img.size}")
    except Exception as e:
        print(f"❌ Ошибка при загрузке: {e}")
        return False
    
    # Генерируем размеры
    for folder, size in SIZES.items():
        try:
            # Создаем папку если её нет
            folder_path = os.path.join(BASE_PATH, folder)
            os.makedirs(folder_path, exist_ok=True)
            
            # Масштабируем изображение
            resized = img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Сохраняем
            output_path = os.path.join(folder_path, 'ic_launcher.png')
            resized.save(output_path, 'PNG')
            
            print(f"✅ {folder}: {size}x{size} → {output_path}")
        except Exception as e:
            print(f"❌ Ошибка при создании {folder}: {e}")
            return False
    
    print("\n✅ Все иконки созданы успешно!")
    return True

if __name__ == '__main__':
    main()
