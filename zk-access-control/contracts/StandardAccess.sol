// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StandardAccess {
    bytes32[] public authorizedHashes;

    event AccessGranted(address indexed user, string documentId);

    // Populate the contract with initial user identity hashes
    function addUsers(bytes32[] memory hashes) external {
        for (uint256 i = 0; i < hashes.length; i++) {
            authorizedHashes.push(hashes[i]);
        }
    }

    // Evaluates access by iterating through the list
    function requestAccess(string memory documentId, uint256 secret) external returns (bool) {
        bytes32 targetHash = keccak256(abi.encodePacked(msg.sender, secret));
        bool found = false;

        uint256 length = authorizedHashes.length;
        for (uint256 i = 0; i < length; i++) {
            if (authorizedHashes[i] == targetHash) {
                found = true;
                break; // Exit early if found to optimize gas
            }
        }

        if (found) {
            emit AccessGranted(msg.sender, documentId);
            return true;
        }

        revert("Access Denied");
    }
}