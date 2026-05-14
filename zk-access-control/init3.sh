#!/bin/bash
set -e

echo "1. Installing circomlibjs..."
npm install circomlibjs

echo "2. Populating scripts/execute.js..."
cat << 'EOF' > scripts/execute.js
const hre = require("hardhat");
const snarkjs = require("snarkjs");
const { buildPoseidon } = require("circomlibjs");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("--- Step A: Local Crypto (Poseidon) ---");
    const poseidon = await buildPoseidon();

    // Dummy employee data
    const roleId = 1;
    const secretKey = 12345;

    // Hash using Poseidon
    const hashResult = poseidon([roleId, secretKey]);
    // Convert out of Montgomery form and to string for BigInt safety
    const publicCommitment = poseidon.F.toObject(hashResult).toString();
    console.log("Generated Public Commitment:", publicCommitment);

    console.log("\n--- Step B: Generate Proof ---");
    // Handle circom default output directory for WASM
    const wasmPath = fs.existsSync("circuit_js/circuit.wasm")
        ? "circuit_js/circuit.wasm"
        : "circuit.wasm";

    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        { roleId: roleId, secretKey: secretKey, publicCommitment: publicCommitment },
        wasmPath,
        "circuit_final.zkey"
    );
    console.log("zk-SNARK Proof generated successfully.");

    console.log("\n--- Step C: Format Proof for Solidity ---");
    const callData = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
    // Parse the string into usable arrays for ethers.js
    const parsedCallData = JSON.parse("[" + callData + "]");
    const a = parsedCallData[0];
    const b = parsedCallData[1];
    const c = parsedCallData[2];
    const Input = parsedCallData[3];

    console.log("\n--- Step D: Deploy Contracts ---");
    const Verifier = await hre.ethers.getContractFactory("Groth16Verifier");
    const verifier = await Verifier.deploy();
    await verifier.waitForDeployment();
    const verifierAddress = await verifier.getAddress();
    console.log("Groth16Verifier deployed to:", verifierAddress);

    const AccessManager = await hre.ethers.getContractFactory("AccessManager");
    const accessManager = await AccessManager.deploy(verifierAddress);
    await accessManager.waitForDeployment();
    const accessManagerAddress = await accessManager.getAddress();
    console.log("AccessManager deployed to:", accessManagerAddress);

    console.log("\nSetting Valid Corporate Commitment on-chain...");
    let tx = await accessManager.updateCommitment(publicCommitment);
    await tx.wait();
    console.log("Commitment updated.");

    console.log("\n--- Step E: Execute Request Access ---");
    console.log("Submitting proof to Smart Contract...");
    tx = await accessManager.requestAccess(a, b, c, Input, "QmTestCID123");
    const receipt = await tx.wait();

    console.log("\nTransaction Successful!");
    console.log("Gas used:", receipt.gasUsed.toString());

    // Catch and display the event
    for (const log of receipt.logs) {
        try {
            const parsedLog = accessManager.interface.parseLog(log);
            if (parsedLog && parsedLog.name === "AccessGranted") {
                console.log("\n[Event Emitted] AccessGranted");
                console.log("User:", parsedLog.args.user);
                console.log("CID:", parsedLog.args.cid);
            }
        } catch (e) {
            // Log might belong to another contract or not be parseable, ignore
        }
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
EOF

echo "3. Running E2E Execution Script..."
npx hardhat run scripts/execute.js