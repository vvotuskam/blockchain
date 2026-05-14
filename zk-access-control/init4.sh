#!/bin/bash
set -e

# 1. Populate docker-compose.yml
echo "Generating docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
services:
  besu:
    image: hyperledger/besu:latest
    container_name: besu-node
    ports:
      - "8545:8545"
    command:
      - --network=dev
      - --rpc-http-enabled
      - --rpc-http-api=ETH,NET,WEB3
      - --rpc-http-cors-origins=["*"]
      - --host-allowlist=["*"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8545"]
      interval: 5s
      timeout: 5s
      retries: 10

  ipfs:
    image: ipfs/kubo:latest
    container_name: ipfs-node
    ports:
      - "5001:5001"
      - "8080:8080"
EOF

# 2. Update hardhat.config.js
echo "Updating hardhat.config.js for Besu..."
cat << 'EOF' > hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    besu: {
      url: "http://127.0.0.1:8545",
      // Standard Besu Dev Account Private Key
      accounts: ["0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63"]
    }
  }
};
EOF

# 3. Populate scripts/benchmark.js
echo "Generating scripts/benchmark.js..."
cat << 'EOF' > scripts/benchmark.js
const hre = require("hardhat");
const snarkjs = require("snarkjs");
const { buildPoseidon } = require("circomlibjs");
const { performance } = require("perf_hooks");
const fs = require("fs");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("--- Benchmarking Environment: Hyperledger Besu ---");
    console.log("Using Account:", deployer.address);

    // 1. Setup Data & Crypto
    const poseidon = await buildPoseidon();
    const roleId = 1;
    const secretKey = 12345;
    const hashResult = poseidon([roleId, secretKey]);
    const publicCommitment = poseidon.F.toObject(hashResult).toString();

    // 2. Generate Proof
    const wasmPath = fs.existsSync("circuit_js/circuit.wasm") ? "circuit_js/circuit.wasm" : "circuit.wasm";
    const startTimeProof = performance.now();
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        { roleId: roleId, secretKey: secretKey, publicCommitment: publicCommitment },
        wasmPath,
        "circuit_final.zkey"
    );
    const endTimeProof = performance.now();

    const callData = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
    const parsedCallData = JSON.parse("[" + callData + "]");

    // 3. Deploy
    const Verifier = await hre.ethers.getContractFactory("Groth16Verifier");
    const verifier = await Verifier.deploy();
    await verifier.waitForDeployment();
    const AccessManager = await hre.ethers.getContractFactory("AccessManager");
    const accessManager = await AccessManager.deploy(await verifier.getAddress());
    await accessManager.waitForDeployment();

    await (await accessManager.updateCommitment(publicCommitment)).wait();

    // 4. The Benchmark
    console.log("\nStarting On-chain Verification Benchmark...");

    const startTimeOnChain = performance.now();
    const tx = await accessManager.requestAccess(
        parsedCallData[0],
        parsedCallData[1],
        parsedCallData[2],
        parsedCallData[3],
        "QmBenchmarkCID123"
    );
    const receipt = await tx.wait();
    const endTimeOnChain = performance.now();

    // 5. Results
    console.log("\n==========================================");
    console.log("ACADEMIC BENCHMARK RESULTS");
    console.log("==========================================");
    console.log(`Local Proof Generation:    ${(endTimeProof - startTimeProof).toFixed(2)} ms`);
    console.log(`On-chain TX Latency:       ${(endTimeOnChain - startTimeOnChain).toFixed(2)} ms`);
    console.log(`Gas Used by Verifier:      ${receipt.gasUsed.toString()}`);
    console.log(`EVM Status:                Success`);
    console.log("==========================================");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
EOF

echo "Module 4 Initialization Complete."
echo "Step 1: Start environment with: docker-compose up -d"
echo "Step 2: Run benchmark with: npx hardhat run scripts/benchmark.js --network besu"