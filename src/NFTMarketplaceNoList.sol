
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketplaceNoList is Ownable(msg.sender), EIP712("OpenSpaceNFTMarket", "1") {
    address public constant ETH_FLAG = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 public constant feeBP = 30; // 30/10000 = 0.3%
    address public whiteListSigner;
    address public feeTo; 
    mapping(bytes32 => bool) public isListed; // orderid

    mapping(address => mapping(uint256 => bytes32)) private _lastIds; //  nft -> lastOrderId
    bytes32 public constant LISTING_TYPEHASH = keccak256("sellOrder(address seller,address nft,uint256 tokenId,address payToken,uint256 price,uint256 deadline)");

    struct SellOrder {
        address seller;
        address nft;
        uint256 tokenId;
        address payToken;
        uint256 price;
        uint256 deadline;
    }

    // function listing(address nft, uint256 tokenId) external view returns (bytes32) {
    //     bytes32 id = _lastIds[nft][tokenId];
    //     return listingOrders[id].seller == address(0) ? bytes32(0x00) : id;
    // }

    // function list(address nft, uint256 tokenId, address payToken, uint256 price, uint256 deadline) external {
    //     require(deadline > block.timestamp, "MKT: deadline is in the past");
    //     require(price > 0, "MKT: price is zero");
    //     require(payToken == address(0) || IERC20(payToken).totalSupply() > 0, "MKT: payToken is not valid");

    //     // safe check
    //     require(IERC721(nft).ownerOf(tokenId) == msg.sender, "MKT: not owner");
    //     require(
    //         IERC721(nft).getApproved(tokenId) == address(this)
    //             || IERC721(nft).isApprovedForAll(msg.sender, address(this)),
    //         "MKT: not approved"
    //     );

    //     SellOrder memory order = SellOrder({
    //         seller: msg.sender,
    //         nft: nft,
    //         tokenId: tokenId,
    //         payToken: payToken,
    //         price: price,
    //         deadline: deadline
    //     });

    //     bytes32 orderId = keccak256(abi.encode(order));
    //     // safe check repeat list
    //     require(listingOrders[orderId].seller == address(0), "MKT: order already listed");
    //     listingOrders[orderId] = order;
    //     _lastIds[nft][tokenId] = orderId; // reset
    //     emit List(nft, tokenId, orderId, msg.sender, payToken, price, deadline);
    // }
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
    function cancel(SellOrder calldata order) external {
        // safe check repeat list
        require(order.seller != address(0), "MKT: order not listed");
        require(order.seller == msg.sender, "MKT: only seller can cancel");
        bytes32 orderId = hashBuyWithList(order);
        isListed[orderId] = true; // meanings that orderId deleted.
        emit Cancel(orderId,true);
    }

    function buyWithETH(bytes calldata signature,SellOrder calldata sellOrder) public payable {
        _buy(signature,sellOrder, feeTo);
    }

    function buy(bytes calldata signature,SellOrder calldata order) external payable {
        // _checkList(order);
        _buy(signature,order, address(0));
    }

    function _buy(bytes calldata signature,SellOrder calldata order, address feeReceiver) private {
        // 1. check
        require(order.seller != address(0), "MKT: order not listed");
        require(order.deadline > block.timestamp, "MKT: order expired");
        // check on list whether or not~
        _checkList(order,signature);
        // 3. trasnfer NFT
        IERC721(order.nft).safeTransferFrom(order.seller, msg.sender, order.tokenId);

        // 4. trasnfer token
        // fee 0.3% or 0
        uint256 fee = feeReceiver == address(0) ? 0 : order.price * feeBP / 10000;
        // safe check
        if (order.payToken == ETH_FLAG) {
            require(msg.value == order.price, "MKT: wrong eth value");
        } else {
            require(msg.value == 0, "MKT: wrong eth value");
        }
        _transferOut(order.payToken, order.seller, order.price - fee);
        if (fee > 0) _transferOut(order.payToken, feeReceiver, fee);
        emit Sold(msg.sender, fee,order);
    }

    function _transferOut(address token, address to, uint256 amount) private {
        if (token == ETH_FLAG) {
            // eth
            (bool success,) = to.call{value: amount}("");
            require(success, "MKT: transfer failed");
        } else {
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, to, amount);
        }
    }

    // check list info
    function _checkList(SellOrder calldata sellOrder,bytes calldata signature) private view {
        // check whiteListSigner for buyer
        bytes32 listHash = _hashTypedDataV4(keccak256(abi.encode(LISTING_TYPEHASH, 
            sellOrder.seller,
            sellOrder.nft,
            sellOrder.tokenId,
            sellOrder.payToken,
            sellOrder.price,
            sellOrder.deadline
            )));
        require(isListed[listHash] == false, "MKT: orderId already matched or deleted!");
        address signer = ECDSA.recover(listHash, signature);
        require(signer == sellOrder.seller, "MKT: not seller listing");
        isListed[listHash] == true;
    }

    function hashBuyWithList(SellOrder calldata sellOrder) public view returns(bytes32){
     return _hashTypedDataV4(keccak256(abi.encode(LISTING_TYPEHASH, 
                sellOrder.seller,
                sellOrder.nft,
                sellOrder.tokenId,
                sellOrder.payToken,
                sellOrder.price,
                sellOrder.deadline
            )));
    }

    function setFeeTo(address to) external onlyOwner {
        require(feeTo != to, "MKT:repeat set");
        feeTo = to;

        emit SetFeeTo(to);
    }

    event List(
        address indexed nft,
        uint256 indexed tokenId,
        bytes32 orderId,
        address seller,
        address payToken,
        uint256 price,
        uint256 deadline
    );
    event Cancel(bytes32 orderId,bool isListed);
    event Sold(address indexed buyer, uint256 fee,SellOrder order);
    event SetFeeTo(address to);
    event SetWhiteListSigner(address signer);
}