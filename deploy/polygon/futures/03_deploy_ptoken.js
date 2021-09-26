module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('PTokenLite', {
    from: deployer,
    log: true,
    args: ['Privi Exchange Position Token', 'pPT'],
  });
};

module.exports.tags = ['ptoken'];
