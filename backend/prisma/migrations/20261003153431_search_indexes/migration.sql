-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- CreateIndex
CREATE INDEX "Ayah_textSearch_idx" ON "Ayah" USING GIN ("textSearch" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "Dhikr_textSearch_idx" ON "Dhikr" USING GIN ("textSearch" gin_trgm_ops);
