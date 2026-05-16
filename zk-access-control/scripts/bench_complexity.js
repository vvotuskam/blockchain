const snarkjs = require("snarkjs");
const { buildPoseidon } = require("circomlibjs");
const { performance } = require("perf_hooks");
const fs = require("fs");

async function main() {
    // The pre-compiled depths we are testing
    const depths = [5, 20, 50, 100, 200, 500, 1000];
    const poseidon = await buildPoseidon();
    const F = poseidon.F;

    console.log("\n=========================================================");
    console.log(" ZKP PROVING TIME VS CIRCUIT COMPLEXITY (MERKLE TREE) ");
    console.log("=========================================================");
    console.log(
        "Depth".padEnd(8) +
        "| Constraints".padEnd(15) +
        "| Proving Time (ms)".padEnd(20)
    );
    console.log("---------------------------------------------------------");

    for (const depth of depths) {
        // Assumed naming convention for your pre-compiled artifacts
        const wasmPath = `circuit_js/merkle_${depth}.wasm`;
        const zkeyPath = `merkle_${depth}.zkey`;
        const r1csPath = `merkle_${depth}.r1cs`; // Used to dynamically fetch constraints

        // 1. Generate Valid Dummy Data
        const leaf = 12345;
        const pathElements = Array(depth).fill(0); // Dummy sibling nodes
        const pathIndices = Array(depth).fill(0);  // Assume left-side path

        // Calculate the exact expected root so the circuit constraints succeed
        let currentHash = F.e(leaf);
        for (let i = 0; i < depth; i++) {
            currentHash = poseidon([currentHash, F.e(pathElements[i])]);
        }
        const root = F.toObject(currentHash).toString();

        const input = {
            leaf: leaf,
            pathElements: pathElements,
            pathIndices: pathIndices,
            root: root
        };

        // 2. Retrieve the exact R1CS Constraint Count
        let constraints = "Unknown";
        if (fs.existsSync(r1csPath)) {
            const info = await snarkjs.r1cs.info(r1csPath);
            constraints = info.constraints;
        } else {
            // Fallback estimation: Poseidon(2) takes ~240 constraints per level
            constraints = `~${depth * 240}`;
        }

        // 3. Benchmark Prover Execution
        try {
            // Warm-up the memory/V8 engine (optional, but good for academic accuracy)
            // await snarkjs.groth16.fullProve(input, wasmPath, zkeyPath);

            const start = performance.now();
            await snarkjs.groth16.fullProve(input, wasmPath, zkeyPath);
            const end = performance.now();

            const durationMs = (end - start).toFixed(2);

            console.log(
                depth.toString().padEnd(8) +
                // "| " + constraints.toString().padEnd(1) +
                "| " + durationMs
            );
        } catch (error) {
            console.log(
                error.message +
                "| ERROR: Missing artifacts or invalid data"
            );
        }
    }
    console.log("=========================================================\n");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });