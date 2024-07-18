// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NFTMarketPermit is EIP712 {
    using ECDSA for bytes32;

    struct Listing {
        address seller;
        uint256 price;
    }
    struct ERC20PermitData{
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }

    struct SellOrderWithSignature{
        address seller;
        address nft;
        uint256 tokenId;
        uint256 price;
        uint256 deadline;
        bytes signature;
    }

    error PaymentFailed(address buyer, address seller, uint256 price);
    error NotListedForSale(uint256 tokenId);
    error NotAllowed(address buyer, address seller, uint256 tokenId);

    

    IERC20 public token;
    IERC721 public nft;
    bytes32 public DOMAIN_SEPARATOR;

    mapping(uint256 => Listing) public listings;
    address public owner;
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event DownListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Purchased(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor(address tokenAddress, address nftAddress) EIP712("NFTMarketPermit", "1") {
        token = IERC20(tokenAddress);
        nft = IERC721(nftAddress);
        owner = msg.sender;       
    }
    function hashBuyWithWL(address user) public view returns(bytes32){
     return  _hashTypedDataV4(
            keccak256(
                abi.encode(
                    WL_TYPEHASH,
                    user
                )
            )
        );
    }
    // 上架 nft
    function list(uint256 tokenId, uint256 price) public {
        require(nft.ownerOf(tokenId) == msg.sender, "Only the owner can list the NFT");
        require(price > 0, "Price must be greater than zero");

        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price
        });

        nft.transferFrom(msg.sender, address(this), tokenId);

        emit Listed(tokenId, msg.sender, price);
    }
    // 下架
    function downlist(uint256 tokenId) public {
        
        Listing memory listing = listings[tokenId];

        require(listing.seller == msg.sender, "Only the owner can list the NFT");

        nft.transferFrom(address(this), msg.sender, tokenId);

        delete listings[tokenId];

        emit DownListed(tokenId, msg.sender, 0);
    }


    function getListing(uint256 tokenId) public view returns (address seller, uint256 price) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price);
    }

    bytes32 public constant WL_TYPEHASH = keccak256("BuyWithWL(address user)");
    bytes32 public constant LISTING_TYPEHASH = keccak256("sellOrder(address seller,address nft,uint256 tokenId,uint256 price,uint256 deadline)");
    address public constant WL_SIGNER = 0x328809Bc894f92807417D2dAD6b7C998c1aFdac6; // alice as master
    
    function buyPermitWithWLV1( 
        uint256 tokenId,
        bytes calldata signatureForWL,
        ERC20PermitData calldata approveData
    ) public {
        // 检查白单签名是否来自于项目方的签署
        // 执行 ERC20 的 permit 进行 授权
        // 执行 ERC20 的转账
        // 执行 NFT  的转账
        Listing memory listing = listings[tokenId];
        require(listing.price > 0, "This NFT is not for sale");
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    WL_TYPEHASH,
                    address(msg.sender)
                )
            )
        );
        address signerForWL = ECDSA.recover(
            digest, signatureForWL
        );
        require(
            signerForWL == WL_SIGNER ,
            "You are not in WL"
        );

        //verify ERC20 permit signature 
        IERC20Permit(address(token)).permit(
            msg.sender,
            address(this),
            listing.price,
            approveData.deadline,
            approveData.v,
            approveData.r,
            approveData.s
        );

        // Transfer the payment tokens from the buyer to the seller
        bool success = IERC20(address(token)).transferFrom(
                msg.sender,
                listing.seller,
                listing.price
            );
        
        if (!success) revert PaymentFailed(msg.sender, listing.seller, listing.price); 

        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        delete listings[tokenId];
        emit Purchased( tokenId,msg.sender, listing.price);

    }


    function buyPermitWithWLV2( 
        bytes calldata signatureForWL,
        ERC20PermitData calldata approveData,
        SellOrderWithSignature calldata sellOrder // sell order
    ) public {
        // 检查上架信息是否存在，「检查后为了防止重入，删除上架信息]
        // 检查白单签名是否来自于项目方的签署
        // 执行 ERC20 的 permit 进行 授权
        // 执行 ERC20 的转账
        // 执行 NFT  的转账
        require(sellOrder.deadline >= block.timestamp, "Signature expired");
        bytes32 orderHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    LISTING_TYPEHASH,
                    sellOrder.seller,
                    sellOrder.nft,
                    sellOrder.tokenId,
                    sellOrder.price,
                    sellOrder.deadline 
                )
            )
        );
    
        address nftOwner= IERC721(sellOrder.nft).ownerOf(sellOrder.tokenId);
        require(ECDSA.recover(orderHash,sellOrder.signature) == nftOwner,"Invalid signature");

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    WL_TYPEHASH,
                    address(msg.sender)
                )
            )
        );
        address signerForWL = ECDSA.recover(
            digest, signatureForWL
        );
        require(
            signerForWL == WL_SIGNER ,
            "You are not in WL"
        );
        

        //verify ERC20 permit signature 
        IERC20Permit(address(token)).permit(
            msg.sender,
            address(this),
            sellOrder.price,
            approveData.deadline,
            approveData.v,
            approveData.r,
            approveData.s
        );

        // Transfer the payment tokens from the buyer to the seller
        bool success = IERC20(address(token)).transferFrom(
                msg.sender,
                sellOrder.seller,
                sellOrder.price
            );
        
        if (!success) revert PaymentFailed(msg.sender, sellOrder.seller, sellOrder.price); 

        // seller must be approve the NFT transfer to this contract
        nft.safeTransferFrom(sellOrder.seller, msg.sender, sellOrder.tokenId);

        emit Purchased( sellOrder.tokenId,msg.sender, sellOrder.price);
    }
}