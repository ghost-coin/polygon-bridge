// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract WGhost is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;

    address public contractOwner;
    
    event WGhostMinted(address receiver, string ghostTxID, uint256 amount);
    event WGhostBurned(address burner, string ghostAddr, uint256 amount);

    mapping(address => bool) public approvedSigners;
    mapping(string => bool) public seenTxIDs;

    address[] public signers;

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC20_init("Wrapped Ghost", "WGhost");
        __Ownable_init();
        __UUPSUpgradeable_init();

        contractOwner = msg.sender;
        approvedSigners[contractOwner] = true;
        signers.push(contractOwner);  
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}


    function addTxID(string memory txid) internal { 
        require(!seenTxIDs[txid], "Transaction with the given ID already processed");
        seenTxIDs[txid] = true;
    }

    function addSigner(address newSigner) external onlyOwner {
        require(msg.sender == contractOwner, "Only contract owner can add a signer");
        require(newSigner != address(0), "Invalid signer address");
        require(!approvedSigners[newSigner], "Signer already added");

        approvedSigners[newSigner] = true;
        signers.push(newSigner);
    }

    function removeSigner(address signer) external onlyOwner {
        require(msg.sender == contractOwner, "Only contract owner can remove a signer");
        require(signer != contractOwner, "Cannot remove contract owner");
        require(approvedSigners[signer], "Signer is not approved");

        approvedSigners[signer] = false;

        // Remove the signer from the signers array
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
    }

    function getApprovedSigners() external view returns (address[] memory) {
        return signers;
    }

    function prefixedHash(bytes32 message) internal pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return keccak256(abi.encodePacked(prefix, message));
    }


    function mint(
        address receiver,
        uint256 amount,
        uint32 ghostBlockHeight,
        uint256 lockedGhostSupply,
        string memory ghostTXID,
        uint256 timestamp,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) external {
        require(v.length >= 1, "Insufficient signatures");
        require(
            v.length == r.length &&
            v.length == s.length,
            "Invalid input lengths"
        );

        bytes32 messageHash = keccak256(abi.encodePacked(
            address(uint160(receiver)), // eth address to receive tokens
            amount, // amount to be minted
            ghostBlockHeight, // uint32
            lockedGhostSupply, // uint32
            ghostTXID, // string
            timestamp // timestamp
        ));

        address[] memory recoveredAddresses = new address[](v.length);
        uint256 validSignatureCount = 0;
        bool ownerSignatureFound = false;

        for (uint256 i = 0; i < v.length; i++) {
            bytes32 msgHash = prefixedHash(messageHash);
            address recoveredAddress = ecrecover(msgHash, v[i], r[i], s[i]);
            // if (recoveredAddress == contractOwner) {
            //     ownerSignatureFound = true;
            // }
            for (uint256 j = 0; j < signers.length; j++) {
                if (recoveredAddress == signers[j]) {
                    recoveredAddresses[validSignatureCount] = recoveredAddress;
                    validSignatureCount++;
                    break;
                }
            }
        }

        // require(ownerSignatureFound, "Owner signature required");
        require(validSignatureCount >= 2, "Invalid signatures");

        require(totalSupply() + amount <= lockedGhostSupply, "Exceeded token limit");

        addTxID(ghostTXID);
        // Perform mint operation
        _mint(receiver, amount);
        emit WGhostMinted(receiver, ghostTXID, amount);
    }

    function burn(string memory ghostAddress, uint256 amount) external { 
        _burn(msg.sender, amount);
        emit WGhostBurned(msg.sender, ghostAddress, amount);
    }
}
