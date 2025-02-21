/*
  # Fix rarity calculation functions

  1. Changes
    - Fix ambiguous column references in calculate_hero_rarity function
    - Improve rarity calculation performance
    - Add proper table aliases
  
  2. Functions Updated
    - calculate_hero_rarity
    - update_rarity_ranks
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS calculate_hero_rarity(integer);
DROP FUNCTION IF EXISTS update_rarity_ranks();

-- Recreate calculate_hero_rarity function with fixed column references
CREATE OR REPLACE FUNCTION calculate_hero_rarity(p_hero_id integer)
RETURNS decimal AS $$
DECLARE
  rarity_score decimal;
BEGIN
  WITH trait_rarities AS (
    SELECT t.rarity
    FROM hero_traits ht
    JOIN traits t ON t.id = ht.trait_id
    WHERE ht.hero_id = p_hero_id
  )
  SELECT 
    POWER(EXP(SUM(LN(rarity))), 1.0 / COUNT(*))
  INTO rarity_score
  FROM trait_rarities;
  
  RETURN rarity_score;
END;
$$ LANGUAGE plpgsql;

-- Recreate update_rarity_ranks function with proper table aliases
CREATE OR REPLACE FUNCTION update_rarity_ranks()
RETURNS void AS $$
BEGIN
  -- Update rarity scores for all heroes
  UPDATE heroes h
  SET rarity_score = calculate_hero_rarity(h.id)
  WHERE EXISTS (
    SELECT 1 
    FROM hero_traits ht 
    WHERE ht.hero_id = h.id
  );

  -- Update rarity ranks based on rarity scores
  WITH ranked_heroes AS (
    SELECT 
      h.id,
      ROW_NUMBER() OVER (ORDER BY h.rarity_score ASC) as new_rank
    FROM heroes h
    WHERE h.rarity_score IS NOT NULL
  )
  UPDATE heroes h
  SET rarity_rank = rh.new_rank
  FROM ranked_heroes rh
  WHERE h.id = rh.id;
END;
$$ LANGUAGE plpgsql;