/*
  # Add insert policies for data upload

  1. Changes
    - Add policies to allow inserting data into tables
    - Add policies to allow updating data in tables
  
  2. Security
    - Policies allow authenticated users to insert and update data
    - Maintains existing read-only access for public users
*/

-- Add insert and update policies for heroes table
CREATE POLICY "Allow authenticated users to insert heroes"
  ON heroes FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update heroes"
  ON heroes FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- Add insert and update policies for traits table
CREATE POLICY "Allow authenticated users to insert traits"
  ON traits FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update traits"
  ON traits FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- Add insert and update policies for hero_traits table
CREATE POLICY "Allow authenticated users to insert hero_traits"
  ON hero_traits FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update hero_traits"
  ON hero_traits FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);