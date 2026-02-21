// Configuration for the Arbitrum Sepolia network

module.exports = {
  networks: {
    arbitrumOne: {
      url: process.env.ARBITRUM_ONE_RPC_URL,
      // additional configuration...
    },
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL,
      // additional configuration...
    },
    // other networks...
  }
};