
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let factory = await ethers.getContract('UniswapFactory');
  let weth = await ethers.getContract('WETH');

  let Factory = await deploy('UniswapRouter', {
    from: deployer,
    log: true,
    args: [factory.address, weth.address],
  });

};

module.exports.tags = ['uniswap_router'];
module.exports.dependencies = ['uniswap_factory', 'weth'];
