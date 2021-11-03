
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('UniswapFactory', {
    from: deployer,
    log: true,
    args: [],
  });

};

module.exports.tags = ['uniswap_factory'];

