# رفع «فضل» على Google Play — خطوة بخطوة

دليل لأول رفع على حساب مطوّر شخصي جديد. النصوص الجاهزة للنسخ في
[`store-listing.md`](store-listing.md)، والصور في [`store-assets/`](store-assets/).

## ١. إنشاء التطبيق (مرة واحدة)

| الخانة | القيمة |
|---|---|
| اسم التطبيق | `فضل - قرآن وأذان وأذكار` |
| اسم الحزمة | `com.fadl.fadl` (دُس «التحقق من التوفّر») |
| اللغة التلقائية | العربية – ar |
| تطبيق أو لعبة | تطبيق |
| مجاني أو مدفوع | مجاني |

اسم الحزمة والسعر المجاني **لا يتغيّران أبدًا بعد الإنشاء**. لو ظهر اسم
الحزمة محجوزًا، توقّف: يجب تغييره في الكود أولًا.

## ٢. ملف الرفع

```
cd "D:\New folder\fadl_app"
git checkout main
git pull origin main
flutter pub get
flutter clean
flutter build appbundle --release
```

الملف: `build\app\outputs\bundle\release\app-release.aab`، موقّع بمفتاح
الرفع في `android\key.properties`. عند أول رفع وافق على **Play App
Signing**: جوجل تحفظ مفتاح توقيع التطبيق، ومفتاح الرفع يمكن استبداله
لاحقًا من الحساب إذا ضاع.

كل رفع جديد يحتاج رقم إصدار أكبر: زِد الرقم بعد `+` في `pubspec.yaml`
(`version: 1.0.0+1` ثم `1.0.1+2` …).

## ٣. محتوى التطبيق (Policy ← App content)

| القسم | الإجابة |
|---|---|
| Privacy policy | `https://ahmedelazaizi.github.io/Fadl-Quran/` |
| Ads | No, my app does not contain ads |
| App access | All functionality is available without special access |
| Content rating | املأ الاستبيان: الفئة Reference/Other، وكل الأسئلة (عنف، محتوى جنسي، مقامرة، مخدرات، ألفاظ، تفاعل بين المستخدمين، مشاركة الموقع، مشتريات) = No |
| Target audience | 13–15، 16–17، 18 فما فوق (لا تختر فئات الأطفال، فتدخل سياسة Families) |
| News app | No |
| Data safety | Does your app collect or share any user data? **No** (الموقع يُستخدم على الجهاز فقط ولا يُرسل) |
| Advertising ID | No |
| Government app | No |
| Financial features | My app doesn't provide any financial features (حاسبة الزكاة حساب على الجهاز فقط) |
| Health | My app doesn't have health features |

### إقرار الخدمة في المقدّمة (Foreground service)

يظهر لأن التطبيق يستخدم `FOREGROUND_SERVICE_MEDIA_PLAYBACK`:

- النوع: **Media playback**.
- الوصف (انسخه):
  `Plays the full adhan at each prayer time, and Quran recitation the user starts, while the screen is locked or another app is open. The user starts and stops it from the notification.`
- أثر التأجيل: `The adhan would be late or cut off, and recitation would stop when the screen locks.`
- فيديو: صوّر من الموبايل ٢٠–٣٠ ثانية: «تجربة الأذان بعد دقيقة» من إعدادات الأذان ثم قفل الشاشة والأذان يعمل، وارفعه على YouTube «غير مدرج» (Unlisted) وضع الرابط.

لو سأل عن **Exact alarms**: الأذان منبّه في وقت محدد يضبطه المستخدم
(alarm clock / calendar-like reminder).

## ٤. صفحة المتجر (Grow ← Store presence ← Main store listing)

| الخانة | المصدر |
|---|---|
| اسم التطبيق | `فضل - قرآن وأذان وأذكار` |
| الوصف المختصر | `store-listing.md` ← الوصف المختصر |
| الوصف الكامل | `store-listing.md` ← الوصف الكامل — عربي |
| أيقونة التطبيق 512×512 | `store-assets/icon-512.png` |
| صورة الميزة 1024×500 | `store-assets/feature-graphic.png` |
| لقطات الهاتف | من ٢ إلى ٨ صور من الموبايل (رأسي): الرئيسية، المصحف، المواقيت، الأذكار، القبلة |
| الفئة | Lifestyle، والعلامات: Religion/Books & Reference حسب المتاح |
| البريد | `moathfdal555@gmail.com` |

ولإضافة الإنجليزية: Store listing ← Manage translations ← English، والنصوص
في نفس الملف.

## ٥. الاختبار المغلق (إلزامي للحسابات الشخصية الجديدة)

1. Testing ← Closed testing ← Create track (أو استخدم Alpha).
2. Countries: اختر الدول (الأردن ومصر وغيرها، أو كل الدول).
3. Testers: أنشئ قائمة بريد وأضف **١٢ بريد Gmail على الأقل**.
4. Create release ← ارفع `app-release.aab` ← اسم الإصدار `1.0.0 (1)` ←
   ملاحظات الإصدار من `store-listing.md` ← Review ← Start rollout.
5. بعد مراجعة جوجل (ساعات إلى أيام) انسخ **رابط الاشتراك** (Opt-in URL)
   وأرسله للمختبرين: يفتحونه بنفس بريدهم، يضغطون «أصبح مختبِرًا»، ثم
   ينزّلون التطبيق من المتجر.
6. يجب أن يبقى ١٢ مختبرًا على الأقل مشتركين **١٤ يومًا متتالية**.
   من كانت عنده النسخة التجريبية APK يحذفها أولًا.
7. بعدها: Dashboard ← Apply for production، وأجب عن أسئلة الاختبار
   (كيف جُنّد المختبرون، ما الملاحظات وما الذي تغيّر).

## ٦. بعد الموافقة على الإنتاج

Production ← Create release ← نفس الملف أو أحدث ← Start rollout. يظهر
التطبيق للجميع بعد المراجعة.
