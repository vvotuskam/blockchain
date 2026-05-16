pragma circom 2.0.0;

include "node_modules/circomlib/circuits/poseidon.circom";

template MerkleTreeInclusionProof(levels) {
    signal input leaf;
    signal input pathElements[levels];
    signal input pathIndices[levels];
    signal input root;

    component hashers[levels];
    signal hashes[levels + 1];

    hashes[0] <== leaf;

    for (var i = 0; i < levels; i++) {
        // Enforce that pathIndices is exactly 0 or 1
        pathIndices[i] * (1 - pathIndices[i]) === 0;

        hashers[i] = Poseidon(2);

        // Algebraic swap based on the index:
        // If pathIndices[i] == 0, left input is hashes[i], right is pathElements[i]
        // If pathIndices[i] == 1, left input is pathElements[i], right is hashes[i]
        hashers[i].inputs[0] <== hashes[i] - pathIndices[i] * (hashes[i] - pathElements[i]);
        hashers[i].inputs[1] <== pathElements[i] - pathIndices[i] * (pathElements[i] - hashes[i]);

        hashes[i + 1] <== hashers[i].out;
    }

    // Constraint: The computed root must match the public root
    root === hashes[levels];
}

// NOTE FOR COMPILATION:
// To compile the 3 variations, you will need to instantiate this template in 3 separate
// entry files (or modify it before compilation), like so:
// component main {public [root]} = MerkleTreeInclusionProof(10);