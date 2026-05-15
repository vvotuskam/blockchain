require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    besu: {
      url: "http://127.0.0.1:8545",
      accounts: ["0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63"],
      chainId: 1337,           // CRITICAL: Besu dev-mode default
      gasPrice: 1000000000,    // 1 Gwei
      gas: 8000000             // High limit for ZKP verification
    }
  }
};
