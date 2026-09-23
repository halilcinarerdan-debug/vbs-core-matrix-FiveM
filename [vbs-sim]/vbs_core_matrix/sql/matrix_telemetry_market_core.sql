-- =====================================================================
-- MATRIX TELEMETRI + PIYASA ARZ/TALEP SEMASI
-- sql/matrix_telemetry_market_core.sql
--
-- Bu dosya EKLEMELİDİR (additive-only): mevcut sql/matrix_financial_core.sql
-- dosyasindaki HICBIR tablo/kolon DEGISTIRILMEZ/SILINMEZ (ALTER/DROP YOK).
-- Bagimsiz olarak, matrix_financial_core.sql'den SONRA herhangi bir sirada
-- calistirilabilir.
--
-- ★ NOT: sql/matrix_financial_core.sql icinde `matrix_raid_log` tablosu
-- ZATEN MEVCUT (trap_house_id/outcome/created_at kolonlariyla, bkz. o
-- dosya). Bu yuzden burada YENIDEN OLUSTURULMUYOR -- server/market.lua'nin
-- yeni arz/talep motoru (recent_raid_factor) o MEVCUT tabloyu okur.
--
-- Kullanilan tablolar:
--   1) matrix_player_telemetry      -- server/player_telemetry.lua write-behind hedefi
--   2) matrix_market_demand_supply  -- server/market.lua Matrix.Market.RecomputeDemandSupply hedefi
-- =====================================================================

CREATE TABLE IF NOT EXISTS `matrix_player_telemetry` (
    `citizenid`        VARCHAR(50) NOT NULL PRIMARY KEY,
    `active_hours`     TEXT        NULL,
    `preferred_zone`   INT         NULL,
    `aggression_index` FLOAT       NOT NULL DEFAULT 0.0,
    `escape_pattern`   FLOAT       NOT NULL DEFAULT 0.5,
    `spend_rate`       FLOAT       NOT NULL DEFAULT 0.0,
    `death_frequency`  FLOAT       NOT NULL DEFAULT 0.0,
    `trade_balance`    FLOAT       NOT NULL DEFAULT 0.0,
    `updated_at`       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS `matrix_market_demand_supply` (
    `zone_id`            INT          NOT NULL PRIMARY KEY,
    `demand_current`     FLOAT        NOT NULL DEFAULT 1.0,
    `supply_current`     FLOAT        NOT NULL DEFAULT 1.0,
    `last_recompute_at`  DATETIME     NULL,
    `trend_7d`           VARCHAR(16)  NOT NULL DEFAULT 'stable'
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- DROP TABLE IF EXISTS `matrix_market_demand_supply`;
-- DROP TABLE IF EXISTS `matrix_player_telemetry`;
