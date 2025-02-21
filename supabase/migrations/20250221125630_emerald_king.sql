/*
  # Fix duplicate traits and data inconsistencies

  1. Changes
    - Clean up duplicate traits by merging them
    - Fix Level category naming
    - Update trait counts and rarities
    - Resync all hero traits
    - Recalculate rarity scores and ranks

  2. Process
    - Handle Level category renaming first
    - Merge duplicate traits while preserving associations
    - Update all statistics
*/

DO $$ 
DECLARE
  total_heroes integer;
BEGIN
  -- Get total number of heroes for rarity calculation
  SELECT COUNT(*) INTO total_heroes FROM heroes;

  -- First, handle the Level category renaming
  WITH level_traits AS (
    SELECT 
      t1.id as keep_id,
      t2.id as remove_id,
      t1.value,
      t1.count + t2.count as total_count
    FROM traits t1
    JOIN traits t2 ON t1.value = t2.value
    WHERE t1.category = 'Level'
    AND t2.category = 'Season 1 Level'
  )
  UPDATE traits t
  SET count = lt.total_count
  FROM level_traits lt
  WHERE t.id = lt.keep_id;

  -- Update hero_traits to point to the correct Level traits
  WITH level_traits AS (
    SELECT 
      t1.id as keep_id,
      t2.id as remove_id
    FROM traits t1
    JOIN traits t2 ON t1.value = t2.value
    WHERE t1.category = 'Level'
    AND t2.category = 'Season 1 Level'
  )
  UPDATE hero_traits ht
  SET trait_id = lt.keep_id
  FROM level_traits lt
  WHERE ht.trait_id = lt.remove_id;

  -- Delete the old Season 1 Level traits
  DELETE FROM traits
  WHERE category = 'Season 1 Level';

  -- Update trait counts based on actual associations
  WITH trait_counts AS (
    SELECT 
      trait_id,
      COUNT(*) as actual_count
    FROM hero_traits
    GROUP BY trait_id
  )
  UPDATE traits t
  SET count = COALESCE(tc.actual_count, 0)
  FROM trait_counts tc
  WHERE t.id = tc.trait_id;

  -- Update trait rarities based on total heroes
  IF total_heroes > 0 THEN
    UPDATE traits
    SET rarity = (count::decimal / total_heroes) * 100
    WHERE count > 0;
  END IF;

  -- Clean up any orphaned traits
  DELETE FROM traits t
  WHERE NOT EXISTS (
    SELECT 1 
    FROM hero_traits ht 
    WHERE ht.trait_id = t.id
  );

  -- Recalculate rarity scores and ranks
  PERFORM update_rarity_ranks();
END $$;