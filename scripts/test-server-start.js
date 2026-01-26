// Minimal test to debug server startup issue
console.log('1. Loading environment...');
require('dotenv').config();

console.log('2. Loading express...');
const express = require('express');

console.log('3. Creating app...');
const app = express();

console.log('4. Setting up listener...');
const server = app.listen(3000, '0.0.0.0', () => {
    console.log('✅ Server is listening on port 3000');
});

console.log('5. Adding test route...');
app.get('/test', (req, res) => {
    res.json({ message: 'Server is working!' });
});

console.log('6. Setup complete. Server should be running...');

// Keep alive
setTimeout(() => {
    console.log('Server still alive after 5 seconds');
}, 5000);

// Catch errors
process.on('uncaughtException', (err) => {
    console.error('❌ Uncaught exception:', err);
    process.exit(1);
});

process.on('unhandledRejection', (err) => {
    console.error('❌ Unhandled rejection:', err);
});
