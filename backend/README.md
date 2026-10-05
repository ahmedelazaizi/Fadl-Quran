# Fadl Backend — الواجهة الخلفية لتطبيق «فضل»

واجهة برمجية (REST API) تخدم شاشات التطبيق الموجودة في `../stitch_ui`:
مواقيت الصلاة والقبلة، المصحف والتفاسير والتلاوات، الأذكار والأدعية، الختمة والمسبحة،
الإمساكية، المساعد القرآني، الإهداء (صدقة جارية)، ومحرّك الإشعارات عبر Firebase Cloud Messaging.

**التقنيات:** Node.js 20+ · TypeScript · Fastify 5 · Prisma 6 · PostgreSQL 17 · `adhan` لحساب المواقيت · `firebase-admin` للإشعارات.

## التشغيل محلياً

```bash
cp .env.example .env            # ثم عدّل JWT_SECRET
docker compose up -d            # PostgreSQL على المنفذ 5433 (+ قاعدة fadl_test للاختبارات)
npm install
npx prisma migrate deploy
npm run seed                    # يحمّل المصحف والتفاسير والأذكار (أول مرة يحتاج إنترنت)
npm run dev                     # http://localhost:3000  — التوثيق التفاعلي: /docs
npm run worker                  # عامل الإشعارات (في نافذة منفصلة)
```

> على Windows مع PowerShell استخدم `npm.cmd` و`npx.cmd` إذا كانت سياسة تشغيل السكربتات تمنع `npm`.

| الأمر | الوظيفة |
|---|---|
| `npm run dev` / `npm start` | تشغيل الـ API |
| `npm run worker` | إرسال الأذان والتذكيرات كل `NOTIFY_INTERVAL_SECONDS` |
| `npm run seed` | تعبئة البيانات المرجعية (آمن للتكرار؛ `-- --force` لإعادة الاستيراد) |
| `npm test` | الاختبارات (تُجهّز `fadl_test` تلقائياً) |
| `npm run typecheck` | فحص الأنواع |

## مصادر البيانات

