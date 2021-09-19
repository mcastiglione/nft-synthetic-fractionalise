// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../SyntheticProtocolRouter.sol";
import "../Interfaces.sol";
import "./Structs.sol";

contract SyntheticNFT is ERC721, Initializable {

    // solhint-disable-next-line
    constructor() ERC721("Privi Colecction Token", "PCT") {}

    function initialize(
    ) external initializer {
    }

}
