// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../governance/FuturesProtocolParameters.sol";
import "./interfaces/IOracleWithUpdate.sol";

contract SymbolOracleOffChain is IOracleWithUpdate, Initializable {
    address public immutable signatory;
    FuturesProtocolParameters private _protocolParameters;

    uint256 public timestamp;
    uint256 public price;

    address private _deployer;

    constructor(address signatory_) {
        signatory = signatory_;
        _deployer = msg.sender;
    }

    function initialize(address protocolParameters_) external initializer {
        require(msg.sender == _deployer, "Only deployer can initialize");
        _protocolParameters = FuturesProtocolParameters(protocolParameters_);
    }

    function getPrice() external view override returns (uint256) {
        // solhint-disable-next-line
        require(block.timestamp - timestamp <= _protocolParameters.oracleDelay(), "Price expired");
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
            if (v_ == 27 || v_ == 28) {
                bytes32 message = keccak256(abi.encodePacked(address_, timestamp_, price_));
                bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
                address signer = ecrecover(hash, v_, r_, s_);
                if (signer == signatory) {
                    timestamp = timestamp_;
                    price = price_;
                }
            }
        }
    }
}
