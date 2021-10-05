const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get previously deployed contracts
  const lToken = await ethers.getContract('LTokenLite');
  const pToken = await ethers.getContract('PTokenLite');
  const futuresParameters = await ethers.getContract('FuturesProtocolParameters');
  const symbolOracleOffChain = await ethers.getContract('SymbolOracleOffChain');

  // TODO: change this deployment to the real contract
  const bToken = await deploy('BTokenMock', {
    from: deployer,
    logs: true,
  });

  const pool = await deploy('PerpetualPoolLite', {
    from: deployer,
    log: true,
    args: [[futuresParameters.address, symbolOracleOffChain.address]],
  });
};

module.exports.tags = ['pool'];
module.exports.dependencies = ['ltoken', 'ptoken', 'futures_protocol_parameters'];
