// SPDX-License-Identifier:  Multiverse Expert
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface NFT_POOL {
    function depositNFT(
        address nftContract,
        uint256 tokenId,
        address ownner
    ) external;

    function transferNFT(
        address nftContract,
        address to,
        uint256 tokenId
    ) external;
}

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function listOnMarket(
        uint256 _tokenId,
        bool _listed,
        uint256 _orderId
    ) external;

    function updateOwner(
        uint256 _tokenId,
        address _newOwner,
        uint256 _price
    ) external;

    function getNFTOwner(uint256 _tokenId) external view returns (address);

    function getNFTListed(uint256 _tokenId) external view returns (bool);

    function getNFTOrderId(uint256 _tokenId) external view returns (uint256);
}

contract BWNFTMarket is ReentrancyGuard, ERC721Holder, Pausable, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter public _orderIds;
    Counters.Counter public _offerIds;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public auctionFees = 1000;
    uint256 public feesRate = 425;

    address public nftPool;

    struct Order {
        address nftContract;
        uint256 orderId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        address buyWithTokenContract;
        bool listed;
        bool sold;
        bool cancel;
    }

    struct Offer {
        address buyer;
        uint256 price;
        uint256 tokenId;
        uint256 offerId;
        address buyWithTokenContract;
        uint256 timeOfferStart;
        uint256 timeOfferEnd;
        bool isAccept;
        bool active;
    }

    /************************** Mappings *********************/

    mapping(uint256 => Order) public idToOrder;
    //
    mapping(uint256 => Offer[]) private offers;

    /************************** Events *********************/

    event OrderCreated(
        address indexed nftContract,
        uint256 indexed orderId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        address buyWithTokenContract,
        bool listed,
        bool sold,
        bool cancel
    );

    event OrderCanceled(
        address indexed nftContract,
        uint256 indexed orderId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        address buyWithTokenContract,
        bool listed,
        bool sold,
        bool cancel
    );

    event OrderSuccessful(
        address indexed nftContract,
        uint256 indexed orderId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        address buyWithTokenContract,
        bool listed,
        bool sold,
        bool cancel
    );

    event OfferEvent(
        address indexed buyer,
        uint256 price,
        uint256 indexed tokenId,
        uint256 indexed offerId,
        address buyWithTokenContract,
        uint256 timeOfferStart,
        uint256 timeOfferEnd,
        bool isAccept,
        bool active
    );

    event CancelOfferEvent(
        address indexed buyer,
        uint256 indexedtokenId,
        uint256 indexed offerId,
        bool active
    );

    event offerSuccesfully(
        address nftContract,
        uint256 indexed tokenId,
        uint256 indexed offerId,
        address seller,
        address buyer,
        uint256 price,
        bool sold,
        bool isAccept,
        bool active
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /******************* Write Functions *********************/

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function updateNFTPool(address _nftPool)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        nftPool = _nftPool;
    }

    function updateFeesRate(uint256 newRate)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newRate <= 500);
        feesRate = newRate;
    }

    function updateAuctionFeesRate(uint256 newRate)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newRate >= 500);
        auctionFees = newRate;
    }

    /*******************Read Functions *********************/

    function getOffer(uint256 tokenId) public view returns (Offer[] memory) {
        return offers[tokenId];
    }

    /******************* Action Functions *********************/

    /* Create an offer for specific order on the marketplace */
    function makeOffer(
        uint256 tokenId,
        uint256 price,
        address buyWithTokenContract
    ) public nonReentrant {
        // set require ERC721 approve below
        uint256 userBalance = IERC20(buyWithTokenContract).balanceOf(
            msg.sender
        );
        require(price > 100, "Price must be at least 100 wei");
        require(userBalance >= price, "Balance: You do not have enough token");

        _offerIds.increment();
        uint256 offerId = _offerIds.current();

        offers[tokenId].push(
            Offer(
                msg.sender,
                price,
                tokenId,
                offerId,
                buyWithTokenContract,
                block.timestamp,
                block.timestamp + 20 minutes,
                false,
                true
            )
        );

        emit OfferEvent(
            msg.sender,
            price,
            tokenId,
            offerId,
            buyWithTokenContract,
            block.timestamp,
            block.timestamp + 5 minutes,
            false,
            true
        );
    }

    /* Cancel an offer for specific order on the marketplace */
    function cancelOffer(uint256 tokenId, uint256 offerId) public nonReentrant {
        uint256 index;
        for (uint32 i; i < offers[tokenId].length; i++) {
            if (offers[tokenId][i].offerId == offerId) {
                index = i;
            }
        }
        require(
            offers[tokenId][index].buyer == msg.sender,
            "You are not owner of the offer"
        );
        require(offers[tokenId][index].active == true, "It's canceled item");

        offers[tokenId][index].active = false;

        emit CancelOfferEvent(msg.sender, tokenId, offerId, false);
    }

    function acceptOffer(
        uint256 tokenId,
        uint256 offerId,
        address buyWithTokenContract,
        address nftContract
    ) public nonReentrant {
        uint256 index;
        for (uint32 i; i < offers[tokenId].length; i++) {
            if (offers[tokenId][i].offerId == offerId) {
                index = i;
            }
        }
        require(
            offers[tokenId][index].isAccept == false,
            "This offer is already accepted"
        );
        require(
            offers[tokenId][index].active == true,
            "This offer is not active"
        );
        require(
            block.timestamp <= offers[tokenId][index].timeOfferEnd,
            "Buyer does not have enough token"
        );
        address buyerAddr = offers[tokenId][index].buyer;
        uint256 balance = IERC20(buyWithTokenContract).balanceOf(buyerAddr);

        require(
            balance >= offers[tokenId][index].price,
            "Buyer does not have enough token"
        );

        uint256 price = offers[tokenId][index].price;
        uint256 fee = (price * feesRate) / 10000;
        uint256 amount = price - fee;
        uint256 orderId = IERC721(nftContract).getNFTOrderId(tokenId);

        //Transfer fee to platform.
        IERC20(buyWithTokenContract).transferFrom(
            buyerAddr,
            address(this),
            fee
        );

        //Transfer token(WolfCoin) to nft seller.
        IERC20(buyWithTokenContract).transferFrom(
            buyerAddr,
            msg.sender,
            amount
        );

        if (IERC721(nftContract).getNFTListed(tokenId) == true) {
            require(idToOrder[orderId].sold == false, "It's sold item");
            require(idToOrder[orderId].cancel == false, "It's canceled item");
            require(
                idToOrder[orderId].seller == msg.sender,
                "You are not the owner"
            );
            // seller.transfer(NFT) when listed;
            NFT_POOL(nftPool).transferNFT(
                idToOrder[orderId].nftContract,
                buyerAddr,
                tokenId
            );

            idToOrder[orderId].owner = buyerAddr;
            idToOrder[orderId].sold = true;
        } else {
            // seller.transfer(NFT) when not listed;
            IERC721(nftContract).safeTransferFrom(
                msg.sender,
                buyerAddr,
                tokenId
            );
        }

        IERC721(nftContract).updateOwner(tokenId, buyerAddr, price);

        offers[tokenId][index].isAccept = true;
        offers[tokenId][index].active = false;

        emit offerSuccesfully(
            nftContract,
            tokenId,
            offerId,
            msg.sender,
            buyerAddr,
            price,
            true,
            true,
            false
        );
    }

    /* Places an item for sale on the marketplace */
    function createOrder(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address buyWithTokenContract
    ) public nonReentrant {
        // set require ERC721 approve below
        require(price > 100, "Price must be at least 100 wei");
        _orderIds.increment();
        uint256 orderId = _orderIds.current();
        idToOrder[orderId] = Order(
            nftContract,
            orderId,
            tokenId,
            msg.sender,
            nftPool,
            price,
            buyWithTokenContract,
            true,
            false,
            false
        );

        // tranfer NFT ownership to Market contract
        IERC721(nftContract).safeTransferFrom(msg.sender, nftPool, tokenId);
        IERC721(nftContract).listOnMarket(tokenId, true, orderId);
        NFT_POOL(nftPool).depositNFT(nftContract, tokenId, msg.sender);

        emit OrderCreated(
            nftContract,
            orderId,
            tokenId,
            msg.sender,
            address(0),
            price,
            buyWithTokenContract,
            true,
            false,
            false
        );
    }

    function cancelOrder(uint256 orderId) public nonReentrant {
        require(idToOrder[orderId].sold == false, "Sold item");
        require(idToOrder[orderId].cancel == false, "Canceled item");
        require(idToOrder[orderId].seller == msg.sender); // check if the person is seller

        idToOrder[orderId].cancel = true;
        idToOrder[orderId].listed = false;

        //Transfer back to owner :: owner is marketplace now >>> original owner
        NFT_POOL(nftPool).transferNFT(
            idToOrder[orderId].nftContract,
            msg.sender,
            idToOrder[orderId].tokenId
        );
        IERC721(idToOrder[orderId].nftContract).listOnMarket(
            idToOrder[orderId].tokenId,
            false,
            orderId
        );

        emit OrderCanceled(
            idToOrder[orderId].nftContract,
            idToOrder[orderId].orderId,
            idToOrder[orderId].tokenId,
            address(0),
            msg.sender,
            idToOrder[orderId].price,
            idToOrder[orderId].buyWithTokenContract,
            false,
            true,
            false
        );
    }

    /* Creates the sale of a marketplace order */
    /* Transfers ownership of the order, as well as funds between parties */
    function createSale(uint256 orderId) public nonReentrant {
        require(idToOrder[orderId].sold == false, "Sold item");
        require(idToOrder[orderId].cancel == false, "Canceled item");
        require(idToOrder[orderId].listed == true, "Listed item");
        // require(idToOrder[orderId].seller != msg.sender);

        uint256 price = idToOrder[orderId].price;
        uint256 tokenId = idToOrder[orderId].tokenId;
        address buyWithTokenContract = idToOrder[orderId].buyWithTokenContract;
        uint256 balance = IERC20(buyWithTokenContract).balanceOf(msg.sender);
        uint256 fee = (price * feesRate) / 10000;
        uint256 amount = price - fee;
        // uint256 totalAmount = price + fee;
        address nftContract = idToOrder[orderId].nftContract;

        require(
            balance >= price,
            "Your balance has not enough amount + including fee."
        );

        //Transfer fee to platform.
        IERC20(buyWithTokenContract).transferFrom(
            msg.sender,
            address(this),
            fee
        );

        //Transfer token(BUSD) to nft seller.
        IERC20(buyWithTokenContract).transferFrom(
            msg.sender,
            idToOrder[orderId].seller,
            amount
        );

        // idToOrder[orderId].seller.transfer(msg.value);
        NFT_POOL(nftPool).transferNFT(
            idToOrder[orderId].nftContract,
            msg.sender,
            tokenId
        );

        IERC721(nftContract).updateOwner(tokenId, msg.sender, price);

        idToOrder[orderId].owner = msg.sender;
        idToOrder[orderId].sold = true;
        idToOrder[orderId].listed = false;

        emit OrderSuccessful(
            nftContract,
            orderId,
            tokenId,
            address(0),
            msg.sender,
            price,
            buyWithTokenContract,
            false,
            true,
            false
        );
    }

    /* tranfer to owner address*/
    function _tranfertoOwner(
        address _tokenAddress,
        address _receiver,
        uint256 _amount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(
            balance >= _amount,
            "Your balance has not enough amount totranfer."
        );

        IERC20(_tokenAddress).transfer(_receiver, _amount);
    }

    function transferERC20(
        address _contractAddress,
        address _to,
        uint256 _amount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 _token = IERC20(_contractAddress);
        _token.transfer(_to, _amount);
    }
}
