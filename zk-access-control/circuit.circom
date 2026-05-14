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
