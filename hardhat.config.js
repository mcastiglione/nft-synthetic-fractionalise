require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle');
require("hardhat-gas-reporter");

const { resolve } = require('path');
const { config: dotenvConfig } = require('dotenv');

dotenvConfig({ path: resolve(__dirname, './.env') });

const MNEMONIC = process.env.MNEMONIC;
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const INFURA_API_KEY = process.env.INFURA_API_KEY;

// Ensure that we have all the environment variables we need.
if (!MNEMONIC) {
  throw new Error('Please set your MNEMONIC in a .env file');
}

if (!INFURA_API_KEY) {
  throw new Error('Please set your INFURA_API_KEY in a .env file');
}

if (!ALCHEMY_API_KEY) {
  throw new Error('Please set your ALCHEMY_API_KEY in a .env file');
}


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});


module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.6',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: '0.6.6',
      },
      {
        version: '0.4.17',
      },
      {
        version: '0.5.16',
      },
    ],
  },
  networks: {
    // localhost: {
    //   url: 'http://127.0.0.1:8545', // ganache local network
    //   accounts: { mnemonic: MNEMONIC },
    // },
    // kovan: {
    //   url: `https://kovan.infura.io/v3/${INFURA_API_KEY}`,
    //   accounts: { mnemonic: MNEMONIC },
    // },
    // ropsten: {
    //   url: `https://ropsten.infura.io/v3/${INFURA_API_KEY}`,
    //   accounts: { mnemonic: MNEMONIC },
    // },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
      accounts: { mnemonic: MNEMONIC },
    },
    hardhat: {
      forking: {
        url: `https://eth-rinkeby.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      }
    },
    
  },
  gasReporter: {
    enabled: true,
  }
};
