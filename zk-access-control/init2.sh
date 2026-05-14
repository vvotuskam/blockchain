#!/bin/bash
set -e

echo "1. Installing Hardhat and dependencies..."
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox ethers

echo "2. Creating directories..."
mkdir -p contracts scripts

echo "3. Creating hardhat.config.js..."
cat << 'EOF' > hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
};
EOF

echo "4. Preparing Verifier.sol..."
if [ -f "Verifier.sol" ]; then
    mv Verifier.sol contracts/
else
    echo "Warning: Verifier.sol not found in root directory. Ensure it is generated before compiling contracts."
fi

if [ -f "contracts/Verifier.sol" ]; then
    # Using .bak extension for cross-platform compatibility (macOS/Linux)
    sed -i.bak 's/pragma solidity.*/pragma solidity ^0.8.0;/g' contracts/Verifier.sol
    rm -f contracts/Verifier.sol.bak
fi

echo "5. Populating AccessManager.sol..."
cat << 'EOF' > contracts/AccessManager.sol
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
EOF

echo "6. Populating deploy.js..."
cat << 'EOF' > scripts/deploy.js
const hre = require("hardhat");

async function main() {
  console.log("Deploying Groth16Verifier...");
  const Verifier = await hre.ethers.getContractFactory("Groth16Verifier");
  const verifier = await Verifier.deploy();
  await verifier.waitForDeployment();
  const verifierAddress = await verifier.getAddress();
  console.log(`Groth16Verifier deployed to: ${verifierAddress}`);

  console.log("Deploying AccessManager...");
  const AccessManager = await hre.ethers.getContractFactory("AccessManager");
  const accessManager = await AccessManager.deploy(verifierAddress);
  await accessManager.waitForDeployment();
  const accessManagerAddress = await accessManager.getAddress();
  console.log(`AccessManager deployed to: ${accessManagerAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOF

echo "Module 2 Setup Complete! You can now run: npx hardhat compile"