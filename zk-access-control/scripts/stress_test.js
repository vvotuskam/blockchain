const hre = require("hardhat");
const snarkjs = require("snarkjs");
const { buildPoseidon } = require("circomlibjs");
const { performance } = require("perf_hooks");
const fs = require("fs");

async function main() {
    // --- CONFIGURATION ---
    const TOTAL_TX = 1000;
    const TARGET_TPS = 55; // Change this to 10, 20, 50, etc.
    const INTER_TX_DELAY = 1000 / TARGET_TPS;

    const [sender] = await hre.ethers.getSigners();
    const poseidon = await buildPoseidon();

    console.log(`\n--- TPS-TARGETED STRESS TEST ---`);
    console.log(`Target: ${TOTAL_TX} TXs | Rate: ${TARGET_TPS} TPS | Interval: ${INTER_TX_DELAY.toFixed(2)}ms`);

    // 1. ZKP ARTIFACTS
    const hashResult = poseidon([1, 12345]);
    const publicCommitment = poseidon.F.toObject(hashResult).toString();
    const wasmPath = "circuit_js/circuit.wasm";
    const zkeyPath = "circuit_final.zkey";

    // 2. PRE-GENERATION
    console.log("Pre-generating ZK Proof...");
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        { roleId: 1, secretKey: 12345, publicCommitment }, wasmPath, zkeyPath
    );
    const callData = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
    const p = JSON.parse("[" + callData + "]");

    // 3. DEPLOYMENT & SYNC
    const Verifier = await hre.ethers.getContractFactory("Groth16Verifier");
    const verifier = await Verifier.deploy();
    await verifier.deploymentTransaction().wait(2);

    const AccessManager = await hre.ethers.getContractFactory("AccessManager");
    const accessManager = await AccessManager.deploy(await verifier.getAddress());
    await accessManager.deploymentTransaction().wait(2);
    await (await accessManager.updateCommitment(publicCommitment)).wait(2);
    console.log("Contract State Synchronized across Consortium.");

    // 4. THE THROTTLED FLOOD
    let currentNonce = await sender.getNonce("pending");
    const txPromises = [];
    const startTime = performance.now();

    console.log(`Pacing emission at ${TARGET_TPS} TPS...`);

    for (let i = 0; i < TOTAL_TX; i++) {
        const loopStart = performance.now();

        // Fire and Forget (Async Sending)
        const txPromise = accessManager.requestAccess(
            p[0], p[1], p[2], p[3],
            `TPS_STRESS_${i}`,
            {
                nonce: currentNonce++,
                gasPrice: 1000000000n, // 1 Gwei (Ethers v6 BigInt)
                gasLimit: 800000n
            }
        ).then(tx => tx.wait()); // Store the promise of mining

        txPromises.push(txPromise);

        // Throttle Logic: Wait for the remainder of the interval
        const elapsed = performance.now() - loopStart;
        if (elapsed < INTER_TX_DELAY) {
            await new Promise(resolve => setTimeout(resolve, INTER_TX_DELAY - elapsed));
        }

        if (i > 0 && i % 100 === 0) {
            console.log(`Emitted: ${i}/${TOTAL_TX} transactions...`);
        }
    }

    const emissionEndTime = performance.now();
    console.log("All transactions emitted. Waiting for final mining block...");

    // 5. COLLECT RESULTS
    const receipts = await Promise.all(txPromises);
    const totalEndTime = performance.now();

    // 6. METRICS CALCULATION
    const emissionDuration = (emissionEndTime - startTime) / 1000;
    const miningDuration = (totalEndTime - startTime) / 1000;

    // Block Density Calculation
    const blocks = {};
    receipts.forEach(r => {
        blocks[r.blockNumber] = (blocks[r.blockNumber] || 0) + 1;
    });
    const maxBlockDensity = Math.max(...Object.values(blocks));

    console.log("\n==========================================");
    console.log("       TPS PERFORMANCE REPORT             ");
    console.log("==========================================");
    console.log(`Planned Emission Rate: ${TARGET_TPS} TPS`);
    console.log(`Actual Emission Rate:  ${(TOTAL_TX / emissionDuration).toFixed(2)} TPS`);
    console.log(`Consensus Throughput:  ${(TOTAL_TX / miningDuration).toFixed(2)} TPS`);
    console.log(`Total Mining Time:     ${miningDuration.toFixed(2)}s`);
    console.log(`Max ZKPs Per Block:    ${maxBlockDensity}`);
    console.log(`Success Rate:          ${receipts.filter(r => r.status === 1).length}/${TOTAL_TX}`);
    console.log("==========================================\n");
}

main().catch(console.error);