module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('LTokenLite', {
    from: deployer,
    log: true,
    args: ['Privi Exchange Liquidity Token', 'pLT'],
  });
};

module.exports.tags = ['ltoken'];
