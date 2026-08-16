import React from 'react';

const STEPS = [
  { id: 1, label: 'Connect & KYC' },
  { id: 2, label: 'Deposit Collateral' },
  { id: 3, label: 'Borrow USDC' },
  { id: 4, label: 'Repay & Stream' }
];

export default function VaultStepper({ currentStep = 2 }) {
  return (
    <div className="w-full py-4 mb-6">
      <div className="flex justify-between items-center max-w-xl mx-auto">
        {STEPS.map((step) => (
          <div key={step.id} className="flex flex-col items-center flex-1">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm ${
              currentStep >= step.id ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-400'
            }`}>
              {step.id}
            </div>
            <span className="text-xs mt-2 text-center text-gray-300 font-medium">
              {step.label}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
