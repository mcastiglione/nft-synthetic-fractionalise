module.exports = async() => {

  const [owner] = await ethers.getSigners();

  const Jot = await ethers.getContractFactory("Jot");
  const JotDeploy = await Jot.deploy();

  const JotStaking = await ethers.getContractFactory("JotStaking");
  const JotStakingDeploy = await JotStaking.deploy();

  const NFTPerpetualFutures = await ethers.getContractFactory("NFTPerpetualFutures");
  const NFTPerpetualFuturesDeploy = await NFTPerpetualFutures.deploy();

  const SyntheticERC721 = await ethers.getContractFactory("SyntheticERC721");
  const SyntheticERC721Deploy = await SyntheticERC721.deploy();

  const SyntheticProtocolRouter = await ethers.getContractFactory("SyntheticProtocolRouter");
  const SyntheticProtocolRouterDeploy = await SyntheticProtocolRouter.deploy();

  const SyntheticProtocolManager = await ethers.getContractFactory("SyntheticProtocolManager");
  const SyntheticProtocolManagerDeploy = await SyntheticProtocolManager.deploy();

  const Governance = await ethers.getContractFactory("Governance");
  const GovernanceDeploy = await Governance.deploy();

  const PolygonValidatorOracle = await ethers.getContractFactory("PolygonValidatorOracle");
  const PolygonValidatorOracleDeploy = await PolygonValidatorOracle.deploy();

  const RewardManager = await ethers.getContractFactory("RewardManager");
  const RewardManagerDeploy = await RewardManager.deploy();

}

module.exports.tags = ['DeployPolygon'];
