#!/bin/bash

result=`cast abi-encode "constructor(string,string)" "ZZL token" "ZLT"`

echo $result

# forge create --rpc-url sepolia --account timzhang0523  src/myToken.sol:MyToken  --constructor-args $result

# forge v --chain sepolia 0x571A332E0fE64a784Cfa8129c06799206341f4aC src/myToken.sol:MyToken  --constructor-args 

# deploy and verify contract for forge scrit
# forge script script/Mytoken.s.sol:DeployToken --account timzhang0523 --rpc-url sepolia --broadcast -vvv
# forge script script/NFT.s.sol:MyScript --chain-id $CHAIN_ID --rpc-url sepolia --account timzhang0523 --etherscan-api-key $ETHERSCAN_API --broadcast --verify -vvvv
