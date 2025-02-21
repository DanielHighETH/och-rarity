/*
  # Add trait columns to heroes table
  
  1. Changes
    - Add columns for each trait type to heroes table
    - Update upload script to store traits directly
  
  2. Benefits
    - Faster direct access to hero traits
    - Maintains existing normalized structure for calculations
*/

ALTER TABLE heroes
ADD COLUMN traits jsonb DEFAULT '{}'::jsonb,
ADD COLUMN attributes jsonb DEFAULT '[]'::jsonb;