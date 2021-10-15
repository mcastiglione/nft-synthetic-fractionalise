// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../polygon/governance/FuturesProtocolParameters.sol";
import "../../polygon/Interfaces.sol";

contract SymbolOracleOffChainMock is IOracleWithUpdate, Initializable {
    address public immutable signatory;
    FuturesProtocolParameters private _protocolParameters;

    uint256 public timestamp = block.timestamp;
    uint256 public price = 1;

    address private immutable _deployer;

    constructor(address signatory_) {
        signatory = signatory_;
        _deployer = msg.sender;
    }

    function initialize(address protocolParameters_) external initializer {
        require(msg.sender == _deployer, "Only deployer can initialize");
        _protocolParameters = FuturesProtocolParameters(protocolParameters_);
    }

    function getPrice() external view override returns (uint256) {
        return price;
    }

    // update oracle price using off chain signed price
    // the signature must be verified in order for the price to be updated
    function updatePrice(
        address address_,
        uint256 timestamp_,
        uint256 price_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external override {
        uint256 lastTimestamp = timestamp;
        if (timestamp_ > lastTimestamp) {
            timestamp = timestamp_;
            price = price_;
        }
    }
}
