// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/WGhost.sol";

contract TestCustomMintableToken {
    CustomMintableToken token;
    address[] signers;

    function beforeEach() public {
        token = new CustomMintableToken();
        signers = new address[](6);

        for (uint256 i = 0; i < 6; i++) {
            signers[i] = address(i + 1);
            token.approvedSigners(signers[i]) = true;
        }
    }

    function testMint() public {
        // Generate the data for minting
        address[] memory data = new address[](6);
        uint8[] memory v = new uint8[](6);
        bytes32[] memory r = new bytes32[](6);
        bytes32[] memory s = new bytes32[](6);

        data[0] = address(this); // Receiver address
        data[1] = 100; // Amount to be minted
        data[2] = 42; // uint32
        data[3] = 10; // uint32
        data[4] = "someTxId"; // string
        data[5] = block.timestamp; // timestamp

        bytes32 messageHash = keccak256(abi.encodePacked(
            address(uint160(data[0])), // eth address to receive tokens
            uint256(data[1]), // amount to be minted
            uint32(data[2]), // uint32
            uint32(data[3]), // uint32
            string(data[4]), // string
            uint256(data[5]) // timestamp
        ));

        for (uint256 i = 0; i < 6; i++) {
            (v[i], r[i], s[i]) = signMessage(messageHash, signers[i]);
        }

        // Call the mint function
        token.mint(data, v, r, s);

        // Verify the minted tokens and other operations if needed
        // ...
    }

    function signMessage(bytes32 messageHash, address signer) private returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 signedMessage = messageHash.toEthSignedMessageHash();
        (v, r, s) = signedMessage.recover(abi.encodePacked(signer));
    }
}
