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
