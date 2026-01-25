# Dummy Payment System

This app now uses a local dummy payment system instead of external payment gateways like Razorpay to avoid timeout issues.

## How it works

1. **Local Database Storage**: All payment data is stored locally using SQLite
2. **Card Validation**: Basic card validation is performed (format, expiry date, CVV)
3. **Simulated Processing**: Payment processing is simulated with a 2-second delay
4. **Wallet Management**: Wallet balance is maintained locally

## Test Card Details

You can use any valid card format for testing:

### Valid Test Cards:
- **Card Number**: 4111 1111 1111 1111 (or any 13-19 digit number)
- **Expiry Date**: Any future date (MM/YY format, e.g., 12/25, 03/26)
- **CVV**: Any 3-4 digits (e.g., 123, 456, 789)
- **Name**: Any name

### Card Validation Rules:
- Card number must be 13-19 digits
- Expiry date must be in MM/YY format and in the future
- CVV must be 3-4 digits
- Cardholder name is required

## Features

1. **Add Money to Wallet**: Use the payment form to add ₹500 to your wallet
2. **Transaction History**: View all payment transactions locally
3. **Wallet Balance**: Real-time wallet balance updates
4. **Offline Operation**: No internet required for payments

## Database Tables

### payments
- Stores all payment transactions
- Includes card details (masked), amounts, and transaction IDs

### wallet_balance
- Maintains current wallet balance per driver
- Updates automatically with successful payments

## Usage

1. Go to Wallet screen
2. Click "Add Money" button
3. Fill in the payment form with valid card details
4. Click "Pay ₹500"
5. Payment will be processed locally and wallet updated

The system will show success/error messages and update the transaction history immediately.