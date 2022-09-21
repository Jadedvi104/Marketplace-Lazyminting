// SPDX-License-Identifier: Multiverse Expert
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract UNQSNFT is
    ERC721,
    ERC721URIStorage,
    ERC721Enumerable,
    AccessControl,
    Pausable,
    ReentrancyGuard
{
    struct NFTs {
        address creator;
        address[] owner;
        uint256[] orderId;
        bool listed;
        uint256[] price;
    }

    mapping(uint256 => NFTs) public sNfts; // tokenid
    using Counters for Counters.Counter;
    Counters.Counter private tokenIdCounter;
    string public baseURI;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    constructor() ERC721("UniqeSpot", "UNQS") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MARKET_ROLE, msg.sender);

    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause()
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyRole(PAUSER_ROLE)
    {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC721,
            ERC721Enumerable,
            AccessControl
        )
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function burn(uint256 tokenId) public whenNotPaused onlyRole(MINTER_ROLE) {
        require(msg.sender == ownerOf(tokenId), "Monster: not owner");
        _burn(tokenId);
        delete sNfts[tokenId];
    }

    function setBaseUri(string memory _baseUri)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = _baseUri;
    }

    function safeMint(address owner, string memory _hash)
        public
        whenNotPaused
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        uint256 _tokenId = tokenIdCounter.current();
        _safeMint(owner, _tokenId);
        _setTokenURI(
            _tokenId,
            string(
                abi.encodePacked(
                    baseURI,
                    "/",
                    _hash,
                    "/",
                    Strings.toString(_tokenId),
                    ".json"
                )
            )
        );
        sNfts[_tokenId].creator = owner;
        sNfts[_tokenId].owner.push(owner);
        sNfts[_tokenId].listed = false;

        tokenIdCounter.increment();

        return _tokenId;
    }

}
