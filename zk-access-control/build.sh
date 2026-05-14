#!/bin/bash
set -e

echo "1. Compiling the circuit..."
./circom.exe circuit.circom --r1cs --wasm --sym

echo "2. Generating Local Powers of Tau (Phase 1 Trusted Setup)..."
# Create a new powers of tau ceremony for 2^12 constraints (plenty for our circuit)
npx snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
# Contribute entropy (randomness) to the ceremony
npx snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v -e="some_random_entropy_for_thesis"
# Prepare the file for Phase 2
npx snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v

echo "3. Running Groth16 setup (Phase 2)..."
npx snarkjs groth16 setup circuit.r1cs pot12_final.ptau circuit_0000.zkey

echo "4. Contributing to phase 2 entropy..."
npx snarkjs zkey contribute circuit_0000.zkey circuit_final.zkey --name="Phase2 Contribution" -v -e="dummy_entropy_string_for_testing_987654321"

echo "5. Exporting verification key..."
npx snarkjs zkey export verificationkey circuit_final.zkey verification_key.json

echo "6. Generating Solidity verifier..."
npx snarkjs zkey export solidityverifier circuit_final.zkey Verifier.sol

echo "Build complete! Verifier.sol has been generated."