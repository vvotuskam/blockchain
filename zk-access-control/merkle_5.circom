pragma circom 2.0.0;
include "merkle_access.circom";

// Instantiate a tree with 5 levels. The root is public, everything else is private.
component main {public [root]} = MerkleTreeInclusionProof(5);