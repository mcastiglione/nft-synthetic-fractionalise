const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  // get previously deployed contracts
  const lToken = await ethers.getContract('LTokenLite');
  const pToken = await ethers.getContract('PTokenLite');
  const futuresParameters = await ethers.getContract('FuturesProtocolParameters');

  // TODO: change this deployment to the real contract
  const bTokenAddress = "0x2cA48b8c2d574b282FDAB69545646983A94a3286"

  const pool = await deploy('PerpetualPoolLite', {
    from: deployer,
    log: true,
    args: [[futuresParameters.address, bTokenAddress]],
  });

  if (pool.newlyDeployed) {
    log('Initializing lToken...');
    await lToken.setPool(pool.address);
    log('Initializing pToken...');
    await pToken.setPool(pool.address);
  }
};

module.exports.tags = ['pool'];
module.exports.dependencies = ['ltoken', 'ptoken', 'oracle', 'futures_protocol_parameters'];
