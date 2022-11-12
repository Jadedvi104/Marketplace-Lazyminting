// SPDX-License-Identifier: Multiverse Expert
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract UNQSNFT is
    ERC721,
    ERC721URIStorage,
    ERC721Enumerable,
    EIP712,
    AccessControl,
    ReentrancyGuard,
    ERC2981
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";
    uint256 public constant mintingFee = 1000; //10%
    address payable private adminWallet; //adminwallet that collect fee

    using Counters for Counters.Counter;
    Counters.Counter public tokenIdCounter;
    string public baseURI;

    constructor()
        ERC721("UniqeSpot", "UNQS")
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    mapping(address => uint256) pendingWithdrawals;
    mapping(string => uint256) tokenIdforUri;

    struct NFTVoucher {
        bytes32 voucherCode;
        uint256 minPrice;
        uint96 royaltyFee;
        string uri;
        bytes signature;
    }

    function setupAdminWallet(address payable _address)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        adminWallet = _address;
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721URIStorage, ERC721)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721URIStorage, ERC721)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function burn(uint256 tokenId) public onlyRole(MINTER_ROLE) {
        require(msg.sender == ownerOf(tokenId), "Ownership: not owner");
        _burn(tokenId);
    }

    function setBaseUri(string memory _baseUri)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = _baseUri;
    }

    function setRoyaltyForToken(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal {
        // fee should not be over 10000
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    // @dev call to reset token Royalty
    function resetRoyaltyForToken(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _resetTokenRoyalty(tokenId);
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function getRoyaltyInfo(uint256 _tokenId, uint256 _salePrice)
        public
        view
        returns (address, uint256)
    {
        (address receiver, uint256 royaltyAmount) = royaltyInfo(
            _tokenId,
            _salePrice
        );

        return (receiver, royaltyAmount);
    }

    function _verify(NFTVoucher calldata voucher)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    function getTokenId(string memory uri) public view returns (uint256) {
        return tokenIdforUri[uri];
    }

    function _hash(NFTVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "NFTVoucher(bytes32 voucherCode,uint256 minPrice,uint96 royaltyFee,string uri)"
                        ),
                        voucher.voucherCode,
                        voucher.minPrice,
                        voucher.royaltyFee,
                        keccak256(bytes(voucher.uri))
                    )
                )
            );
    }

    function safeMint(
        address _to,
        string memory uriHash,
        uint96 _royaltyFee
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        tokenIdCounter.increment();
        uint256 _tokenId = tokenIdCounter.current();
        string memory uri = string(
                abi.encodePacked(
                    baseURI,
                    "/",
                    uriHash,
                    "/",
                    Strings.toString(_tokenId),
                    ".json"
                )
            );
        _safeMint(_to, _tokenId);
        _setTokenURI(
            _tokenId,
            uri
        );
        setRoyaltyForToken(_tokenId, msg.sender, _royaltyFee);
        tokenIdforUri[uri] = _tokenId;
        return _tokenId;
    }

    function grantMinterRoles(address[] memory _addresses)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint32 i = 0; i < _addresses.length; i++) {
            grantRole(MINTER_ROLE, _addresses[i]);
        }
    }

    function airDrop(
        address[] memory _addresses,
        string[] memory uriHashes,
        uint96 _royaltyFee
    ) public onlyRole(MINTER_ROLE) returns (uint256[] memory) {
        require(_addresses.length == uriHashes.length, "Length must equal");
        uint256[] memory tokenIds = new uint256[](_addresses.length);

        for (uint32 i = 0; i < _addresses.length; i++) {
            tokenIdCounter.increment();
            uint256 _tokenId = tokenIdCounter.current();
            _safeMint(_addresses[i], _tokenId);
            string memory uri = string(
                abi.encodePacked(
                    baseURI,
                    "/",
                    uriHashes[i],
                    "/",
                    Strings.toString(_tokenId),
                    ".json"
                )
            );
            _setTokenURI(_tokenId, uri);
            setRoyaltyForToken(_tokenId, msg.sender, _royaltyFee);
            tokenIdforUri[uri] = _tokenId;
            tokenIds[i] = _tokenId;
        }
        return tokenIds;
    }

    function withdraw() public nonReentrant {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "Only authorized minters can withdraw"
        );

        // IMPORTANT: casting msg.sender to a payable address is only safe if ALL members of the minter role are payable addresses.
        address payable receiver = payable(msg.sender);

        uint256 amount = pendingWithdrawals[receiver];
        // zero account before transfer to prevent re-entrancy attack
        pendingWithdrawals[receiver] = 0;
        receiver.transfer(amount);
    }

    function availableToWithdraw() public view returns (uint256) {
        return pendingWithdrawals[msg.sender];
    }

    function redeem(NFTVoucher calldata voucher)
        public
        payable
        returns (uint256)
    {
        address signer = _verify(voucher);

        // make sure that the signer is authorized to mint NFTs
        require(
            hasRole(MINTER_ROLE, signer),
            "Signature invalid or unauthorized"
        );

        if (voucher.minPrice > 0) {
            require(
                msg.value >= voucher.minPrice,
                "Insufficient funds to redeem"
            );
            //calculate the fee
            uint256 fee = (msg.value * mintingFee) / 10000;
            uint256 amount = msg.value - fee;

            // charge minting fee to owner
            (bool sent, ) = adminWallet.call{value: fee}("");
            require(sent, "Failed to send Ether");

            // record payment to signer's withdrawal balance
            pendingWithdrawals[signer] += amount;
        }

        tokenIdCounter.increment();
        uint256 _tokenId = tokenIdCounter.current();

        _safeMint(msg.sender, _tokenId);
        _setTokenURI(_tokenId, voucher.uri);
        setRoyaltyForToken(_tokenId, signer, voucher.royaltyFee);
        tokenIdforUri[voucher.uri] = _tokenId;

        return _tokenId;
    }
}
