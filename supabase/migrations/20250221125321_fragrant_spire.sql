/*
  # Fix duplicate traits and data inconsistencies

  1. Changes
    - Clean up duplicate traits by merging them
    - Fix Level category naming
    - Update trait counts and rarities
    - Resync all hero traits
    - Recalculate rarity scores and ranks

  2. Process
    - Merge duplicate traits while preserving associations
    - Update all trait categories to be consistent
    - Recalculate all statistics
*/

-- First, fix the Level category naming
UPDATE traits
SET category = 'Level'
WHERE category = 'Season 1 Level';

-- Create a temporary table to store unique traits
CREATE TEMP TABLE unique_traits AS
SELECT 
  MIN(id) as id,
  category,
  value,
  SUM(count) as total_count
FROM traits
GROUP BY category, value;

-- Update hero_traits to point to the correct trait IDs
WITH duplicate_traits AS (
  SELECT 
    t1.id as old_id,
    ut.id as new_id
  FROM traits t1
  JOIN unique_traits ut ON t1.category = ut.category AND t1.value = ut.value
  WHERE t1.id != ut.id
)
UPDATE hero_traits ht
SET trait_id = dt.new_id
FROM duplicate_traits dt
WHERE ht.trait_id = dt.old_id;

-- Delete duplicate traits
DELETE FROM traits t
WHERE NOT EXISTS (
  SELECT 1 FROM unique_traits ut
  WHERE ut.id = t.id
);

-- Update traits with correct counts
WITH trait_counts AS (
  SELECT 
    trait_id,
    COUNT(*) as actual_count
  FROM hero_traits
  GROUP BY trait_id
)
UPDATE traits t
SET count = tc.actual_count
FROM trait_counts tc
WHERE t.id = tc.trait_id;

-- Recalculate rarities
WITH total_heroes AS (
  SELECT COUNT(*) as count FROM heroes
)
UPDATE traits t
SET rarity = (t.count::decimal / th.count) * 100
FROM total_heroes th;

-- Resync all hero traits to ensure consistency
DO $$
DECLARE
  hero_record record;
BEGIN
  FOR hero_record IN SELECT id FROM heroes LOOP
    PERFORM sync_hero_traits(hero_record.id);
  END LOOP;
END $$;

-- Update trait counts one final time
SELECT update_trait_counts();

-- Recalculate all rarity scores and ranks
SELECT update_rarity_ranks();