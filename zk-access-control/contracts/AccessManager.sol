// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Verifier.sol";

contract AccessManager {
    Groth16Verifier public verifier;
    uint256 public validCorporateCommitment;
    address public admin;

    event AccessGranted(address indexed user, string cid);

    constructor(address _verifierAddress) {
        verifier = Groth16Verifier(_verifierAddress);
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized: Admin only");
        _;
    }

    function updateCommitment(uint256 _newCommitment) external onlyAdmin {
        validCorporateCommitment = _newCommitment;
    }

    function requestAccess(
        uint[2] calldata a,
        uint[2][2] calldata b,
        uint[2] calldata c,
        uint[1] calldata input,
        string calldata cid
    ) external {
        require(input[0] == validCorporateCommitment, "Invalid corporate commitment");

        bool isValid = verifier.verifyProof(a, b, c, input);
        require(isValid, "ZKP Verification Failed");

        emit AccessGranted(msg.sender, cid);
    }
}
