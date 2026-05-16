pragma circom 2.0.0;
include "merkle_access.circom";

component main {public [root]} = MerkleTreeInclusionProof(50);