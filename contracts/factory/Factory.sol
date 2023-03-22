pragma solidity 0.4.24;

import "../utils/OwnableContract.sol";
import "../controller/ControllerInterface.sol";


contract Factory is OwnableContract {

    enum RequestStatus {PENDING, CANCELED, APPROVED, REJECTED}

    struct Request {
        address requester; // sender of the request.
        uint amount; // amount of wghost to mint/burn.
        bytes32 ghostDepositAddress; // custodian's ghost address in mint, merchant's ghost address in burn.
        bytes32 ghostTxid; // ghost txid for sending/redeeming ghost in the mint/burn process.
        uint nonce; // serial number allocated for each request.
        uint timestamp; // time of the request creation.
        RequestStatus status; // status of the request.
    }

    ControllerInterface public controller;

    // mapping between merchant to the corresponding custodian deposit address, used in the minting process.
    // by using a different deposit address per merchant the custodian can identify which merchant deposited.
    mapping(address=>bytes32) public custodianGhostDepositAddress;

    // mapping between merchant to the its deposit address where ghost should be moved to, used in the burning process.
    mapping(address=>bytes32) public merchantGhostDepositAddress;

    // mapping between a mint request hash and the corresponding request nonce. 
    mapping(bytes32=>uint) public mintRequestNonce;

    // mapping between a burn request hash and the corresponding request nonce.
    mapping(bytes32=>uint) public burnRequestNonce;

    Request[] public mintRequests;
    Request[] public burnRequests;

    constructor(ControllerInterface _controller) public {
        require(_controller != address(0), "invalid _controller address");
        controller = _controller;
        owner = _controller;
    }

    modifier onlyMerchant() {
        require(controller.isMerchant(msg.sender), "sender not a merchant.");
        _;
    }

    modifier onlyCustodian() {
        require(controller.isCustodian(msg.sender), "sender not a custodian.");
        _;
    }

    event CustodianGhostDepositAddressSet(address indexed merchant, address indexed sender, bytes32 ghostDepositAddress);

    function setCustodianGhostDepositAddress(
        address merchant,
        bytes32 ghostDepositAddress
    )
        external
        onlyCustodian
        returns (bool) 
    {
        require(merchant != 0, "invalid merchant address");
        require(controller.isMerchant(merchant), "merchant address is not a real merchant.");
        require(!isEmptyString(ghostDepositAddress), "invalid ghost deposit address");

        custodianGhostDepositAddress[merchant] = ghostDepositAddress;
        emit CustodianGhostDepositAddressSet(merchant, msg.sender, ghostDepositAddress);
        return true;
    }

    event MerchantGhostDepositAddressSet(address indexed merchant, bytes32 ghostDepositAddress);

    function setMerchantGhostDepositAddress(bytes32 ghostDepositAddress) external onlyMerchant returns (bool) {
        require(!isEmptyString(ghostDepositAddress), "invalid ghost deposit address");

        merchantGhostDepositAddress[msg.sender] = ghostDepositAddress;
        emit MerchantGhostDepositAddressSet(msg.sender, ghostDepositAddress);
        return true; 
    }

    event MintRequestAdd(
        uint indexed nonce,
        address indexed requester,
        uint amount,
        bytes32 ghostDepositAddress,
        bytes32 ghostTxid,
        uint timestamp,
        bytes32 requestHash
    );

    function addMintRequest(
        uint amount,
        bytes32 ghostTxid,
        bytes32 ghostDepositAddress
    )
        external
        onlyMerchant
        returns (bool)
    {
        require(!isEmptyString(ghostDepositAddress), "invalid ghost deposit address"); 
        require(compareStrings(ghostDepositAddress, custodianGhostDepositAddress[msg.sender]), "wrong ghost deposit address");

        uint nonce = mintRequests.length;
        uint timestamp = getTimestamp();

        Request memory request = Request({
            requester: msg.sender,
            amount: amount,
            ghostDepositAddress: ghostDepositAddress,
            ghostTxid: ghostTxid,
            nonce: nonce,
            timestamp: timestamp,
            status: RequestStatus.PENDING
        });

        bytes32 requestHash = calcRequestHash(request);
        mintRequestNonce[requestHash] = nonce; 
        mintRequests.push(request);

        emit MintRequestAdd(nonce, msg.sender, amount, ghostDepositAddress, ghostTxid, timestamp, requestHash);
        return true;
    }

    event MintRequestCancel(uint indexed nonce, address indexed requester, bytes32 requestHash);

    function cancelMintRequest(bytes32 requestHash) external onlyMerchant returns (bool) {
        uint nonce;
        Request memory request;

        (nonce, request) = getPendingMintRequest(requestHash);

        require(msg.sender == request.requester, "cancel sender is different than pending request initiator");
        mintRequests[nonce].status = RequestStatus.CANCELED;

        emit MintRequestCancel(nonce, msg.sender, requestHash);
        return true;
    }

    event MintConfirmed(
        uint indexed nonce,
        address indexed requester,
        uint amount,
        bytes32 ghostDepositAddress,
        bytes32 ghostTxid,
        uint timestamp,
        bytes32 requestHash
    );

    function confirmMintRequest(bytes32 requestHash) external onlyCustodian returns (bool) {
        uint nonce;
        Request memory request;

        (nonce, request) = getPendingMintRequest(requestHash);

        mintRequests[nonce].status = RequestStatus.APPROVED;
        require(controller.mint(request.requester, request.amount), "mint failed");

        emit MintConfirmed(
            request.nonce,
            request.requester,
            request.amount,
            request.ghostDepositAddress,
            request.ghostTxid,
            request.timestamp,
            requestHash
        );
        return true;
    }

    event MintRejected(
        uint indexed nonce,
        address indexed requester,
        uint amount,
        bytes32 ghostDepositAddress,
        bytes32 ghostTxid,
        uint timestamp,
        bytes32 requestHash
    );

    function rejectMintRequest(bytes32 requestHash) external onlyCustodian returns (bool) {
        uint nonce;
        Request memory request;

        (nonce, request) = getPendingMintRequest(requestHash);

        mintRequests[nonce].status = RequestStatus.REJECTED;

        emit MintRejected(
            request.nonce,
            request.requester,
            request.amount,
            request.ghostDepositAddress,
            request.ghostTxid,
            request.timestamp,
            requestHash
        );
        return true;
    }

    event Burned(
        uint indexed nonce,
        address indexed requester,
        uint amount,
        bytes32 ghostDepositAddress,
        uint timestamp,
        bytes32 requestHash
    );

    function burn(uint amount) external onlyMerchant returns (bool) {
        bytes32 memory ghostDepositAddress = merchantGhostDepositAddress[msg.sender];
        require(!isEmptyString(ghostDepositAddress), "merchant ghost deposit address was not set"); 

        uint nonce = burnRequests.length;
        uint timestamp = getTimestamp();

        // set txid as empty since it is not known yet.
        bytes32 memory ghostTxid = "";

        Request memory request = Request({
            requester: msg.sender,
            amount: amount,
            ghostDepositAddress: ghostDepositAddress,
            ghostTxid: ghostTxid,
            nonce: nonce,
            timestamp: timestamp,
            status: RequestStatus.PENDING
        });

        bytes32 requestHash = calcRequestHash(request);
        burnRequestNonce[requestHash] = nonce; 
        burnRequests.push(request);

        require(controller.getWGhost().transferFrom(msg.sender, controller, amount), "trasnfer tokens to burn failed");
        require(controller.burn(amount), "burn failed");

        emit Burned(nonce, msg.sender, amount, ghostDepositAddress, timestamp, requestHash);
        return true;
    }

    event BurnConfirmed(
        uint indexed nonce,
        address indexed requester,
        uint amount,
        bytes32 ghostDepositAddress,
        bytes32 ghostTxid,
        uint timestamp,
        bytes32 inputRequestHash
    );

    function confirmBurnRequest(bytes32 requestHash, bytes32 ghostTxid) external onlyCustodian returns (bool) {
        uint nonce;
        Request memory request;

        (nonce, request) = getPendingBurnRequest(requestHash);

        burnRequests[nonce].ghostTxid = ghostTxid;
        burnRequests[nonce].status = RequestStatus.APPROVED;
        burnRequestNonce[calcRequestHash(burnRequests[nonce])] = nonce;

        emit BurnConfirmed(
            request.nonce,
            request.requester,
            request.amount,
            request.ghostDepositAddress,
            ghostTxid,
            request.timestamp,
            requestHash
        );
        return true;
    }

    function getMintRequest(uint nonce)
        external
        view
        returns (
            uint requestNonce,
            address requester,
            uint amount,
            bytes32 ghostDepositAddress,
            bytes32 ghostTxid,
            uint timestamp,
            bytes32 status,
            bytes32 requestHash
        )
    {
        Request memory request = mintRequests[nonce];
        bytes32 memory statusString = getStatusString(request.status); 

        requestNonce = request.nonce;
        requester = request.requester;
        amount = request.amount;
        ghostDepositAddress = request.ghostDepositAddress;
        ghostTxid = request.ghostTxid;
        timestamp = request.timestamp;
        status = statusString;
        requestHash = calcRequestHash(request);
    }

    function getMintRequestsLength() external view returns (uint length) {
        return mintRequests.length;
    }

    function getBurnRequest(uint nonce)
        external
        view
        returns (
            uint requestNonce,
            address requester,
            uint amount,
            bytes32 ghostDepositAddress,
            bytes32 ghostTxid,
            uint timestamp,
            bytes32 status,
            bytes32 requestHash
        )
    {
        Request storage request = burnRequests[nonce];
        bytes32 memory statusString = getStatusString(request.status); 

        requestNonce = request.nonce;
        requester = request.requester;
        amount = request.amount;
        ghostDepositAddress = request.ghostDepositAddress;
        ghostTxid = request.ghostTxid;
        timestamp = request.timestamp;
        status = statusString;
        requestHash = calcRequestHash(request);
    }

    function getBurnRequestsLength() external view returns (uint length) {
        return burnRequests.length;
    }

    function getTimestamp() internal view returns (uint) {
        // timestamp is only used for data maintaining purpose, it is not relied on for critical logic.
        return block.timestamp; // solhint-disable-line not-rely-on-time
    }

    function getPendingMintRequest(bytes32 requestHash) internal view returns (uint nonce, Request memory request) {
        require(requestHash != 0, "request hash is 0");
        nonce = mintRequestNonce[requestHash];
        request = mintRequests[nonce];
        validatePendingRequest(request, requestHash);
    }

    function getPendingBurnRequest(bytes32 requestHash) internal view returns (uint nonce, Request memory request) {
        require(requestHash != 0, "request hash is 0");
        nonce = burnRequestNonce[requestHash];
        request = burnRequests[nonce];
        validatePendingRequest(request, requestHash);
    }

    function validatePendingRequest(Request memory request, bytes32 requestHash) internal pure {
        require(request.status == RequestStatus.PENDING, "request is not pending");
        require(requestHash == calcRequestHash(request), "given request hash does not match a pending request");
    }

    function calcRequestHash(Request request) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            request.requester,
            request.amount,
            request.ghostDepositAddress,
            request.ghostTxid,
            request.nonce,
            request.timestamp
        ));
    }

    function compareStrings (bytes32 a, bytes32 b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }

    function isEmptyString (bytes32 a) internal pure returns (bool) {
        return (compareStrings(a, ""));
    }

    function getStatusString(RequestStatus status) internal pure returns (bytes32) {
        if (status == RequestStatus.PENDING) {
            return "pending";
        } else if (status == RequestStatus.CANCELED) {
            return "canceled";
        } else if (status == RequestStatus.APPROVED) {
            return "approved";
        } else if (status == RequestStatus.REJECTED) {
            return "rejected";
        } else {
            // this fallback can never be reached.
            return "unknown";
        }
    }
}
