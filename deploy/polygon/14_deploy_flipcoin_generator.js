module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('FlipCoinGenerator', {
    from: deployer,
    log: true,
    //TODO: these are values for Polygon Mumbai testnet
    args: ['0x8c7382f9d8f56b33781fe506e897a4f1e2d17255', '0x326c977e6efc84e512bb9c30f76e30c160ed06fb'],
  });
};
module.exports.tags = ['flipcoin_generator'];
