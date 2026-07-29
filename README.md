# USCIS Case Tracker

SwiftUI tabanlı iPhone uygulaması. İlk sürüm:

- USCIS makbuz numarası ekleme ve doğrulama
- Birden fazla dosyayı yerel olarak saklama
- Durum özeti ve zaman çizelgesi
- Demo verisiyle çevrimdışı çalışma
- Güvenli bir backend API'sine bağlanmaya hazır servis katmanı

## Açma

`USCISCaseTracker.xcodeproj` dosyasını Xcode ile açın, geliştirme takımınızı seçin ve bir iPhone simülatöründe çalıştırın.

## Canlı API bağlantısı

`AppConfiguration.swift` içindeki `backendBaseURL` değerini kendi HTTPS backend adresinizle değiştirin. USCIS client secret anahtarını iPhone uygulamasına koymayın.

Backend sözleşmesi:

`GET /v1/cases/{receiptNumber}`

```json
{
  "receiptNumber": "IOE0912345678",
  "formType": "I-485",
  "title": "Case Was Received",
  "description": "We received your case.",
  "updatedAt": "2026-07-28T12:00:00Z"
}
```

