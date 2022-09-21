// SPDX-License-Identifier:  Multiverse Expert
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract UNQSPool is AccessControl, ERC721Holder {
    using Counters for Counters.Counter;
    
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public contractOwnerNFTs;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MARKET_ROLE, msg.sender);
    }

    function depositNFT(
        address nftContract,
        uint256 tokenId,
        address ownner
    ) public onlyRole(MARKET_ROLE) {
        contractOwnerNFTs[nftContract][ownner][tokenId] = 1;
    }

    function transferNFT(
        address nftContract,
        address to,
        uint256 tokenId
    ) public onlyRole(MARKET_ROLE) {
        IERC721(nftContract).transferFrom(address(this), to, tokenId);
    }

    function withdrawNFT(address nftContract, uint256 tokenId) public {
        require(
            contractOwnerNFTs[nftContract][msg.sender][tokenId] == 1,
            "You is not token owner."
        );
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        contractOwnerNFTs[nftContract][msg.sender][tokenId] = 0;
    }
}
