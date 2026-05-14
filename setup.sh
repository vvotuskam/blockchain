#!/bin/bash
set -e

# 1. Workspace Setup
echo "Initializing Workspace..."
mkdir -p zk-access-control
cd zk-access-control
npm init -y
npm install circomlib@2.0.5 snarkjs@0.7.0

# 2. Populate circuit.circom
echo "Generating circuit.circom..."
cat << 'EOF' > circuit.circom
pragma circom 2.1.6;

include "node_modules/circomlib/circuits/poseidon.circom";

template CorporateAccessVerifier() {
    // Private Inputs
    signal input roleId;
    signal input secretKey;

    // Public Input
    signal input publicCommitment;

    // Instantiate Poseidon hasher for 2 inputs
    component hasher = Poseidon(2);
    hasher.inputs[0] <== roleId;
    hasher.inputs[1] <== secretKey;

    // Constrain the hash output to exactly match the public commitment
    hasher.out === publicCommitment;
}

// Define the main component and explicitly declare the public input
component main {public [publicCommitment]} = CorporateAccessVerifier();
EOF

# 3. Populate build.sh
echo "Generating build.sh..."
cat << 'EOF' > build.sh
#!/bin/bash
set -e

echo "1. Compiling the circuit..."
circom circuit.circom --r1cs --wasm --sym

echo "2. Downloading Powers of Tau file..."
if [ ! -f powersOfTau28_hez_final_12.ptau ]; then
    wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_12.ptau
fi

echo "3. Running Groth16 setup..."
npx snarkjs groth16 setup circuit.r1cs powersOfTau28_hez_final_12.ptau circuit_0000.zkey

echo "4. Contributing to phase 2 entropy..."
npx snarkjs zkey contribute circuit_0000.zkey circuit_final.zkey --name="Phase2 Contribution" -v -e="dummy_entropy_string_for_testing_987654321"

echo "5. Exporting verification key..."
npx snarkjs zkey export verificationkey circuit_final.zkey verification_key.json

echo "6. Generating Solidity verifier..."
npx snarkjs zkey export solidityverifier circuit_final.zkey Verifier.sol

echo "Build complete! Verifier.sol has been generated."
EOF

# 4. Finalization
chmod +x build.sh
echo "Initialization complete! Navigate to the directory and run ./build.sh"