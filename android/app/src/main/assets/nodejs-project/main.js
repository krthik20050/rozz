const { on, send } = require('flutter-bridge');

console.log('ROZZ Node.js Engine: Started');

on('ping', (data) => {
    send('pong', { status: 'alive' });
});

on('parse_sms', (smsData) => {
    const { body, sender } = smsData;
    
    // Enhanced Regex for HDFC Bank
    const patterns = {
        // Rs. 500.00 or Rs 500
        amount: /(?:rs|inr)\.?\s?([\d,]+\.?\d*)/i,
        // Debited, spent, withdrawn, sent, paid
        direction: /(?:debited|spent|withdrawn|sent|paid|transfer to)/i,
        // To VPA, To [Name], At [Merchant]
        recipient: /(?:to|at|vpa)\s?([^.]+?)(?=\s?on\s?|\s?ref\s?|\s?link\s?|\s?is\s?|$)/i,
        // Bal is Rs. 1000, Balance Rs 1000
        balance: /(?:bal|balance|avbl\sbal)\.?\s?(?:is\s?)?(?:rs|inr)\.?\s?([\d,]+\.?\d*)/i,
        // Ref No. 123456789
        upiRef: /(?:ref|rrn)\s?(?:no\.?)?\s?(\d{10,12})/i
    };

    try {
        const amountMatch = body.match(patterns.amount);
        const directionMatch = body.match(patterns.direction);
        const recipientMatch = body.match(patterns.recipient);
        const balanceMatch = body.match(patterns.balance);
        const upiMatch = body.match(patterns.upiRef);

        if (amountMatch) {
            const result = {
                amount: parseFloat(amountMatch[1].replace(/,/g, '')),
                direction: directionMatch ? 'expense' : 'income',
                recipient: recipientMatch ? recipientMatch[1].trim() : 'Unknown',
                balanceAfter: balanceMatch ? parseFloat(balanceMatch[1].replace(/,/g, '')) : null,
                upiRef: upiMatch ? upiMatch[1] : null,
                rawSms: body,
                timestamp: new Date().toISOString()
            };
            send('sms_parsed', result);
        }
    } catch (e) {
        console.error('Parsing failed:', e);
    }
});
