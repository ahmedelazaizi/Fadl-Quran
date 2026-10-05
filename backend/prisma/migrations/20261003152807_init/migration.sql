-- CreateEnum
CREATE TYPE "RevelationType" AS ENUM ('MECCAN', 'MEDINAN');

-- CreateEnum
CREATE TYPE "EditionType" AS ENUM ('TAFSIR', 'TRANSLATION');

-- CreateEnum
CREATE TYPE "EditionSource" AS ENUM ('LOCAL', 'QURAN_COM');

-- CreateEnum
CREATE TYPE "BookmarkKind" AS ENUM ('BOOKMARK', 'LAST_READ');

-- CreateEnum
CREATE TYPE "KhatmaStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "DedicationType" AS ENUM ('KHATMA', 'READING', 'LISTENING', 'TASBEEH', 'ATHKAR', 'DUA', 'OTHER');

-- CreateTable
CREATE TABLE "Surah" (
    "id" INTEGER NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameTranslit" TEXT NOT NULL,
    "revelationType" "RevelationType" NOT NULL,
    "ayahCount" INTEGER NOT NULL,
    "startPage" INTEGER NOT NULL,

    CONSTRAINT "Surah_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Ayah" (
    "id" INTEGER NOT NULL,
    "surahId" INTEGER NOT NULL,
    "number" INTEGER NOT NULL,
    "key" TEXT NOT NULL,
    "textUthmani" TEXT NOT NULL,
    "textSimple" TEXT NOT NULL,
    "textSearch" TEXT NOT NULL,
    "juz" INTEGER NOT NULL,
    "hizbQuarter" INTEGER NOT NULL,
    "page" INTEGER NOT NULL,
    "manzil" INTEGER NOT NULL,
    "ruku" INTEGER NOT NULL,
    "sajda" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "Ayah_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TextEdition" (
    "slug" TEXT NOT NULL,
    "type" "EditionType" NOT NULL,
    "language" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "source" "EditionSource" NOT NULL,
    "externalId" INTEGER,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "TextEdition_pkey" PRIMARY KEY ("slug")
);

-- CreateTable
CREATE TABLE "AyahText" (
    "editionSlug" TEXT NOT NULL,
    "ayahId" INTEGER NOT NULL,
    "text" TEXT NOT NULL,
    "fetchedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AyahText_pkey" PRIMARY KEY ("editionSlug","ayahId")
);

-- CreateTable
CREATE TABLE "Reciter" (
    "id" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "style" TEXT NOT NULL,
    "riwaya" TEXT NOT NULL DEFAULT 'حفص عن عاصم',
    "verseBitrates" INTEGER[],
    "surahBitrate" INTEGER,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "Reciter_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AthkarCategory" (
    "id" SERIAL NOT NULL,
    "slug" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "featured" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "AthkarCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Dhikr" (
    "id" SERIAL NOT NULL,
    "categoryId" INTEGER NOT NULL,
    "text" TEXT NOT NULL,
    "virtue" TEXT,
    "repeat" INTEGER NOT NULL DEFAULT 1,
    "reference" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "textSearch" TEXT NOT NULL,

    CONSTRAINT "Dhikr_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DuaCollection" (
    "id" SERIAL NOT NULL,
    "slug" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "DuaCollection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DuaCollectionItem" (
    "id" SERIAL NOT NULL,
    "collectionId" INTEGER NOT NULL,
    "dhikrId" INTEGER,
    "verseRange" TEXT,
    "repeat" INTEGER NOT NULL DEFAULT 1,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "DuaCollectionItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AmenCounter" (
    "targetKey" TEXT NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "AmenCounter_pkey" PRIMARY KEY ("targetKey")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT,
    "passwordHash" TEXT,
    "displayName" TEXT,
    "isGuest" BOOLEAN NOT NULL DEFAULT true,
    "membership" TEXT NOT NULL DEFAULT 'FREE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserSettings" (
    "userId" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "locationName" TEXT,
    "timezone" TEXT NOT NULL DEFAULT 'Asia/Riyadh',
    "calcMethod" TEXT NOT NULL DEFAULT 'UmmAlQura',
    "madhab" TEXT NOT NULL DEFAULT 'shafi',
    "highLatRule" TEXT,
    "adjustments" JSONB NOT NULL DEFAULT '{}',
    "hijriAdjustment" INTEGER NOT NULL DEFAULT 0,
    "theme" TEXT NOT NULL DEFAULT 'light',
    "mushafScript" TEXT NOT NULL DEFAULT 'uthmani_hafs',
    "fontSize" INTEGER NOT NULL DEFAULT 24,
    "reciterId" TEXT NOT NULL DEFAULT 'ar.abdulbasitmurattal',
    "audioQuality" INTEGER NOT NULL DEFAULT 128,
    "continuousPlay" BOOLEAN NOT NULL DEFAULT true,
    "tafsirSlug" TEXT NOT NULL DEFAULT 'ar.muyassar',
    "language" TEXT NOT NULL DEFAULT 'ar',
    "dedicateeName" TEXT,
    "tasbeehDailyGoal" INTEGER NOT NULL DEFAULT 100,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserSettings_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "Bookmark" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "ayahId" INTEGER NOT NULL,
    "kind" "BookmarkKind" NOT NULL DEFAULT 'BOOKMARK',
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Bookmark_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "KhatmaPlan" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "khatmaCount" INTEGER NOT NULL DEFAULT 1,
    "durationDays" INTEGER NOT NULL,
    "startDate" DATE NOT NULL,
    "currentPage" INTEGER NOT NULL DEFAULT 1,
    "status" "KhatmaStatus" NOT NULL DEFAULT 'ACTIVE',
    "reminderTime" TEXT,
    "dedicated" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "KhatmaPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "KhatmaLog" (
    "id" TEXT NOT NULL,
    "planId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "fromPage" INTEGER NOT NULL,
    "toPage" INTEGER NOT NULL,
    "pages" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "KhatmaLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TasbeehDhikr" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "target" INTEGER NOT NULL DEFAULT 33,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TasbeehDhikr_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TasbeehEntry" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "dhikrId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "count" INTEGER NOT NULL,
    "clientEventId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TasbeehEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AthkarProgress" (
    "userId" TEXT NOT NULL,
    "dhikrId" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "count" INTEGER NOT NULL,

    CONSTRAINT "AthkarProgress_pkey" PRIMARY KEY ("userId","dhikrId","date")
);

-- CreateTable
CREATE TABLE "DailyChecklist" (
    "userId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "key" TEXT NOT NULL,
    "done" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "DailyChecklist_pkey" PRIMARY KEY ("userId","date","key")
);

-- CreateTable
CREATE TABLE "Dedication" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" "DedicationType" NOT NULL,
    "amount" INTEGER NOT NULL DEFAULT 1,
    "dedicateeName" TEXT,
    "refKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Dedication_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CustomDua" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CustomDua_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserAmen" (
    "userId" TEXT NOT NULL,
    "targetKey" TEXT NOT NULL,
    "date" DATE NOT NULL,

    CONSTRAINT "UserAmen_pkey" PRIMARY KEY ("userId","targetKey","date")
);

-- CreateTable
CREATE TABLE "Device" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "fcmToken" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "locale" TEXT NOT NULL DEFAULT 'ar',
    "appVersion" TEXT,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationSettings" (
    "userId" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "adhan" JSONB NOT NULL DEFAULT '{"fajr":true,"sunrise":false,"dhuhr":true,"asr":true,"maghrib":true,"isha":true}',
    "adhanSound" TEXT NOT NULL DEFAULT 'makkah',
    "preAlertMinutes" INTEGER NOT NULL DEFAULT 15,
    "morningAthkarTime" TEXT DEFAULT '06:00',
    "eveningAthkarTime" TEXT DEFAULT '17:00',
    "sleepAthkarTime" TEXT,
    "qiyamEnabled" BOOLEAN NOT NULL DEFAULT false,
    "duhaEnabled" BOOLEAN NOT NULL DEFAULT false,
    "fridayKahf" BOOLEAN NOT NULL DEFAULT true,
    "fridayHour" BOOLEAN NOT NULL DEFAULT false,
    "mondayThursdayFast" BOOLEAN NOT NULL DEFAULT false,
    "whiteDaysFast" BOOLEAN NOT NULL DEFAULT false,
    "khatmaReminder" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationSettings_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "NotificationLog" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "fireAt" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'SENT',
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NotificationLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Ayah_key_key" ON "Ayah"("key");

-- CreateIndex
CREATE INDEX "Ayah_page_idx" ON "Ayah"("page");

-- CreateIndex
CREATE INDEX "Ayah_juz_idx" ON "Ayah"("juz");

-- CreateIndex
CREATE UNIQUE INDEX "Ayah_surahId_number_key" ON "Ayah"("surahId", "number");

-- CreateIndex
CREATE UNIQUE INDEX "AthkarCategory_slug_key" ON "AthkarCategory"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "AthkarCategory_nameAr_key" ON "AthkarCategory"("nameAr");

-- CreateIndex
CREATE INDEX "Dhikr_categoryId_idx" ON "Dhikr"("categoryId");

-- CreateIndex
CREATE UNIQUE INDEX "DuaCollection_slug_key" ON "DuaCollection"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");

-- CreateIndex
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");

-- CreateIndex
CREATE INDEX "Bookmark_userId_kind_idx" ON "Bookmark"("userId", "kind");

-- CreateIndex
CREATE UNIQUE INDEX "Bookmark_userId_ayahId_kind_key" ON "Bookmark"("userId", "ayahId", "kind");

-- CreateIndex
CREATE INDEX "KhatmaPlan_userId_status_idx" ON "KhatmaPlan"("userId", "status");

-- CreateIndex
CREATE INDEX "KhatmaLog_planId_date_idx" ON "KhatmaLog"("planId", "date");

-- CreateIndex
CREATE INDEX "TasbeehDhikr_userId_idx" ON "TasbeehDhikr"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "TasbeehEntry_clientEventId_key" ON "TasbeehEntry"("clientEventId");

-- CreateIndex
CREATE INDEX "TasbeehEntry_userId_date_idx" ON "TasbeehEntry"("userId", "date");

-- CreateIndex
CREATE INDEX "Dedication_userId_type_idx" ON "Dedication"("userId", "type");

-- CreateIndex
CREATE INDEX "CustomDua_userId_idx" ON "CustomDua"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Device_fcmToken_key" ON "Device"("fcmToken");

-- CreateIndex
CREATE INDEX "Device_userId_idx" ON "Device"("userId");

-- CreateIndex
CREATE INDEX "NotificationLog_createdAt_idx" ON "NotificationLog"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationLog_userId_key_key" ON "NotificationLog"("userId", "key");

-- AddForeignKey
ALTER TABLE "Ayah" ADD CONSTRAINT "Ayah_surahId_fkey" FOREIGN KEY ("surahId") REFERENCES "Surah"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AyahText" ADD CONSTRAINT "AyahText_editionSlug_fkey" FOREIGN KEY ("editionSlug") REFERENCES "TextEdition"("slug") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AyahText" ADD CONSTRAINT "AyahText_ayahId_fkey" FOREIGN KEY ("ayahId") REFERENCES "Ayah"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Dhikr" ADD CONSTRAINT "Dhikr_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "AthkarCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DuaCollectionItem" ADD CONSTRAINT "DuaCollectionItem_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "DuaCollection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DuaCollectionItem" ADD CONSTRAINT "DuaCollectionItem_dhikrId_fkey" FOREIGN KEY ("dhikrId") REFERENCES "Dhikr"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserSettings" ADD CONSTRAINT "UserSettings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Bookmark" ADD CONSTRAINT "Bookmark_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Bookmark" ADD CONSTRAINT "Bookmark_ayahId_fkey" FOREIGN KEY ("ayahId") REFERENCES "Ayah"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "KhatmaPlan" ADD CONSTRAINT "KhatmaPlan_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "KhatmaLog" ADD CONSTRAINT "KhatmaLog_planId_fkey" FOREIGN KEY ("planId") REFERENCES "KhatmaPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TasbeehDhikr" ADD CONSTRAINT "TasbeehDhikr_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TasbeehEntry" ADD CONSTRAINT "TasbeehEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TasbeehEntry" ADD CONSTRAINT "TasbeehEntry_dhikrId_fkey" FOREIGN KEY ("dhikrId") REFERENCES "TasbeehDhikr"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AthkarProgress" ADD CONSTRAINT "AthkarProgress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AthkarProgress" ADD CONSTRAINT "AthkarProgress_dhikrId_fkey" FOREIGN KEY ("dhikrId") REFERENCES "Dhikr"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyChecklist" ADD CONSTRAINT "DailyChecklist_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Dedication" ADD CONSTRAINT "Dedication_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CustomDua" ADD CONSTRAINT "CustomDua_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserAmen" ADD CONSTRAINT "UserAmen_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationSettings" ADD CONSTRAINT "NotificationSettings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationLog" ADD CONSTRAINT "NotificationLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