| البيانات | المصدر | التخزين |
|---|---|---|
| نص المصحف (عثماني + إملائي)، الصفحات/الأجزاء/الأحزاب/السجدات | [alquran.cloud](https://alquran.cloud) (`quran-uthmani`, `quran-simple-clean`) | محلي |
| التفسير الميسر، الجلالين، ترجمة Saheeh International | alquran.cloud | محلي |
| السعدي، ابن كثير، الطبري، القرطبي، البغوي | [Quran.com API v4](https://api.quran.com) | يُجلب عند أول طلب لكل آية ثم يُخزَّن |
| ملفات الصوت (آية بآية، وسورة كاملة لبعض القراء) | `cdn.islamic.network` | روابط CDN (تم التحقق من معدلات البت لكل قارئ) |
| الأذكار (حصن المسلم: النص، الفضل، عدد التكرار، المرجع) | [osamayy/azkar-db](https://github.com/osamayy/azkar-db) | محلي |

لا توجد نصوص شرعية مكتوبة يدوياً في الكود: أدعية القرآن في مجموعات الأدعية مُشار إليها برقم الآية
(`scripts/seed-data.ts`) وتُقرأ من نص المصحف، والأذكار من حصن المسلم.
مستودع الأذكار لا يذكر ترخيصاً صريحاً؛ راجعه قبل النشر التجاري.

## الشاشات ← نقاط الوصول

جميع المسارات تحت البادئة `/api/v1`. المسارات التي تبدأ بـ `/me` تتطلب `Authorization: Bearer <accessToken>`.

| الشاشة | نقاط الوصول |
|---|---|
| الرئيسية | `GET /me/dashboard` (قبس اليوم، الصلاة القادمة والعدّاد، الختمة، المسبحة، آخر قراءة) |
| المصحف | `GET /quran/surahs`, `/quran/surahs/:id`, `/quran/pages/:page`, `/quran/juz/:n`, `/quran/ayahs/:key`, `/quran/ayahs/:key/tafsir?edition=`, `/quran/editions` |
| الاستماع | `GET /quran/reciters`, `GET /quran/audio/surahs/:id?reciter=&bitrate=` |
| المساعد والبحث | `GET /search?q=`, `GET /assistant/topics`, `POST /assistant/ask` |
| مواقيت الصلاة | `GET /prayer/times`, `/prayer/calendar`, `/prayer/methods`, `/hijri`, `GET /me/prayer` |
| القبلة | `GET /qibla?lat=&lng=` (الاتجاه من الشمال الحقيقي + المسافة بالكيلومتر) |
| الأذكار | `GET /athkar/categories`, `/athkar/categories/:slug`, `/athkar/search`, `GET/PUT /me/athkar/progress` |
| المسبحة | `GET /me/tasbeeh`, `POST /me/tasbeeh/entries`, `POST/PATCH/DELETE /me/tasbeeh/dhikrs`, `DELETE /me/tasbeeh/today/:dhikrId` |
| الختمة | `GET /khatma/presets`, `GET/POST /me/khatmas`, `POST /me/khatmas/:id/progress`, `GET /me/khatmas/:id/logs` |
| رمضان | `GET /ramadan/imsakiya`, `GET/PUT /me/checklist` |
| دعاء للوالد / صدقة جارية | `GET /duas/collections/:slug`, `POST /duas/amen`, `POST /me/dedications`, `GET /me/dedications/stats`, `GET /stats/dedications`, `GET/POST/DELETE /me/duas` |
| الإعدادات والإشعارات | `GET/PATCH /me/settings`, `GET/PATCH /me/notifications`, `POST/DELETE /me/devices`, `GET /me/notifications/upcoming` |
| الفواصل | `GET/POST/DELETE /me/bookmarks`, `GET/PUT /me/last-read` |

التوثيق الكامل لكل حقل متاح في `/docs` (OpenAPI).

## الحسابات

- `POST /auth/guest` ينشئ حساباً بدون تسجيل (التطبيق لا يحتوي شاشة دخول)، ويعيد `accessToken` (15 دقيقة) و`refreshToken` (60 يوماً).
- `POST /auth/register` مع توكن الضيف يحوّل الحساب نفسه إلى حساب بريد/كلمة مرور دون فقدان البيانات.
- `POST /auth/refresh` يدوّر التوكن؛ إعادة استخدام توكن قديم تُبطل كل الجلسات.
- كلمات المرور مخزنة بـ scrypt. `DELETE /me` يحذف الحساب وكل بياناته.

## مواقيت الصلاة

- طرق الحساب: أم القرى، الهيئة المصرية، رابطة العالم الإسلامي، كراتشي، دبي، الكويت، قطر، سنغافورة، تركيا، طهران، ISNA، لجنة رؤية الهلال.
- المذهب (جمهور/حنفي للعصر)، قاعدة خطوط العرض العليا، تعديل دقائق لكل صلاة، وتصحيح التاريخ الهجري (±3 أيام).
- مع أم القرى يصبح العشاء بعد المغرب بـ 120 دقيقة في رمضان.
- التاريخ الهجري بتقويم أم القرى (`Intl`)، وقد يختلف عن الرؤية المحلية — استخدم `hijriAdjustment`.
- يجب أن يرسل التطبيق المنطقة الزمنية IANA (مثل `Asia/Riyadh`)؛ وتُحفظ في إعدادات المستخدم.

## الإشعارات

العامل (`npm run worker`) يحسب لكل مستخدم لديه جهاز مسجل وموقع محفوظ ما يستحق الإرسال الآن:
الأذان لكل صلاة، التنبيه قبل الأذان، أذكار الصباح/المساء/النوم، الثلث الأخير من الليل، الضحى،
الكهف وساعة الإجابة يوم الجمعة، صيام الاثنين والخميس (ليلة قبله، ولا يُرسل قبل العيد وأيام التشريق)،
الأيام البيض، ووِرد الختمة إن بقيت صفحات اليوم.

- كل إشعار له مفتاح فريد في `NotificationLog`، فلا يتكرر حتى مع إعادة التشغيل أو تشغيل أكثر من عامل.
- بدون `FIREBASE_SERVICE_ACCOUNT_PATH` يعمل العامل بوضع `log` ويطبع الإشعارات فقط.
- التوكنات التي يرفضها FCM تُحذف تلقائياً.
- على Android تُرسل إشعارات الأذان على قناة `adhan_<sound>` وعلى iOS بصوت `<sound>.caf`، ويجب أن يُنشئ التطبيق القناة ويضمّن ملف الصوت.
- يُنصح بأن يجدول التطبيق أيضاً إشعارات محلية من `GET /me/notifications/upcoming` كاحتياط عند انقطاع الإنترنت.

## المساعد القرآني

`POST /assistant/ask` يبحث في نص المصحف (بدون تشكيل) والأذكار، ويعرض لكل موضوع من المواضيع المقترحة
آيات مختارة أولاً. عند ضبط `ANTHROPIC_API_KEY` يكتب Claude إجابة قصيرة مبنية **فقط** على المصادر المسترجعة؛
وبدونه تعود النتائج مع ملخص ثابت.

## ما لم يُنفّذ بعد

- قاعدة أحاديث مستقلة (شاشة البحث تعرض أحاديث؛ حالياً المتاح أذكار حصن المسلم بمراجعها).
- رواية ورش وخط النسخ (الحقل `mushafScript` محفوظ في الإعدادات لكن النص المتوفر حفص بالرسم العثماني).
- تصدير الإمساكية PDF، وتسجيل الدخول عبر Google/Apple.
