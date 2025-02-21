/*
  # Fix rarity calculation and trait syncing

  1. Changes
    - Ensure attributes column is JSONB
    - Fix rarity calculation function to handle all cases
    - Add function to sync hero traits from attributes
    - Add function to update trait counts and rarities
*/

-- Ensure attributes is JSONB
ALTER TABLE heroes
ALTER COLUMN attributes TYPE jsonb USING attributes::jsonb;

-- Create function to sync hero traits from attributes
CREATE OR REPLACE FUNCTION sync_hero_traits(p_hero_id integer)
RETURNS void AS $$
DECLARE
  attr jsonb;
  trait_type text;
  trait_value text;
  trait_id uuid;
  attr_record record;
BEGIN
  -- Get hero attributes
  SELECT attributes INTO attr
  FROM heroes
  WHERE id = p_hero_id;

  -- Delete existing trait associations
  DELETE FROM hero_traits WHERE hero_id = p_hero_id;

  -- Process each attribute
  FOR attr_record IN
    SELECT 
      CASE 
        WHEN value->>'trait_type' = 'Season 1 Level' THEN 'Level'
        WHEN value->>'trait_type' = 'Name' THEN '1/1'
        ELSE value->>'trait_type'
      END as trait_type,
      value->>'value' as trait_value
    FROM jsonb_array_elements(attr)
  LOOP
    -- Get or create trait
    WITH trait_insert AS (
      INSERT INTO traits (category, value, count, rarity)
      VALUES (
        attr_record.trait_type,
        attr_record.trait_value,
        1,
        0.01  -- Initial rarity, will be updated
      )
      ON CONFLICT (category, value) DO UPDATE
      SET count = traits.count
      RETURNING id
    )
    SELECT id INTO trait_id FROM trait_insert;

    -- Link trait to hero
    INSERT INTO hero_traits (hero_id, trait_id)
    VALUES (p_hero_id, trait_id)
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create function to update trait counts
CREATE OR REPLACE FUNCTION update_trait_counts()
RETURNS void AS $$
DECLARE
  total_heroes integer;
BEGIN
  -- Get total number of heroes
  SELECT COUNT(*) INTO total_heroes FROM heroes;

  -- Update trait counts and rarities
  UPDATE traits t
  SET 
    count = subquery.trait_count,
    rarity = (subquery.trait_count::decimal / total_heroes) * 100
  FROM (
    SELECT trait_id, COUNT(*) as trait_count
    FROM hero_traits
    GROUP BY trait_id
  ) subquery
  WHERE t.id = subquery.trait_id;
END;
$$ LANGUAGE plpgsql;

-- Improve rarity calculation function
CREATE OR REPLACE FUNCTION calculate_hero_rarity(p_hero_id integer)
RETURNS decimal AS $$
DECLARE
  rarity_score decimal;
  trait_count integer;
BEGIN
  -- Get number of traits for this hero
  SELECT COUNT(*) INTO trait_count
  FROM hero_traits
  WHERE hero_id = p_hero_id;

  -- If no traits, return NULL
  IF trait_count = 0 THEN
    RETURN NULL;
  END IF;

  -- Calculate rarity score
  WITH trait_rarities AS (
    SELECT t.rarity
    FROM hero_traits ht
    JOIN traits t ON t.id = ht.trait_id
    WHERE ht.hero_id = p_hero_id
  )
  SELECT 
    POWER(EXP(SUM(LN(NULLIF(rarity, 0)))), 1.0 / COUNT(*))
  INTO rarity_score
  FROM trait_rarities;
  
  RETURN rarity_score;
END;
$$ LANGUAGE plpgsql;

-- Improve rank update function
CREATE OR REPLACE FUNCTION update_rarity_ranks()
RETURNS void AS $$
DECLARE
  hero_record record;
BEGIN
  -- First sync all hero traits
  FOR hero_record IN SELECT id FROM heroes
  LOOP
    PERFORM sync_hero_traits(hero_record.id);
  END LOOP;

  -- Update trait counts and rarities
  PERFORM update_trait_counts();

  -- Update rarity scores for all heroes
  UPDATE heroes h
  SET rarity_score = calculate_hero_rarity(h.id);

  -- Update rarity ranks based on rarity scores
  WITH ranked_heroes AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY rarity_score ASC NULLS LAST) as new_rank
    FROM heroes
  )
  UPDATE heroes h
  SET rarity_rank = rh.new_rank
  FROM ranked_heroes rh
  WHERE h.id = rh.id;
END;
$$ LANGUAGE plpgsql;