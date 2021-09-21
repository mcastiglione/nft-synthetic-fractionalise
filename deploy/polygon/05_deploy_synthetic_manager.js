module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');

  await deploy('SyntheticCollectionManager', {
    from: deployer,
    log: true,
    args: [randomConsumer.address],
  });
};

module.exports.tags = ['synthetic_manager_implementation'];
module.exports.dependencies = ['chainlink_random_consumer'];
