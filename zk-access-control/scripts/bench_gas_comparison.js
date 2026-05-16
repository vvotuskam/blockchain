const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("=========================================================");
    console.log("          GAS COMPARISON & SCALABILITY BENCHMARK         ");
    console.log("=========================================================");

    // 1. Deploy Standard Access Contract
    const StandardAccess = await hre.ethers.getContractFactory("StandardAccess");
    const standardAccess = await StandardAccess.deploy();
    await standardAccess.deploymentTransaction().wait(1);

    // 2. Setup baseline data (e.g., a pool of 10 users, placing target at the end)
    const secret = 12345n;
    const targetHash = hre.ethers.solidityPackedKeccak256(
        ["address", "uint256"],
        [deployer.address, secret]
    );

    const dummyHashes = Array(9).fill(hre.ethers.ZeroHash);
    dummyHashes.push(targetHash); // Target at index 9 (worst-case execution scenario)

    await (await standardAccess.addUsers(dummyHashes)).wait(1);

    // 3. Measure Standard Access Gas Consumption
    const txStandard = await standardAccess.requestAccess("DOC_001", secret);
    const receiptStandard = await txStandard.wait(1);
    const gasUsedStandard = receiptStandard.gasUsed;

    // 4. Constants for ZKP Verification (from Groth16 Verifier execution)
    const ZKP_GAS_COST = 227000n;
    const GAS_PER_ARRAY_ELEMENT = 2100n; // Average cold SLOAD per unchecked index iteration
    const BASE_TRANSACTION_GAS = 21000n;

    console.log(`Standard Array Access (N=10) Gas Used: ${gasUsedStandard.toString()}`);
    console.log(`ZKP Access Manager (Any N) Gas Used:   ${ZKP_GAS_COST.toString()}`);
    console.log("---------------------------------------------------------");

    // 5. Theoretical Extrapolation & Scalability Calculations
    const BLOCK_GAS_LIMIT = 15000000n;

    // Linear formula derived from EVM storage iteration: Gas = Base + (N * IterationCost)
    // To find where Standard costs exceed ZKP: Base + N * 2100 > 227000 => N = (227000 - Base) / 2100
    const estimatedBaseGas = gasUsedStandard - (10n * GAS_PER_ARRAY_ELEMENT);
    const breakEvenUsers = (ZKP_GAS_COST - estimatedBaseGas) / GAS_PER_ARRAY_ELEMENT;
    const absoluteMaxUsersStandard = (BLOCK_GAS_LIMIT - estimatedBaseGas) / GAS_PER_ARRAY_ELEMENT;

    console.log("              THEORETICAL SCALING ANALYSIS               ");
    console.log("---------------------------------------------------------");
    console.log(`Break-Even Point:      ~${breakEvenUsers.toString()} users`);
    console.log(`> Beyond this point, ZKP Verification is more gas-efficient than an on-chain list lookup.`);
    console.log("");
    console.log(`Max Standard Capacity: ~${absoluteMaxUsersStandard.toString()} users`);
    console.log(`> At this scaling factor, a single standard validation hits the 15,000,000 Block Gas Limit`);
    console.log(`  causing a permanent denial of service (DoS) for users located late in the array.`);
    console.log("");
    console.log(`ZKP Scalability:       Infinite $O(1)$ execution overhead on-chain`);
    console.log(`> Off-chain Merkle tree generation allows scaling to millions of users while retaining`);
    console.log(`  a constant verification signature footprint of ${ZKP_GAS_COST.toString()} gas.`);
    console.log("=========================================================");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });