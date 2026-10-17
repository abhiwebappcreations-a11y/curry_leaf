/**
 * Utility functions for handling monetary calculations strictly in INTEGER PAISE.
 * 1 INR = 100 paise.
 * Never use floating-point numbers for financial storage.
 */

export function paiseToRupees(paise: number): number {
  return paise / 100;
}

export function rupeesToPaise(rupees: number): number {
  return Math.round(rupees * 100);
}

export function formatPaise(paise: number): string {
  const rupees = paise / 100;
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(rupees);
}

export function calculateTaxPaise(subtotalPaise: number, taxRatePercent: number): number {
  // Round to nearest integer paise
  return Math.round((subtotalPaise * taxRatePercent) / 100);
}

export function calculateDiscountPaise(subtotalPaise: number, discountPercent: number): number {
  return Math.round((subtotalPaise * discountPercent) / 100);
}
