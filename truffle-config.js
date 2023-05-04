
const privKeyrinkeby = "eae752e09ea4109e4ad21a4f35bf8df27e6fb83a67363ac1fcf7e3a330e3e862"
const PrivateKeyProvider = require("truffle-privatekey-provider");

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 5000000
    },
    mumbai: {
      host: "https://rpc.ankr.com/polygon_mumbai",
      port: 8545,
      network_id: "*",
      gas: 5000000,
      provider: () => new PrivateKeyProvider(privKeyrinkeby, "https://rpc.ankr.com/polygon_mumbai"),
    }
  },
  compilers: {
    solc: {
      version: "^0.8.0",
      settings: {
        optimizer: {
          enabled: true, // Default: false
          runs: 200      // Default: 200
        },
      }
    }
  }
};
