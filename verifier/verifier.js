/**
 * @dev script to deploy the EverlastingOption contract and dependencies
 *
 * after deployment addresses of contracts are saved in the everlasting-option.deploy.log
 * file under the logs folder for later consulting
 */
const fs = require('fs');
const BigNumber = require('bignumber.js');

// const file = fs.createWriteStream('./logs/everlasting-option.deploy.log', { flags: 'w' });
// let logger = new console.Console(file, file);

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
// rescale
function one(value = 1, left = 0, right = 18) {
  let from = ethers.BigNumber.from('1' + '0'.repeat(left));
  let to = ethers.BigNumber.from('1' + '0'.repeat(right));
  return ethers.BigNumber.from(value).mul(to).div(from);
}

function neg(value) {
  return value.mul(-1);
}

let usdt_address = '0x580d6ebC53BB4239f52C5E28a9c2bD037faB0089';

let protocol_params_address = '0x7485C5B724C99475411721CE070116102665F99C';
let offchainOracle_address = '0x5723B0c53eD5564A15c215A349445029B2dd902f';

let ltoken_address = '0xAF8623Cd7CACdE3d8e529fF9500159C6F2b03868';
let ptoken_address = '0xb4Ee9dc5F3d21b37D931c8DB30376dceC3CF7403';

let perpetual_address = '0x8d82EBB3fED62BeeA28a192eD9047DDf26d76fB3';
let pool_info = '0x745035fded1AEfCf60B73117d067196c8ff22a3d';

let symbolOracle = '';

async function main() {
  //const config = getConfigFromNetwork(hre.network.name);

  // ! change the signatory before deploying to production
  [deployer] = await ethers.getSigners();
  console.log('Deployer address: ', deployer.address);

  const mainParams = {
    minPoolMarginRatio: one(),
    minInitialMarginRatio: one(1, 1),
    minMaintenanceMarginRatio: one(5, 2),
    minLiquidationReward: one(10),
    maxLiquidationReward: one(1000),
    liquidationCutRatio: one(5, 1),
    protocolFeeCollectRatio: one(2, 1),
  };

  const defaultProtocolParameters = {
    mainParams,
    futuresOracleAddress: symbolOracle,
    futuresMultiplier: 1,
    futuresFeeRatio: 1,
    futuresFundingRateCoefficient: 1,
    oracleDelay: 6000,
  };
 
   // verify test usdt
  //  console.log('Verifying usdt...');
  //  await hre.run("verify:verify", {
  //        address: usdt_address,
  //        constructorArguments: ['Tether USDT', 'USDT']
  //  });
  //  console.log(`Verified USDT: ${usdt_address}`);
 
  //  // verify liquidity token
  //  console.log('Verifying lToken...');
  //  await hre.run("verify:verify", {
  //        address: ltoken_address,
  //        //contract: "contracts/token/LTokenLite.sol:LTokenLite",
  //        constructorArguments: []
  //  });
  //  console.log(`Verified lToken: ${ltoken_address}`);
 
  //  // verify position token
  //  console.log('Verifying pToken...');
  //  await hre.run("verify:verify", {
  //        address: ptoken_address,
  //        constructorArguments: []
  //  });
  //  console.log(`Verified pToken: ${ptoken_address}`);
 
 
   // verify protocol params 
  //  console.log('Verifying protocol params...');
  //  await hre.run("verify:verify", {
  //        address: protocol_params_address,
  //        constructorArguments: [...Object.values(defaultProtocolParameters), deployer.address]
  //  });
  //  console.log(`Verified protocol params.: ${protocol_params_address}`);
 
 
    // verify perpetual pool
    console.log('Verifying perpetual pool...');
    await hre.run("verify:verify", {
          address: perpetual_address,
          constructorArguments:[[protocol_params_address, offchainOracle_address]]
    });
    console.log(`Verified perpetual pool: ${perpetual_address}`);
 
    // verify pool info
    // console.log('Verifying pool info...');
    // await hre.run("verify:verify", {
    //       address: pool_info,
    //       constructorArguments: [ perpetual_address ]
    // });
    // console.log(`Verified pool info: ${pool_info}`);
 
   // verify offchain oracle
    console.log('Verifying offchain oracle...');
    await hre.run("verify:verify", {
          address: offchainOracle_address,
          constructorArguments: []
    });
    console.log(`Verified offchain oracle: ${offchainOracle_address}`);
  }
 
 function getConfigFromNetwork(network) {
   switch (network) {
     case 'rinkeby':
       return {
         volatilityChainlinkOracle: {
           linkToken: '0x01BE23585060835E02B77ef475b0Cc51aA1e0709',
           chainlinkNode: '0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e',
           jobId: '6d1bfe27e7034b1d87b5270556b17277',
           nodeFee: 100,
         },
       };
     default:
       throw new Error('Trying to deploy to an unconfigured network');
   }
 }
 
 main()
   .then(() => process.exit(0))
   .catch((error) => {
     console.error(error);
     process.exit(1);
   });