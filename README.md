# OnChain Heroes Rarity Tool

A web application to discover and analyze the rarity of OnChain Heroes NFT traits. Built with React, TypeScript, and Supabase.

![OnChain Heroes Rarity Tool]()

## Features

- 🎮 Check individual hero rarity scores and ranks
- 🔍 Search and filter traits by category
- 📊 View trait distribution and rarity percentages
- 📱 Fully responsive design
- 🎨 Beautiful UI with pixel art theme

## Tech Stack

- **Frontend**: React, TypeScript, Vite
- **Styling**: Tailwind CSS
- **Database**: Supabase
- **Icons**: Lucide React
- **Fonts**: Press Start 2P (Google Fonts)

## Rarity Calculation

The rarity score is calculated using a statistical approach:

1. **Individual Trait Rarity**:
   ```
   trait rarity = (number of heroes with trait ÷ total heroes) × 100
   ```

2. **Overall Hero Rarity**:
   - Multiply all trait rarities together
   - Take the geometric mean (nth root where n is the number of traits)
   - Lower scores indicate rarer heroes

## Disclaimer

This tool is not affiliated with OnChain Heroes. Data accuracy is not guaranteed.

## Author

Built by [DanielHigh](https://x.com/dhigh_eth)