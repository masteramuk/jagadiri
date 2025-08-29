CREATE TABLE IF NOT EXISTS sugar_reference(
  id INTEGER PRIMARY KEY,
  scenario TEXT,
  unit TEXT,
  meal_time TEXT,
  meal_type TEXT,
  min_value REAL,
  max_value REAL,
  created_at INTEGER DEFAULT (unixepoch())
);

INSERT INTO sugar_reference (id, scenario, unit, meal_time, meal_type, min_value, max_value) VALUES
(1, 'Non-diabetic', 'mmol/L', 'BEFORE', 'breakfast', 3.9, 5.5),
(2, 'Non-diabetic', 'mmol/L', 'AFTER', 'breakfast', 0.0, 7.8),
(3, 'Prediabetes', 'mmol/L', 'BEFORE', 'breakfast', 5.6, 6.9),
(4, 'Prediabetes', 'mmol/L', 'AFTER', 'breakfast', 7.8, 11.0),
(5, 'Diabetes-ADA', 'mmol/L', 'BEFORE', 'breakfast', 4.4, 7.2),
(6, 'Diabetes-ADA', 'mmol/L', 'AFTER', 'breakfast', 0.0, 10.0),
(7, 'Severe-Hyper', 'mmol/L', 'ANY', 'ANY', 11.1, 999.0),
(8, 'Hypoglycaemia', 'mmol/L', 'ANY', 'ANY', 0.0, 3.8),
(9, 'Non-diabetic', 'mg/dL', 'BEFORE', 'breakfast', 70.2, 99.0),
(10, 'Non-diabetic', 'mg/dL', 'AFTER', 'breakfast', 0.0, 140.4),
(11, 'Prediabetes', 'mg/dL', 'BEFORE', 'breakfast', 100.8, 124.2),
(12, 'Prediabetes', 'mg/dL', 'AFTER', 'breakfast', 140.4, 198.0),
(13, 'Diabetes-ADA', 'mg/dL', 'BEFORE', 'breakfast', 79.2, 129.6),
(14, 'Diabetes-ADA', 'mg/dL', 'AFTER', 'breakfast', 0.0, 180.0),
(15, 'Severe-Hyper', 'mg/dL', 'ANY', 'ANY', 199.8, 17982.0),
(16, 'Hypoglycaemia', 'mg/dL', 'ANY', 'ANY', 0.0, 68.4);
