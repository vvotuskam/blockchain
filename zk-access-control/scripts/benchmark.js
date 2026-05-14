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
