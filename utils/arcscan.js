export const ARCSCAN_BASE_URL = 'https://testnet.arcscan.io';

export const showArcscanToast = (txHash) => {
  const url = `${ARCSCAN_BASE_URL}/tx/${txHash}`;
  console.log(`Transaction submitted: ${url}`);
};
