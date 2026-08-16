import React from 'react';

export default function DebtTracker({ totalBorrowed = 1000, totalRepaid = 350 }) {
  const remainingDebt = Math.max(0, totalBorrowed - totalRepaid);
  const progressPercent = totalBorrowed > 0 ? Math.min(100, ((totalRepaid / totalBorrowed) * 100)).toFixed(1) : 0;

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 space-y-4">
      <h3 className="text-base font-medium text-white">Streaming Repayment Tracker</h3>
      
      <div className="w-full bg-gray-700 rounded-full h-3 overflow-hidden">
        <div 
          className="bg-green-500 h-3 rounded-full transition-all duration-500" 
          style={{ width: `${progressPercent}%` }}
        />
      </div>

      <div className="grid grid-cols-2 gap-4 pt-2">
        <div className="bg-gray-800 p-3 rounded-lg border border-gray-700/50">
          <p className="text-xs text-gray-400">Total Repaid</p>
          <p className="text-lg font-bold text-green-400">${totalRepaid} USDC</p>
        </div>
        <div className="bg-gray-800 p-3 rounded-lg border border-gray-700/50">
          <p className="text-xs text-gray-400">Remaining Debt</p>
          <p className="text-lg font-bold text-amber-400">${remainingDebt} USDC</p>
        </div>
      </div>
    </div>
  );
}
