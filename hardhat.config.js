require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-solhint');
require('@nomiclabs/hardhat-web3');
require('hardhat-gas-reporter');
require('hardhat-contract-sizer');
require('./tasks/accounts');
require('./tasks/balance');

require('dotenv').config();

const MNEMONIC = process.env.MNEMONIC;
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const INFURA_API_KEY = process.env.INFURA_API_KEY;

module.exports = {
  solidity: {
    compilers: [
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
    localhost: {
      url: 'http://127.0.0.1:7545', // ganache local network
      accounts: { mnemonic: MNEMONIC },
    },
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
      },
    },
  },
  gasReporter: {
    enabled: true,
  },
};
