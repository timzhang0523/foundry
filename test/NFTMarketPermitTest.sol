// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,Vm,console} from "forge-std/Test.sol";
import {ERC721Mock} from "../src/MockERC721.sol";
import {ZLERC20Permit} from "../src/ZLERC20Permit.sol";
import {NFTMarketPermit} from "../src/NFTMarketPermit.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract NFTMarketPermitTest is Test {
    NFTMarketPermit public nftMarket;
    ZLERC20Permit public erc20;
    ERC721Mock public erc721;
    uint256 public private_key ;
    address public alice; // as master
    address public jack;
    uint256 public privateKeyJack;
    uint public price = 10 ether;
    uint256 public deadline;
    address public bob = makeAddr("bob");

    address public otherBuyer = address(0x1234);
    error ERC721InvalidOperator(address to );
    error ERC721InsufficientApproval(address to,uint);
    error ERC20InsufficientBalance(address spender, uint currentAllowance, uint value);

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Purchased(uint256 indexed tokenId, address indexed buyer, uint256 price);
    // constructor(address(erc20),address(erc721)) NFTMarketPermit(_tokenAddress, _nftAddress) {}

    function setUp() public {
        (alice,private_key) = makeAddrAndKey("alice"); // seller
        (jack,privateKeyJack) = makeAddrAndKey("jack"); // buyer 
        erc20 = new ZLERC20Permit();
        erc721 = new ERC721Mock("zhanglu","zl");
        deadline = block.timestamp + 2 days;
        nftMarket = new NFTMarketPermit(address(erc20),address(erc721)); 
        deal(address(erc20),alice, 1e9 ether);
        deal(address(erc20),jack, 1e5 ether);
    }
    /**
        测试nFT上架
     */
    function testList(uint _price) public {
        // 先铸造nft
        uint256 tokenId = erc721.mint(alice);
        assertEq(erc721.ownerOf(tokenId), alice);
        // deal(address(erc20),alice, 1e9 ether);
        vm.startPrank(alice); 
        vm.assume(_price > 0 && _price < 1e9 ether);
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.isApprovedForAll(alice,address(nftMarket)), true,"emitted approved all  mismatch");
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        vm.expectEmit(true, true, false, true);
        emit Listed(tokenId,alice,_price);
        nftMarket.list(tokenId, _price);
        vm.stopPrank();
        assertEq(erc721.balanceOf(address(nftMarket)), 1);
        assertEq(erc721.ownerOf(tokenId), address(nftMarket));
    }

    function signWL(address user) private returns(bytes memory){
        bytes32 digest = nftMarket.hashBuyWithWL(user); 
       (uint8 v, bytes32 r, bytes32 s) =vm.sign(private_key, digest); // alice's private_key
       return abi.encodePacked(r,s,v);
    }  
    // 购买NFT成功
    function testBuyPermitWithV1() public {
        uint256 tokenId = erc721.mint(bob);
        // uint256 deadline = block.timestamp + 2 hours;
        assertEq(erc721.ownerOf(tokenId), bob);
        // deal(address(erc20),alice, 1e9 ether);
        vm.startPrank(bob); 
        // uint price = 10 ether;
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.isApprovedForAll(bob,address(nftMarket)), true,"emitted approved all  mismatch");
        assertEq(erc721.ownerOf(tokenId),bob,"emitted owner  mismatch");
        vm.expectEmit(true, true, false, true);
        emit Listed(tokenId,bob,price);
        nftMarket.list(tokenId, price);
        vm.stopPrank();
        
        vm.startPrank(jack); 
        (,uint _price) = nftMarket.getListing(tokenId);
        vm.assume(_price > 0);
        // 先签名用户的白名单
        bytes memory signatureWL = signWL(jack);
        
        assertEq(signatureWL.length,65,"signature mismatch");

        uint256 nonce = erc20.nonces(jack);
        // 然后在验证 eip712
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                jack,
                address(nftMarket),
                price,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                erc20.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyJack, digest);
        NFTMarketPermit.ERC20PermitData memory approveData = NFTMarketPermit.ERC20PermitData({
            v: v,
            r: r,
            s: s,
            deadline: deadline
        });
        vm.expectEmit(true, true, false, true);
        emit Purchased(tokenId,jack,_price);
        nftMarket.buyPermitWithWLV1(tokenId,signatureWL, approveData);
        vm.stopPrank();

        assertEq(erc721.ownerOf(tokenId), jack);
        // 检查上架的商品是否清空
        (address _seller,uint _price1) = nftMarket.getListing(tokenId);
        assertEq(_seller, address(0),"mismatch 1111");
        assertEq(_price1, 0,"mismatch 2222");

    }

    function testBuyPermitWithV2() public {
        uint256 tokenId = erc721.mint(bob);
        // uint256 deadline = block.timestamp + 2 hours;
        assertEq(erc721.ownerOf(tokenId), bob);
        // deal(address(erc20),alice, 1e9 ether);
        vm.startPrank(bob); 
        // uint price = 10 ether;
        // 测试是否授权
        bytes memory signatureListing = _getListingSignature();

        NFTMarketPermit.SellOrderWithSignature memory SellOrder = NFTMarketPermit.SellOrderWithSignature({
            seller:bob,
            nft:address(erc721),
            tokenId:tokenId,
            price:price,
            signature: signatureListing,
            deadline:deadline
        });
    
        vm.stopPrank();
        vm.startPrank(jack); 
        
        // 先签名用户的白名单
        bytes memory signatureWL = signWL(jack);
        
        assertEq(signatureWL.length,65,"signature mismatch");

        uint256 nonce = erc20.nonces(jack);
        // 然后在验证 eip712
        
        bytes memory signatureERC20 = _getERC20Signature();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyJack, digest);
        NFTMarketPermit.ERC20PermitData memory approveData = NFTMarketPermit.ERC20PermitData({
            v: v,
            r: r,
            s: s,
            deadline: deadline
        });
        vm.expectEmit(true, true, false, true);
        emit Purchased(tokenId,jack,price);
        nftMarket.buyPermitWithWLV2(signatureWL, approveData,SellOrder);
        vm.stopPrank();

        assertEq(erc721.ownerOf(tokenId), jack);
        // 检查上架的商品是否清空
        (address _seller,uint _price1) = nftMarket.getListing(tokenId);
        assertEq(_seller, address(0),"mismatch 1111");
        assertEq(_price1, 0,"mismatch 2222");

    }

    function _getERC20Signature() private view returns (bytes memory){
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                jack,
                address(nftMarket),
                price,
                erc20.nonces(jack),
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                erc20.DOMAIN_SEPARATOR(),
                structHash
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyJack, digest);
        return abi.encodePacked(r,s,v);
    }

    function _getListingSignature() private view returns (bytes memory){
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.LISTING_TYPEHASH,
                bob,
                address(erc721),
                price,
                erc721.nonces(bob),
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                nftMarket.DOMAIN_SEPARATOR(),
                structHash
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(private_key, digest);
        return abi.encodePacked(r,s,v);
    }
    


}