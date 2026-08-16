import React from 'react';

export default function BorrowPreview({ collateralAmount = 0, collateralPrice = 1, requestedBorrow = 0, maxLTV = 75 }) {
  const collateralValue = collateralAmount * collateralPrice;
  const maxBorrowable = (collateralValue * maxLTV) / 100;
  const currentLTV = collateralValue > 0 ? ((requestedBorrow / collateralValue) * 100).toFixed(1) : 0;

  return (
    <div className="bg-gray-800/80 border border-gray-700 rounded-xl p-4 my-4 space-y-3 text-sm">
      <div className="flex justify-between text-gray-300">
        <span>Collateral Value:</span>
        <span className="font-semibold text-white">${collateralValue.toLocaleString()}</span>
      </div>
      <div className="flex justify-between text-gray-300">
        <span>Max Borrow Limit ({maxLTV}% LTV):</span>
        <span className="font-semibold text-green-400">${maxBorrowable.toLocaleString()} USDC</span>
      </div>
      <div className="flex justify-between text-gray-300">
        <span>Estimated LTV:</span>
        <span className={`font-semibold ${currentLTV > maxLTV ? 'text-red-400' : 'text-blue-400'}`}>
          {currentLTV}%
        </span>
      </div>
    </div>
  );
}
