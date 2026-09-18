--Создание схем для проекта E-commerce Customer Analysis
--Скрипт выполняется в базе данных ecommerce_analysis

--raw хранит детальные данные, загруженные из подготовленных CSV-файлов
CREATE SCHEMA IF NOT EXISTS raw;

COMMENT ON SCHEMA raw IS
    'Event-level source data imported into PostgreSQL';

--analytics хранит аналитические таблицы и представления для Power BI
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA analytics IS
    'Analytical tables and views for reporting and Power BI';