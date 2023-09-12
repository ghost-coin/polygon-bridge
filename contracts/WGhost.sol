// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract WrappedGhost is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;

    address public contractOwner;
    
    uint32 public bridgeMin;
    
    event WGhostMinted(address receiver, string ghostTxID, uint256 amount);
    event WGhostBurned(address burner, string ghostAddr, uint256 amount);

    mapping(address => bool) public approvedSigners;
    mapping(string => bool) public seenTxIDs;

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __ERC20_init("Wrapped Ghost", "WGhost");
        __Ownable_init();
        __UUPSUpgradeable_init();

        contractOwner = msg.sender;
        approvedSigners[contractOwner] = true;
        bridgeMin = 35;
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
    }

    function removeSigner(address signer) external onlyOwner {
        require(msg.sender == contractOwner, "Only contract owner can remove a signer");
        require(signer != contractOwner, "Cannot remove contract owner");
        require(approvedSigners[signer], "Signer is not approved");

        approvedSigners[signer] = false;

    }

    function updateBridgeMin(uint32 newBridgeMin) external onlyOwner {
        require(msg.sender == contractOwner, "Only contract owner can update bridge min");
        bridgeMin = newBridgeMin;
    } 
    
    function prefixedHash(bytes32 message) internal pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return keccak256(abi.encodePacked(prefix, message));
    }


    function mint(
        address receiver,
        uint256 amount,
        string memory ghostTXID,
        uint256 timestamp,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {

        require(approvedSigners[msg.sender], "Mint must be called by approved signer");

        bytes32 messageHash = keccak256(abi.encodePacked(
            address(uint160(receiver)), // eth address to receive tokens
            amount, // amount to be minted
            ghostTXID, // string
            timestamp // timestamp
        ));

        bytes32 msgHash = prefixedHash(messageHash);
        address recoveredAddress = ecrecover(msgHash, v, r, s);
        
        require(approvedSigners[recoveredAddress], "Invalid Signature");


        addTxID(ghostTXID);
        // Perform mint operation
        _mint(receiver, amount);
        emit WGhostMinted(receiver, ghostTXID, amount);
    }

    function burn(string memory ghostAddress, uint256 amount) external {
        require(amount < bridgeMin, "Amount below min bridge amount."); 
        _burn(msg.sender, amount);
        emit WGhostBurned(msg.sender, ghostAddress, amount);
    }
}
