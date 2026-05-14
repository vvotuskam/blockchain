echo "Updating hardhat.config.js to ESM..."
cat << 'EOF' > hardhat.config.js
import "@nomicfoundation/hardhat-toolbox";

/** @type import('hardhat/config').HardhatUserConfig */
export default {
  solidity: "0.8.20",
};
EOF

echo "Updating scripts/deploy.js to ESM..."
cat << 'EOF' > scripts/deploy.js
import hre from "hardhat";

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

echo "Fix applied! You can now run: npx hardhat compile"