-- Dummy data for sugar_records
INSERT INTO sugar_records (date, time, mealTimeCategory, mealType, value, status, notes) VALUES
(1727323200000, '08:05', 'beforeMeal', 'breakfast', 95.0, 'Normal', 'Feeling good'),
(1727328600000, '09:30', 'afterMeal', 'breakfast', 135.0, 'Normal', ''),
(1727240400000, '13:10', 'beforeMeal', 'lunch', 102.0, 'Normal', ''),
(1727247600000, '15:15', 'afterMeal', 'lunch', 155.0, 'Elevated', 'Ate a heavy meal'),
(1727163600000, '19:00', 'beforeMeal', 'dinner', 98.0, 'Normal', ''),
(1727083200000, '08:15', 'beforeMeal', 'breakfast', 110.0, 'Normal', ''),
(1726996800000, '13:05', 'beforeMeal', 'lunch', 92.0, 'Normal', 'Feeling a bit tired'),
(1726914000000, '19:30', 'afterMeal', 'dinner', 165.0, 'High', 'Had dessert'),
(1726824000000, '08:00', 'beforeMeal', 'breakfast', 88.0, 'Normal', ''),
(1726741200000, '12:30', 'afterMeal', 'lunch', 142.0, 'Normal', ''),
(1726654800000, '09:00', 'beforeMeal', 'breakfast', 75.0, 'Low', 'Skipped morning snack'),
(1726568400000, '20:00', 'afterMeal', 'dinner', 130.0, 'Normal', '');

-- Dummy data for bp_records
INSERT INTO bp_records (date, time, timeName, systolic, diastolic, pulseRate, status) VALUES
(1727323200000, '08:10', 'morning', 118, 78, 68, 'Normal'),
(1727240400000, '13:15', 'afternoon', 122, 80, 72, 'Normal'),
(1727154000000, '18:30', 'evening', 125, 82, 75, 'Elevated'),
(1727083200000, '08:20', 'morning', 115, 75, 65, 'Normal'),
(1726996800000, '13:25', 'afternoon', 135, 88, 80, 'Hypertension Stage 1'),
(1726910400000, '19:00', 'evening', 128, 85, 78, 'Elevated'),
(1726824000000, '08:05', 'morning', 112, 72, 64, 'Normal'),
(1726737600000, '12:00', 'afternoon', 120, 79, 70, 'Normal'),
(1726651200000, '09:30', 'morning', 132, 86, 82, 'Hypertension Stage 1'),
(1726564800000, '20:15', 'evening', 124, 81, 73, 'Normal'),
(1726478400000, '14:00', 'afternoon', 119, 77, 69, 'Normal'),
(1726392000000, '07:45', 'morning', 121, 76, 66, 'Normal');
