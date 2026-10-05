/*
  Warnings:

  - You are about to drop the column `email` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `isGuest` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `membership` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `passwordHash` on the `User` table. All the data in the column will be lost.
  - You are about to drop the `RefreshToken` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "RefreshToken" DROP CONSTRAINT "RefreshToken_userId_fkey";

-- DropIndex
DROP INDEX "User_email_key";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "email",
DROP COLUMN "isGuest",
DROP COLUMN "membership",
DROP COLUMN "passwordHash";

-- DropTable
DROP TABLE "RefreshToken";

-- CreateTable
CREATE TABLE "DeviceCredential" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "secretHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastUsedAt" TIMESTAMP(3),
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "DeviceCredential_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HadithBook" (
    "id" INTEGER NOT NULL,
    "slug" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "authorAr" TEXT NOT NULL,
    "group" TEXT NOT NULL,
    "hadithCount" INTEGER NOT NULL DEFAULT 0,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "HadithBook_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HadithChapter" (
    "id" SERIAL NOT NULL,
    "bookId" INTEGER NOT NULL,
    "number" INTEGER NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT,

    CONSTRAINT "HadithChapter_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Hadith" (
    "id" SERIAL NOT NULL,
    "bookId" INTEGER NOT NULL,
    "chapterId" INTEGER,
    "number" INTEGER NOT NULL,
    "textAr" TEXT NOT NULL,
    "textSearch" TEXT NOT NULL,
    "textEn" TEXT,
    "narratorEn" TEXT,
    "grade" TEXT,
    "gradeSource" TEXT,

    CONSTRAINT "Hadith_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "DeviceCredential_secretHash_key" ON "DeviceCredential"("secretHash");

-- CreateIndex
CREATE INDEX "DeviceCredential_userId_idx" ON "DeviceCredential"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "HadithBook_slug_key" ON "HadithBook"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "HadithChapter_bookId_number_key" ON "HadithChapter"("bookId", "number");

-- CreateIndex
CREATE INDEX "Hadith_chapterId_idx" ON "Hadith"("chapterId");

-- CreateIndex
CREATE INDEX "Hadith_textSearch_idx" ON "Hadith" USING GIN ("textSearch" gin_trgm_ops);

-- CreateIndex
CREATE UNIQUE INDEX "Hadith_bookId_number_key" ON "Hadith"("bookId", "number");

-- AddForeignKey
ALTER TABLE "DeviceCredential" ADD CONSTRAINT "DeviceCredential_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HadithChapter" ADD CONSTRAINT "HadithChapter_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "HadithBook"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Hadith" ADD CONSTRAINT "Hadith_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "HadithBook"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Hadith" ADD CONSTRAINT "Hadith_chapterId_fkey" FOREIGN KEY ("chapterId") REFERENCES "HadithChapter"("id") ON DELETE SET NULL ON UPDATE CASCADE;
