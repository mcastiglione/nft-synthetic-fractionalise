// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract StakingERC721 is ERC721 {
    using Counters for Counters.Counter;

    struct Position {
        uint256 stake;
        uint256 totalShares;
    }

    Counters.Counter private idGen;

    mapping(uint256 => Position) private positions;

    // solhint-disable-next-line
    constructor() ERC721("", "") {}

    function createPosition(
        address to,
        uint256 stakeAmount,
        uint256 totalShares
    ) external {
        idGen.increment();
        uint256 id = idGen.current();
        _mint(to, id);
        positions[id].stake = stakeAmount;
        positions[id].totalShares = totalShares;
    }

    function getPosition(uint256 id) external view returns (uint256 stake, uint256 totalShares) {
        stake = positions[id].stake;
        totalShares = positions[id].totalShares;
    }

    function decreasePosition(
        uint256 id,
        address owner,
        uint256 amount,
        uint256 totalShares
    ) external {
        require(ownerOf(id) == owner, "Cannot update position if not owner");
        if (amount == positions[id].stake) {
            _burn(id);
            delete positions[id];
        } else {
            positions[id].stake -= amount;
            positions[id].totalShares = totalShares;
        }
    }

    function setPositionTotalShares(
        uint256 id,
        address owner,
        uint256 totalShares
    ) external {
        require(ownerOf(id) == owner, "Cannot update position if not owner");
        positions[id].totalShares = totalShares;
    }

    function calculateReward(uint256 id, uint256 totalAccumulatedShares)
        external
        view
        returns (uint256 reward)
    {
        reward = ((totalAccumulatedShares - positions[id].totalShares) * positions[id].stake) / 10**18;
    }
}
