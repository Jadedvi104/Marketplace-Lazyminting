// SPDX-License-Identifier: Multiverse Expert
pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BWNFT is
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
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

    using SafeMathUpgradeable for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    function initialize(string memory _name, string memory _symbol)
        public
        initializer
    {
        __ERC721_init(_name, _symbol);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

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
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
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
                    StringsUpgradeable.toString(_tokenId),
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

    function listOnMarket(
        uint256 _tokenId,
        bool _listed,
        uint256 _orderId
    ) public onlyRole(MARKET_ROLE) {
        sNfts[_tokenId].listed = _listed;
        if (_listed == true) {
            sNfts[_tokenId].orderId.push(_orderId);
        } else {
            require(
                sNfts[_tokenId].orderId[sNfts[_tokenId].orderId.length - 1] ==
                    _orderId,
                "This order is not exist"
            );
            sNfts[_tokenId].orderId.pop();
        }
    }

    function updateOwner(
        uint256 _tokenId,
        address _newOwner,
        uint256 _price
    ) public onlyRole(MARKET_ROLE) {
        sNfts[_tokenId].owner.push(_newOwner);
        sNfts[_tokenId].price.push(_price);
    }

    function getNfts(uint256 _tokenId) public view returns (NFTs memory) {
        return sNfts[_tokenId];
    }

    function getNFTOwner(uint256 _tokenId) public view returns (address) {
        return sNfts[_tokenId].owner[sNfts[_tokenId].owner.length - 1];
    }

    function getNFTListed(uint256 _tokenId) public view returns (bool) {
        return sNfts[_tokenId].listed;
    }

    function getNFTOrderId(uint256 _tokenId) public view returns (uint256) {
        return sNfts[_tokenId].orderId[sNfts[_tokenId].orderId.length - 1];
    }
}
