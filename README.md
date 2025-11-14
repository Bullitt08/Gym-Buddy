# 🏋️ GymBuddy - Fitness Sosyal Medya Uygulaması

GymBuddy, fitness tutkunları için tasarlanmış bir sosyal medya uygulamasıdır. Arkadaşlarınla antrenman anlarını paylaş, birbirinizi motive edin ve fitness yolculuğunuzda birlikte ilerleyin!

## 🌟 Özellikler

### 📱 Ana Özellikler
- **Kullanıcı Kimlik Doğrulama**: Firebase Auth ile güvenli giriş/kayıt
- **Gönderi Paylaşımı**: Fotoğraf ve video paylaşımı
- **Arkadaşlık Sistemi**: Arkadaş ekle ve takip et
- **Streak Takibi**: Ardışık antrenman günlerini say
- **Harita Entegrasyonu**: Arkadaşların gönderi konumları ve yakındaki spor salonları
- **Müzik Entegrasyonu**: Deezer API ile müzik ekleme

### 🎨 Kullanıcı Arayüzü
- **5 Ana Sekme**:
  1. **Ana Sayfa**: Arkadaşların gönderileri
  2. **Harita**: Konum bazlı içerik
  3. **Gönderi Oluştur**: Kamera/galeri entegrasyonu
  4. **Arkadaş İstatistikleri**: Sosyal aktivite takibi
  5. **İstatistiklerim**: Kişisel performans

## 🛠️ Teknik Detaylar

### 📊 Kullanılan Teknolojiler
- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **Backend**: Firebase
- **Veritabanı**: Cloud Firestore
- **Kimlik Doğrulama**: Firebase Auth
- **Depolama**: Firebase Storage
- **Haritalar**: Google Maps API
- **Müzik**: Deezer API

## 🗄️ Veritabanı Yapısı (Firebase Firestore)

### Users Collection
```javascript
{
  id: "user_uid",
  email: "user@example.com",
  username: "kullanici_adi",
  profilePhoto: "url",
  bio: "Hakkımda",
  streak: 5,
  friends: ["friend_uid1", "friend_uid2"],
  createdAt: Timestamp
}
```

### Posts Collection
```javascript
{
  id: "post_id",
  userId: "user_uid",
  mediaUrl: "storage_url",
  mediaType: "photo" | "video",
  caption: "Gönderi açıklaması",
  taggedUsers: ["user_uid"],
  musicTrackId: "deezer_track_id",
  musicTrackName: "Şarkı adı",
  musicArtist: "Sanatçı",
  location: { lat: 41.0082, lng: 28.9784 },
  likes: 10,
  comments: 5,
  createdAt: Timestamp
}
```

### Chats Collection
```javascript
{
  id: "chat_id",
  participants: ["user_uid1", "user_uid2"],
  lastMessage: "Son mesaj",
  lastMessageTime: Timestamp,
  createdAt: Timestamp
}
```

## 🚀 Kurulum

### Gereksinimler
1. Flutter SDK (>= 3.4.4)
2. Dart SDK (>= 3.0.0)
3. Android Studio / VS Code
4. Firebase hesabı
5. Google Cloud Platform hesabı (Maps API için)

### Kurulum Adımları

1. **Projeyi klonlayın**:
```bash
git clone https://github.com/YOUR_USERNAME/GymBuddy.git
cd GymBuddy
```

2. **Bağımlılıkları yükleyin**:
```bash
flutter pub get
```

3. **API Anahtarlarını Ayarlayın**:
   
   a) **Dart API Anahtarları:**
   - `lib/config/api_keys.example.dart` dosyasını `api_keys.dart` olarak kopyalayın
   - Google Maps API anahtarınızı ekleyin
   - Firebase API anahtarlarını ekleyin
   
   b) **iOS API Anahtarları:**
   - `ios/Runner/AppDelegate.swift` dosyasını açın
   - `YOUR_GOOGLE_MAPS_API_KEY` kısmını kendi API anahtarınızla değiştirin
   
   c) **Android API Anahtarları:**
   - `android/app/src/main/AndroidManifest.xml` dosyasını açın
   - `YOUR_GOOGLE_MAPS_API_KEY` kısmını kendi API anahtarınızla değiştirin
   
   **Not:** Deezer API için herhangi bir anahtar gerekmez, ücretsizdir!

4. **Firebase Yapılandırması**:
   - Firebase Console'da yeni bir proje oluşturun
   - Android/iOS uygulamalarını ekleyin
   - `google-services.json` (Android) ve `GoogleService-Info.plist` (iOS) dosyalarını indirin
   - Firebase Authentication, Firestore, Storage ve Cloud Messaging'i etkinleştirin

5. **Android İzinleri**:
   `android/app/src/main/AndroidManifest.xml` dosyasına şu izinleri ekleyin:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```

6. **Uygulamayı çalıştırın**:
```bash
flutter run
```

## 📁 Proje Yapısı
```
lib/
├── main.dart                      # Uygulama giriş noktası
├── config/
│   ├── api_keys.dart             # API anahtarları (gitignore)
│   └── api_keys.example.dart     # API anahtarları şablonu
├── models/                        # Veri modelleri
│   ├── user_model.dart
│   ├── post_model.dart
│   ├── chat_model.dart
│   └── gym_model.dart
├── providers/                     # Riverpod state yöneticileri
│   ├── auth_provider.dart
│   ├── location_provider.dart
│   └── providers.dart
├── services/                      # API ve iş mantığı servisleri
│   ├── firebase_auth_service.dart
│   ├── firestore_post_service.dart
│   ├── firebase_chat_service.dart
│   ├── notification_service.dart
│   ├── deezer_service.dart
│   └── gym_service.dart
├── screens/                       # Ekranlar
│   ├── auth/                     # Kimlik doğrulama ekranları
│   ├── main/                     # Ana uygulama ekranları
│   ├── chat/                     # Sohbet ekranları
│   └── ...
├── widgets/                       # Yeniden kullanılabilir bileşenler
│   ├── post_card.dart
│   └── ...
└── utils/                        # Yardımcı fonksiyonlar
```

## 🔄 State Management

Bu proje **Riverpod** kullanıyor. Ana provider'lar:

- `authStateProvider`: Kullanıcı kimlik doğrulama durumu
- `currentUserProvider`: Mevcut kullanıcı bilgileri
- `userPostsProvider`: Kullanıcı gönderileri
- `userNotificationsProvider`: Kullanıcı bildirimleri

## 🎯 Gelecek Planları

- [ ] Story özelliği
- [ ] Antrenman takibi
- [ ] Fitness challenge'lar
- [ ] Karanlık mod
- [ ] Çoklu dil desteği
- [ ] Antrenman planı paylaşımı


**Not**: Bu uygulama hala geliştirme aşamasındadır. Bazı özellikler henüz tam olarak çalışmıyor olabilir. Firebase yapılandırmanızı yapmayı unutmayın!