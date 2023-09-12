const privKeyrinkeby = "";
const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  networks: {
    dev: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 5000000
    },
    mumbai: {
      host: "https://polygon-mumbai.blockpi.network/v1/rpc/public",
      network_id: "*",
      port: 8545,
      gas: 5000000,
      provider: () => new HDWalletProvider(privKeyrinkeby, "https://polygon-mumbai.blockpi.network/v1/rpc/public"),
    }
  },
  compilers: {
    solc: {
      version: "0.8.9",
      settings: {
        optimizer: {
          enabled: true, // Default: false
          runs: 200      // Default: 200
        },
      }
    }
  }
};
  
