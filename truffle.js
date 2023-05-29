module.exports = {
  compilers: {
    solc: {
      version: "^0.8.0"
    }
  },
  networks: {
    dev: {
      host: "localhost",
      port: 8545,
      gas: 6000000,
      gasPrice: 40000000000,
      network_id: "*" // Match any network id
    },
    ganache: {
      host: "localhost",
      port: 7545,
      gas: 6721975,
      gasPrice: 20000000000,
      network_id: "*" // Match any network id
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8555,         // <-- If you change this, also set the port option in .solcover.js.
      gas: 0xfffffffffff, // <-- Use this high gas value
      gasPrice: 0x01      // <-- Use this low gas price
    },
  },
};
  