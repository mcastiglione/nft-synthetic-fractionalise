module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('SyntheticTokenLibrary', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['synthetic_token_library'];
