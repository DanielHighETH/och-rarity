import React from 'react';
import { Trait } from '../data/traits';

interface RarityCardProps {
  trait: Trait;
  category: string;
}

export const RarityCard: React.FC<RarityCardProps> = ({ trait, category }) => {
  const rarityPercentage = parseFloat(trait.rarity.replace('%', ''));
  const getRarityColor = (percentage: number) => {
    if (percentage <= 1) return 'bg-purple-100 border-purple-500 text-purple-700';
    if (percentage <= 5) return 'bg-blue-100 border-blue-500 text-blue-700';
    if (percentage <= 10) return 'bg-green-100 border-green-500 text-green-700';
    return 'bg-gray-100 border-gray-500 text-gray-700';
  };

  return (
    <div className={`p-4 rounded-lg border-2 ${getRarityColor(rarityPercentage)} transition-transform hover:scale-105`}>
      <h3 className="font-pixel text-lg mb-2">{trait.value}</h3>
      <div className="flex justify-between items-center">
        <span className="text-sm opacity-75">Count: {trait.count}</span>
        <span className="font-bold">{trait.rarity}</span>
      </div>
      <div className="mt-2 w-full bg-white/50 rounded-full h-2">
        <div 
          className="h-full rounded-full bg-current transition-all"
          style={{ width: trait.rarity }}
        />
      </div>
    </div>
  );
};