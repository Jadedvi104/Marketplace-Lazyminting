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
    uint256 public constant mintingFee = 1000; //divide by 10000
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

    /******************* MAPPING *********************/

    mapping(address => uint256) pendingWithdrawals;

    /******************* STRUCT *********************/

    /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct NFTVoucher {
        /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
        uint256 tokenId;
        /// @notice The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
        uint256 minPrice;
        /// @notice The metadata URI to associate with this token.
        string uri;
        /// @notice the EIP-712 signature of all other fields in the NFTVoucher struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }

    /******************* SETUP FUNCS *********************/

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

    function safeMint(address owner, string memory genHash)
        public
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
                    genHash,
                    "/",
                    Strings.toString(_tokenId),
                    ".json"
                )
            )
        );

        tokenIdCounter.increment();

        return _tokenId;
    }

    /******************* MUST HAVE FUNCS *********************/

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

    /******************* VIEW FUNCS *********************/

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    function _verify(NFTVoucher calldata voucher)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
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
                            "NFTVoucher(uint256 tokenId,uint256 minPrice,string uri)"
                        ),
                        voucher.tokenId,
                        voucher.minPrice,
                        keccak256(bytes(voucher.uri))
                    )
                )
            );
    }

    /******************* ACTION FUNCS *********************/

    /// @notice bulk grant role for minter
    function grantMinterRoles(address[] memory _addresses)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for(uint32 i=0; i< _addresses.length; i++) {
             grantRole(MINTER_ROLE, _addresses[i]);
        }
    }
    
    /// @notice airdrop to users
    function airDrop(address[] memory _addresses)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256[] memory)
    {

        uint256[] memory tokenIds = new uint256[](_addresses.length);

        for(uint32 i=0; i< _addresses.length; i++) {
            uint256 _tokenId = tokenIdCounter.current();
            _safeMint(_addresses[i], _tokenId);
            _setTokenURI(
            _tokenId,
            string(
                abi.encodePacked(
                    baseURI,
                    "/",
                    Strings.toString(_tokenId),
                    ".json"
                    )
                )
            );

            tokenIds[i] = _tokenId;
        }

        return tokenIds;
    }

    /// @notice Transfers all pending withdrawal balance to the caller. Reverts if the caller is not an authorized minter.
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

    /// @notice Retuns the amount of Ether available to the caller to withdraw.
    function availableToWithdraw() public view returns (uint256) {
        return pendingWithdrawals[msg.sender];
    }

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param redeemer The address of the account which will receive the NFT upon success.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(address redeemer, NFTVoucher calldata voucher)
        public
        payable
        returns (uint256)
    {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);

        // make sure that the signer is authorized to mint NFTs
        require(
            hasRole(MINTER_ROLE, signer),
            "Signature invalid or unauthorized"
        );

        // make sure that the redeemer is paying enough to cover the buyer's cost
        require(msg.value >= voucher.minPrice, "Insufficient funds to redeem");

        // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);

        // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);

        if (voucher.minPrice > 0) {
            //calculate the fee
            uint256 fee = (msg.value * mintingFee) / 10000;
            uint256 amount = msg.value - fee;

            // charge minting fee to owner
            (bool sent, ) = adminWallet.call{value: fee}("");
            require(sent, "Failed to send Ether");

            // record payment to signer's withdrawal balance
            pendingWithdrawals[signer] += amount;
        }

        return voucher.tokenId;
    }
}
