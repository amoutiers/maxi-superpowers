// Minimal billing module for the brownfield fixture.
export function createInvoice(customerId, lineItems) {
  return { customerId, lineItems, total: lineItems.reduce((s, i) => s + i.amount, 0) };
}

export function markPaid(invoice) {
  return { ...invoice, paid: true };
}
