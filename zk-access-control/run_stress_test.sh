#!/bin/bash

echo "Cleaning environment..."
rm -f stress_results.txt

echo "Step 4: Starting Stress Test..."
npx hardhat run scripts/stress_test.js --network besu | tee stress_results.txt

echo "Experiment Complete. Data stored in stress_results.txt"