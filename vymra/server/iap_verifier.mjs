import { createServer } from 'node:http';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const port = Number(process.env.PORT || 8787);
const sharedSecret = process.env.APPLE_SHARED_SECRET || '';
const bearerToken = process.env.IAP_VERIFICATION_TOKEN || '';
const ledgerPath = process.env.IAP_LEDGER_PATH || './iap-ledger.json';

function loadLedger() {
  if (!existsSync(ledgerPath)) {
    return {};
  }

  try {
    return JSON.parse(readFileSync(ledgerPath, 'utf8'));
  } catch (_) {
    return {};
  }
}

function saveLedger(ledger) {
  writeFileSync(ledgerPath, JSON.stringify(ledger, null, 2));
}

async function verifyWithApple(receiptData) {
  const body = {
    'receipt-data': receiptData,
    password: sharedSecret || undefined,
    'exclude-old-transactions': false,
  };

  const productionResponse = await fetch('https://buy.itunes.apple.com/verifyReceipt', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const productionJson = await productionResponse.json();
  if (productionJson.status === 21007) {
    const sandboxResponse = await fetch('https://sandbox.itunes.apple.com/verifyReceipt', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const sandboxJson = await sandboxResponse.json();
    return { environment: 'Sandbox', payload: sandboxJson };
  }

  return { environment: 'Production', payload: productionJson };
}

function resolveTransaction(payload, transactionId, productId) {
  const receiptTransactions = payload?.receipt?.in_app || [];
  const latestTransactions = payload?.latest_receipt_info || [];
  const allTransactions = [...latestTransactions, ...receiptTransactions];

  return allTransactions.find((transaction) => {
    const matchesId = transactionId
      ? transaction.transaction_id === transactionId ||
        transaction.original_transaction_id === transactionId
      : true;
    const matchesProduct = productId
      ? transaction.product_id === productId
      : true;
    return matchesId && matchesProduct;
  });
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'Content-Type': 'application/json' });
  response.end(JSON.stringify(payload));
}

const server = createServer(async (request, response) => {
  if (request.method !== 'POST' || request.url !== '/verify') {
    sendJson(response, 404, { verified: false, message: 'Not found' });
    return;
  }

  if (bearerToken) {
    const auth = request.headers.authorization || '';
    if (auth !== `Bearer ${bearerToken}`) {
      sendJson(response, 401, { verified: false, message: 'Unauthorized' });
      return;
    }
  }

  const chunks = [];
  for await (const chunk of request) {
    chunks.push(chunk);
  }

  let data;
  try {
    data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch (_) {
    sendJson(response, 400, { verified: false, message: 'Invalid JSON body' });
    return;
  }

  const receiptData = data.serverVerificationData;
  const productId = data.productId;
  const transactionId = data.transactionId;
  const appAccountToken = data.appAccountToken || 'anonymous';

  if (!receiptData || !productId) {
    sendJson(response, 400, { verified: false, message: 'Missing receipt or productId' });
    return;
  }

  try {
    const { environment, payload } = await verifyWithApple(receiptData);
    if (payload.status !== 0) {
      sendJson(response, 422, {
        verified: false,
        message: `Apple verifyReceipt failed with status ${payload.status}`,
      });
      return;
    }

    const transaction = resolveTransaction(payload, transactionId, productId);
    if (!transaction) {
      sendJson(response, 422, {
        verified: false,
        message: 'Verified receipt did not contain the requested product transaction',
      });
      return;
    }

    const canonicalTransactionId = transaction.transaction_id;
    const deliveryKey = `${appAccountToken}:${canonicalTransactionId}`;
    const ledger = loadLedger();
    const alreadyDelivered = ledger[deliveryKey] === true;

    if (!alreadyDelivered) {
      ledger[deliveryKey] = true;
      saveLedger(ledger);
    }

    sendJson(response, 200, {
      verified: true,
      verificationStatus: 'verified',
      environment,
      productId: transaction.product_id,
      transactionId: canonicalTransactionId,
      originalTransactionId: transaction.original_transaction_id,
      purchaseDateMs: transaction.purchase_date_ms,
      shouldGrantCoins: !alreadyDelivered,
      alreadyDelivered,
      verifiedAt: new Date().toISOString(),
    });
  } catch (error) {
    sendJson(response, 500, {
      verified: false,
      message: error instanceof Error ? error.message : 'Verification service failure',
    });
  }
});

server.listen(port, () => {
  console.log(`IAP verifier listening on http://0.0.0.0:${port}/verify`);
});
