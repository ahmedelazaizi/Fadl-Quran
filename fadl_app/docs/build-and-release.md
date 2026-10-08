# بناء «فضل» ونشره على Google Play وApp Store

نسختا أندرويد وiOS تُبنيان من نفس المجلد `fadl_app`، ومن نفس الكود. الفرق الوحيد هو الجهاز: **أندرويد يُبنى على ويندوز، وiOS لا يُبنى إلا على ماك** (شرط من آبل: Xcode والمحاكي يعملان على macOS فقط).

## 1. أندرويد (على ويندوز)

```powershell
cd "D:\New folder\fadl_app"
git pull origin main
flutter pub get
flutter build appbundle --release
```

الملف الناتج: `build\app\outputs\bundle\release\app-release.aab`. هذا ما يُرفع على Google Play Console.

### التوقيع (مهم)

- يُوقَّع الملف بالمفتاح المذكور في `android\key.properties`. هذا الملف والمفتاح `.jks` لا يُرفعان على GitHub أبدًا.
- يجب أن تُوقَّع كل التحديثات بنفس المفتاح. احتفظوا بنسختين منه في مكانين آمنين.
- الأفضل أن يكون المفتاح عند صاحب الحساب، أو أن تُفعَّل «Play App Signing» في Play Console، فيصبح هذا المفتاح «مفتاح رفع» يمكن استبداله لو ضاع.
- للتجربة على هاتف دون متجر: `flutter build apk --release`، والملف في `build\app\outputs\flutter-apk\app-release.apk`.

## 2. iOS (آيفون وآيباد)

### المتطلبات

- **جهاز ماك عليه Xcode** من App Store. ماك صاحب التطبيق، أو ماك مستأجر في السحابة مثل MacinCloud أو AWS EC2 Mac.
- **حساب Apple Developer** باسم صاحب التطبيق، اشتراكه 99 دولارًا سنويًا.
- Flutter نفس الإصدار المستخدم في المشروع (3.41)، وCocoaPods (`brew install cocoapods`).

### التشغيل على المحاكي (على الماك)

```bash
cd fadl_app
flutter pub get
open -a Simulator        # يفتح محاكي آيفون
flutter run              # يبني التطبيق ويشغّله على المحاكي
```

لتجربة الآيباد: من قائمة Simulator اختر File ← Open Simulator ← أي iPad، ثم `flutter run` مرة أخرى.

### التوقيع لأول مرة (مرة واحدة على الماك)

1. افتح `ios/Runner.xcworkspace` في Xcode (لا تفتح `.xcodeproj`).
2. اختر الهدف **Runner** ثم تبويب Signing & Capabilities، وفعّل Automatically manage signing واختر فريق (Team) صاحب الحساب.
3. كرّر نفس الخطوة للهدف **PrayerWidgetExtension** (ويدجت المواقيت).
4. معرّف التطبيق الحالي `com.fadl.fadl`، ومعرّف الويدجت `com.fadl.fadl.PrayerWidget`.
   - لو رفضه Xcode لأنه محجوز، غيّره لمعرّف خاص بصاحب الحساب، مثل `com.ownername.fadl`، في الهدفين بنفس البادئة.
   - وعندها يجب تغيير `applicationId` في أندرويد ليطابقه.
5. **App Group:** التطبيق والويدجت يتشاركان مواقيت الصلاة عبر `group.com.fadl.fadl`، وXcode يسجّله تلقائيًا مع التوقيع.
   - لو غيّرت المعرّف فغيّر اسم المجموعة بنفس الشكل في الملفات الأربعة:
     - `ios/Runner/Runner.entitlements`
     - `ios/PrayerWidget/PrayerWidget.entitlements`
     - `ios/Runner/AppDelegate.swift`
     - `ios/PrayerWidget/PrayerWidget.swift`

### البناء والرفع على App Store

```bash
cd fadl_app
flutter build ipa --release
```

ثم ارفع الملف الناتج في `build/ios/ipa/` بإحدى طريقتين:

- **تطبيق Transporter** من App Store على الماك: اسحب الملف إليه ثم Deliver.
- **أو من Xcode:** افتح `build/ios/archive/Runner.xcarchive`، ثم Distribute App ← App Store Connect.

بعد دقائق تظهر النسخة في App Store Connect. جرّبها على الآيفون من تطبيق **TestFlight** قبل إرسالها للمراجعة.

### بدون ماك

- **المحاكي:** لا توجد طريقة لتشغيل محاكي iOS على ويندوز.
- **التأكد من أن الكود يُبنى:** كل تعديل على GitHub يبنيه Workflow اسمه **iOS build** على ماك من GitHub (`.github/workflows/ios.yml`)، وينتج ملف `fadl-ios-unsigned.ipa`. هذا الملف غير موقّع، فلا يُثبَّت على آيفون ولا يُرفع على المتجر.
- **الرفع التلقائي:** يمكن إضافة رفع تلقائي إلى TestFlight من GitHub بعد أن يُنشئ صاحب الحساب مفتاح App Store Connect API (دور Admin) ويضيفه كـ Secrets في المستودع. وقتها يكفي الضغط على زر في GitHub بدل الحاجة إلى ماك.

## 3. قبل كل إصدار

- **رقم الإصدار:** ارفع `version` في `pubspec.yaml`، مثلًا من `1.0.0+1` إلى `1.0.1+2`. الرقم بعد `+` يجب أن يزيد في كل رفع على المتجرين.
- **الفحوص:**

  ```
  flutter analyze
  flutter test
  ```

  ويجب أن يكون فحص **iOS build** أخضر على GitHub.
- **ما يحتاج تجربة على أجهزة حقيقية:**
  - الأذان على أندرويد.
  - إشعار الصلاة بصوت الأذان (30 ثانية) على الآيفون.
  - الويدجت على الشاشة الرئيسية وشاشة القفل.
  - تشغيل التلاوة والشاشة مقفولة.

## 4. نصوص تُطلب عند النشر

- **سياسة الخصوصية:** يطلبها المتجران. التطبيق لا يجمع بيانات، والموقع يُستخدم على الجهاز فقط لحساب المواقيت والقبلة.
- **App Store Connect:** في قسم App Privacy اختر «Data Not Collected»، إلا لو فُعّل الخادم الاختياري لاحقًا.
- **Google Play:** في نموذج Data safety اختر «لا يجمع بيانات».
- **صلاحيات أندرويد:** صلاحية المنبّهات الدقيقة تحتاج تبريرًا في Play Console: «تطبيق مواقيت صلاة يرفع الأذان في وقته».
