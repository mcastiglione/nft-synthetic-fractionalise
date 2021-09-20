// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../Interfaces.sol";
import "./Structs.sol";

contract SyntheticNFT is ERC721, Initializable, AccessControl {

    bytes32 public constant MANAGER = keccak256("MANAGER");

    // token metadata
    mapping(uint256 => string) private _tokenMetadata;

    // proxied values for the erc721 attributes
    string private _proxiedName;
    string private _proxiedSymbol;

    // solhint-disable-next-line
    constructor() ERC721("Privi Collection Token", "PCT") {}

    function initialize(
        string memory name_,
        string memory symbol_,
        address collectionManager
    ) external initializer {
        _proxiedName = name_;
        _proxiedSymbol = symbol_;

        _setupRole(MANAGER, collectionManager);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _proxiedName;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _proxiedSymbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenMetadata[tokenId];
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function safeMint(address to, uint256 tokenId, string memory metadata) public onlyRole(MANAGER) {
        _safeMint(to, tokenId);
        _tokenMetadata[tokenId] = metadata;
    }

    function safeBurn(uint256 tokenId) public onlyRole(MANAGER) {
        _burn(tokenId);
        _tokenMetadata[tokenId] = "";
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override (AccessControl, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
