// SPDX-License-Identifier:  Multiverse Expert
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


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

interface INFT_CORE {
    function getRoyaltyInfo(
        uint256 _tokenId, uint256 _salePrice
    ) external view returns (address, uint256);
}

contract UNQSMarket is ReentrancyGuard, Pausable, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter public _orderIds;
    Counters.Counter public _auctionIds;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public auctionFees = 1000;
    uint256 public feesRate = 425;

    address public adminWallet;
    address public nftPool;
    INFT_CORE public nftCore;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /************************** Structs *********************/

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
    }

    struct Auction {
        address nftContract;
        uint256 auctionId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 startPrice;
        address buyWithTokenContract;
        bool started;
        bool ended;
        uint256 endAt;
        bool sold;
    }

    struct HighestBid {
        address highestBidder;
        uint256 bidAmount;
    }

    /************************** Mappings *********************/

    mapping(uint256 => Order) public idToOrder;
    mapping(uint256 => Auction) public idToAuction;
    mapping(uint256 => mapping(address => uint256)) public bidsToAuction;
    mapping(uint256 => HighestBid) public auctionHighestBid;
    mapping(address => bool) private isWhitelist;

    /************************** Events *********************/

    event OrderCreated(
        address nftContract,
        uint256 indexed orderId,
        uint256 tokenId,
        address seller,
        address owner,
        uint256 price,
        address buyWithTokenContract,
        bool listed,
        bool sold
    );

    event OrderCanceled(
        uint256 orderId,
        uint256 tokenId,
        address seller,
        address owner,
        bool listed
    );

    event OrderSuccessful(
        uint256 orderId,
        uint256 tokenId,
        address seller,
        address owner,
        bool listed,
        bool sold
    );

    event StartAuction(
        address nftContract,
        uint256 auctionId,
        uint256 tokenId,
        address seller,
        address owner,
        uint256 startPrice,
        address buyWithTokenContract,
        bool started,
        bool ended,
        uint256 endAt,
        bool sold
    );

    event Bid(uint256 auctionId, address indexed sender, uint256 amount);
    event End(uint256 auctionId, address winner, uint256 amount, bool ended);
    event Withdraw(address bidder, uint256 auctionId, uint256 amount);

    /******************* Setup Functions *********************/

    //@Admin if something happen Admin can call this function to pause txs
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

    function updateNFTCore(INFT_CORE _nftCore)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        nftCore = INFT_CORE(_nftCore);
    }

    //@Admin call to set whitelists
    function setWhitelist(address whitelistAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            !isWhitelist[whitelistAddress],
            "User already exist in whitelist"
        );
        isWhitelist[whitelistAddress] = true;
    }

    //@Admin call to update market fee
    function updateFeesRate(uint256 feeRate)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // feeAmount will be / by 10000
        // if you want 5% feeRate should be 500
        feesRate = feeRate;
    }

    //@Admin call to update market fee
    function updateAdminWallet(address _adminWallet)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // feeAmount will be / by 10000
        // if you want 5% feeRate should be 500
        adminWallet = _adminWallet;
    }

    //@Admin call to update auction fee
    function updateAuctionFeesRate(uint256 newRate)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newRate >= 500);
        auctionFees = newRate;
    }

    /*******************Read Functions *********************/

    // for frontend \\
    // Listing Items
    // Items info

    /******************* Buy/Sell/Cancel Functions *********************/

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
            false
        );

        // tranfer NFT ownership to Market contract
        IERC721(nftContract).safeTransferFrom(msg.sender, nftPool, tokenId);
        NFT_POOL(nftPool).depositNFT(nftContract, tokenId, msg.sender);

        emit OrderCreated(
            nftContract,
            orderId,
            tokenId,
            msg.sender,
            nftPool,
            price,
            buyWithTokenContract,
            true,
            false
        );
    }

    /* Seller call this to cancel placed order */
    function cancelOrder(uint256 orderId) public {
        require(!idToOrder[orderId].sold, "Sold item");
        require(idToOrder[orderId].listed, "Item is not listed");
        // check if the caller is seller
        require(idToOrder[orderId].seller == msg.sender);

        //Transfer back to the real owner.
        NFT_POOL(nftPool).transferNFT(
            idToOrder[orderId].nftContract,
            msg.sender,
            idToOrder[orderId].tokenId
        );

        //update mapping info
        idToOrder[orderId].owner = msg.sender;
        idToOrder[orderId].seller = address(0);
        idToOrder[orderId].listed = false;

        emit OrderCanceled(
            idToOrder[orderId].orderId,
            idToOrder[orderId].tokenId,
            address(0),
            msg.sender,
            false
        );
    }

    /* Creates the sale of a marketplace order */
    /* Transfers ownership of the order, as well as funds between parties */
    function buyOrder(uint256 orderId) public nonReentrant {
        require(!idToOrder[orderId].sold, "Status: Sold item");
        require(idToOrder[orderId].listed, "Status: It's not listed item");

        uint256 price = idToOrder[orderId].price;
        uint256 tokenId = idToOrder[orderId].tokenId;
        address buyWithTokenContract = idToOrder[orderId].buyWithTokenContract;

        (address creator ,uint256 royaltyFee) = nftCore.getRoyaltyInfo(tokenId, price);
        uint256 fee = (price * feesRate) / 10000;
        uint256 amount = (price - fee) - royaltyFee;

        //if not the whitelists, transfer fee to platform.
        if (!isWhitelist[msg.sender]) {
            IERC20(buyWithTokenContract).transferFrom(
                msg.sender,
                adminWallet,
                fee
            );
        }

        //transfer Royalty amount
        IERC20(buyWithTokenContract).transferFrom(
            msg.sender,
            creator,
            royaltyFee
        );

        //Transfer token to nft seller.
        IERC20(buyWithTokenContract).transferFrom(
            msg.sender,
            idToOrder[orderId].seller,
            amount
        );

        // call NFT pool to transfer the nft to buyer;
        NFT_POOL(nftPool).transferNFT(
            idToOrder[orderId].nftContract,
            msg.sender,
            tokenId
        );

        //update status of this orderId
        idToOrder[orderId].owner = msg.sender;
        idToOrder[orderId].sold = true;
        idToOrder[orderId].listed = false;

        emit OrderSuccessful(
            orderId,
            tokenId,
            address(0),
            msg.sender,
            false,
            true
        );
    }

    /******************* English Auction Functions *********************/

    //seller call this to start auction
    function startAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        address buyWithTokenContract,
        uint256 dateAmount
    ) external nonReentrant {
        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();

        //lock nft token to the pool
        IERC721(nftContract).transferFrom(msg.sender, nftPool, tokenId);

        //declare the end time.
        uint256 endAt = block.timestamp + dateAmount;
        //insert auction data to mapping
        idToAuction[auctionId] = Auction(
            nftContract,
            auctionId,
            tokenId,
            msg.sender,
            nftPool,
            startPrice,
            buyWithTokenContract,
            true,
            false,
            endAt,
            false
        );

        //the first bidder is auction creator
        auctionHighestBid[auctionId].highestBidder = msg.sender;
        //the first bid is start price
        auctionHighestBid[auctionId].bidAmount = startPrice;

        emit StartAuction(
            nftContract,
            auctionId,
            tokenId,
            msg.sender,
            nftPool,
            startPrice,
            buyWithTokenContract,
            true,
            false,
            endAt,
            false
        );
    }

    // bidder call this to bid
    function bid(uint256 auctionId, uint256 bidAmount) external {
        address buyWithTokenContract = idToAuction[auctionId]
            .buyWithTokenContract;
        uint256 highestBid = auctionHighestBid[auctionId].bidAmount;

        require(idToAuction[auctionId].started, "not started");
        require(block.timestamp < idToAuction[auctionId].endAt, "ended");
        require(bidAmount > highestBid, "bid amount < highest");

        if (msg.sender != address(0)) {
            //calculate left amount
            uint256 transferAmount;
            if (bidsToAuction[auctionId][msg.sender] > 0) {
                transferAmount =
                    bidAmount -
                    bidsToAuction[auctionId][msg.sender];
            } else {
                transferAmount = bidAmount;
            }
            //transfer amount of bid to this contract
            IERC20(buyWithTokenContract).transferFrom(
                msg.sender,
                address(this),
                transferAmount
            );
            // user's lastest bid will always be the highest
            bidsToAuction[auctionId][msg.sender] = bidAmount;
            // Put the hihest bid to mapping
            auctionHighestBid[auctionId].bidAmount = bidAmount;
            auctionHighestBid[auctionId].highestBidder = msg.sender;
        }
        emit Bid(auctionId, msg.sender, bidAmount);
    }

    //seller or winner call this to claim their item/eth
    function end(uint256 auctionId) external nonReentrant {
        require(idToAuction[auctionId].started, "not started");
        require(
            block.timestamp >= idToAuction[auctionId].endAt,
            "Auction's not past end date"
        );
        require(!idToAuction[auctionId].ended, "Auction's already ended");

        //the last bidder is always the highest one.
        uint256 highestBid = auctionHighestBid[auctionId].bidAmount;
        address highestBidder = auctionHighestBid[auctionId].highestBidder;
        address seller = idToAuction[auctionId].seller;
        address buyWithTokenContract = idToAuction[auctionId]
            .buyWithTokenContract;
        uint256 fee = (highestBid * auctionFees) / 10000;
        uint256 transferAmount = highestBid - fee;

        if (highestBidder != address(0)) {
            //transfer nft to winner
            NFT_POOL(nftPool).transferNFT(
                idToAuction[auctionId].nftContract,
                highestBidder,
                idToAuction[auctionId].tokenId
            );
            if (!isWhitelist[msg.sender]) {
                // tranfer winner's bid to seller
                IERC20(buyWithTokenContract).transfer(seller, transferAmount);
            } else {
                IERC20(buyWithTokenContract).transfer(seller, highestBid);
            }
        } else {
            //transfer nft to seller if no winner
            NFT_POOL(nftPool).transferNFT(
                idToAuction[auctionId].nftContract,
                seller,
                idToAuction[auctionId].tokenId
            );
        }

        idToAuction[auctionId].ended = true;

        emit End(auctionId, highestBidder, highestBid, true);
    }

    function bidderWithdraw(uint256 auctionId) external nonReentrant {
        require(
            block.timestamp >= idToAuction[auctionId].endAt,
            "Auction's not past end date"
        );
        require(!idToAuction[auctionId].ended, "Auction's already ended");
        address buyWithTokenContract = idToAuction[auctionId]
            .buyWithTokenContract;
        uint256 transferAmount = bidsToAuction[auctionId][msg.sender];
        address highestBidder = auctionHighestBid[auctionId].highestBidder;
        require(msg.sender != highestBidder, "Highest Bidder can't withdraw");

        IERC20(buyWithTokenContract).transfer(msg.sender, transferAmount);

        emit Withdraw(msg.sender, auctionId, transferAmount);
    }

    /******************* MUST_HAVE Functions *********************/

    /* tranfer to owner address*/
    function transferERC20(
        address _contractAddress,
        address _to,
        uint256 _amount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 _token = IERC20(_contractAddress);
        _token.transfer(_to, _amount);
    }
}
