// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IVenuePolicy} from "./interfaces/IVenuePolicy.sol";

interface IRetiredClaus {
    function balanceOf(address) external view returns(uint256);
    function totalSupply() external view returns(uint256);
    function transferFrom(address,address,uint256) external returns(bool);
    function burn(uint256) external;
}

/// @notice Pre-funded migration reserve. Burn receipts release existing tokens;
/// only the separately disclosed owner-mint function increases total supply.
contract MigrationToken is ERC20Upgradeable, Ownable2StepUpgradeable, EIP712Upgradeable, IERC165, IVenuePolicy {
    struct Metadata { string name; string symbol; string uri; }
    bytes32 private constant METADATA_SLOT = keccak256("test.token.metadata.v1");
    struct Venues { address registrar; PoolKey[] pools; }
    bytes32 private constant VENUES_SLOT = keccak256("test.token.venues.v1");
    event MetadataUpdated(string name, string symbol, string uri);

    constructor() { _disableInitializers(); }

    function initialize(address administrator, address signer_, string calldata n, string calldata s, string calldata uri, uint256 reserveSupply_, uint256 sourceLimit_, address retiredToken_, uint256 ownerRolloverLimit_) external initializer {
        __ERC20_init(n, s);
        __Ownable_init(administrator);
        __Ownable2Step_init();
        _setMetadata(n, s, uri);
        require(signer_ != address(0));
        __EIP712_init("Claus Migration Receipt", "3");
        _migration().signer = signer_;
        _migration().paused = true;
        require(reserveSupply_ > 0 && sourceLimit_ > 0 && retiredToken_.code.length > 0, "Invalid reserve");
        require(sourceLimit_ <= reserveSupply_ && ownerRolloverLimit_ <= reserveSupply_ - sourceLimit_, "Reserve overallocated");
        Reserve storage r = _reserve();
        r.initialSupply = reserveSupply_;
        r.sourceLimit = sourceLimit_;
        r.retiredToken = retiredToken_;
        r.ownerRolloverLimit = ownerRolloverLimit_;
        _mint(address(this), reserveSupply_);
        emit VenueEnforcementChanged(VenueEnforcement.Preferred);
        emit ExternalVenuesChanged();
    }


    // The signer attests finalized source receipts; this is an explicit trust boundary,
    // not an Ethereum light client. Any gas payer may deliver the signed receipt.
    address public constant SOURCE_TOKEN = 0x1b54E762aa34CF6E28E9C082F2848e28E45DA6b8;
    uint256 public constant SOURCE_CHAIN_ID = 1;
    bytes32 public constant RECEIPT_TYPEHASH = keccak256("BurnReceipt(address sourceGate,bytes32 sourceTxHash,uint256 logIndex,address wallet,address recipient,uint256 amount)");
    struct Migration { address signer; mapping(bytes32=>bool) consumed; uint256 minted; bool paused; address sourceGate; }
    bytes32 private constant MIGRATION_SLOT = keccak256("claus.migration.receipts.v1");
    event Migrated(bytes32 indexed sourceTxHash,uint256 indexed logIndex,address indexed wallet,address recipient,uint256 amount);
    event ReceiptSignerChanged(address indexed signer);
    event MigrationPaused(bool paused);
    event SourceGateBound(address indexed gate);
    function SOURCE_GATE() external view returns(address){return _migration().sourceGate;}
    function setSourceGate(address gate) external onlyOwner {
        require(gate!=address(0)&&_migration().sourceGate==address(0),"Gate already bound");
        _migration().sourceGate=gate;emit SourceGateBound(gate);
    }
    function receiptSigner() external view returns(address){return _migration().signer;}
    function migrationPaused() external view returns(bool){return _migration().paused;}
    /// @notice Cumulative migration issuance, excluding owner mints and later burns.
    function migratedSupply() external view returns(uint256){return _migration().minted;}
    function consumed(bytes32 txHash,uint256 index) external view returns(bool){return _migration().consumed[_receiptId(txHash,index)];}
    function setReceiptSigner(address signer) external onlyOwner {require(signer!=address(0));_migration().signer=signer;emit ReceiptSignerChanged(signer);}
    function setMigrationPaused(bool paused) external onlyOwner {require(paused || _snapshot().root == bytes32(0), "Snapshot cutover active");_migration().paused=paused;emit MigrationPaused(paused);}
    function receiptDigest(bytes32 txHash,uint256 index,address wallet,address recipient,uint256 amount) public view returns(bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(RECEIPT_TYPEHASH,_migration().sourceGate,txHash,index,wallet,recipient,amount)));
    }
    function mintFromBurn(bytes32 txHash,uint256 index,address wallet,address recipient,uint256 amount,bytes calldata signature) external {
        Migration storage m=_migration();bytes32 id=_receiptId(txHash,index);
        require(m.sourceGate!=address(0) && !m.paused && !m.consumed[id] && txHash!=bytes32(0) && wallet!=address(0) && amount!=0,"Invalid receipt");
        require(recipient!=address(0) && recipient!=address(this) && recipient!=SOURCE_TOKEN && recipient!=address(0xdead),"Invalid recipient");
        require(ECDSA.recover(receiptDigest(txHash,index,wallet,recipient,amount),signature)==m.signer,"Invalid signer");
        require(amount <= _reserve().sourceLimit - m.minted, "Migration reserve exhausted");
        m.consumed[id]=true;m.minted+=amount;
        _transfer(address(this),recipient,amount);emit Migrated(txHash,index,wallet,recipient,amount);
    }
    function _receiptId(bytes32 txHash,uint256 index) private view returns(bytes32){return keccak256(abi.encode(SOURCE_CHAIN_ID,SOURCE_TOKEN,_migration().sourceGate,txHash,index));}
    function _migration() private pure returns(Migration storage m){bytes32 slot=MIGRATION_SLOT;assembly{m.slot:=slot}}

    // These allocations are disjoint. Unallocated reserve has no transfer path.
    // Proxy administration can still replace this policy, as publicly disclosed.
    struct Reserve {
        uint256 initialSupply;
        uint256 sourceLimit;
        address retiredToken;
        uint256 ownerRolloverLimit;
        uint256 rolledOver;
        bool rolloverClosed;
        bool busy;
    }
    bytes32 private constant RESERVE_SLOT = keccak256("claus.migration.reserve.v1");
    event RetiredInventoryConverted(address indexed token,address indexed owner,uint256 amount);
    event RolloverClosed();
    function initialReserveSupply() external view returns(uint256){return _reserve().initialSupply;}
    function sourceMigrationLimit() external view returns(uint256){return _reserve().sourceLimit;}
    function retiredToken() external view returns(address){return _reserve().retiredToken;}
    function ownerRolloverLimit() external view returns(uint256){return _reserve().ownerRolloverLimit;}
    function rolledOverSupply() external view returns(uint256){return _reserve().rolledOver;}
    function rolloverClosed() external view returns(bool){return _reserve().rolloverClosed;}
    function migrationReserveRemaining() external view returns(uint256){return _reserve().sourceLimit-_migration().minted-_snapshot().distributed;}
    function unallocatedReserve() external view returns(uint256){
        Reserve storage r=_reserve();return r.initialSupply-r.sourceLimit-r.ownerRolloverLimit;
    }
    function convertRetiredInventory(uint256 amount) external onlyOwner {
        Reserve storage r=_reserve();
        require(!r.rolloverClosed && !r.busy && amount>0 && amount<=r.ownerRolloverLimit-r.rolledOver,"Invalid rollover");
        r.busy=true;r.rolledOver+=amount;
        IRetiredClaus old=IRetiredClaus(r.retiredToken);
        uint256 beforeBalance=old.balanceOf(address(this));uint256 beforeSupply=old.totalSupply();
        require(old.transferFrom(msg.sender,address(this),amount),"Transfer failed");
        require(old.balanceOf(address(this))==beforeBalance+amount,"Incorrect transfer");
        old.burn(amount);
        require(old.balanceOf(address(this))==beforeBalance && old.totalSupply()==beforeSupply-amount,"Incorrect burn");
        _transfer(address(this),msg.sender,amount);r.busy=false;
        emit RetiredInventoryConverted(address(old),msg.sender,amount);
    }
    function closeRollover() external onlyOwner {
        require(!_reserve().busy,"Busy");_reserve().rolloverClosed=true;emit RolloverClosed();
    }
    function _reserve() private pure returns(Reserve storage r){bytes32 slot=RESERVE_SLOT;assembly{r.slot:=slot}}

    // Snapshot distribution releases the existing reserve. It never mints tokens
    // and never fabricates a source burn. Historical receipt accounting stays intact.
    struct Snapshot {
        bytes32 root;
        bytes32 sourceBlockHash;
        uint256 sourceBlock;
        uint256 allocation;
        uint256 distributed;
        mapping(uint256 => uint256) claimedWords;
        mapping(uint256 => address) resolvedRecipients;
    }
    struct SnapshotClaim {
        uint256 index;
        address sourceAccount;
        address recipient;
        uint256 amount;
        bytes32[] proof;
    }
    bytes32 private constant SNAPSHOT_SLOT = keccak256("claus.snapshot.airdrop.v1");
    event SnapshotBound(bytes32 indexed root, uint256 sourceBlock, bytes32 sourceBlockHash, uint256 allocation, uint256 historicalBurnReleases);
    event SnapshotDistributed(uint256 indexed index, address indexed sourceAccount, address indexed recipient, uint256 amount);
    event SnapshotRecipientResolved(uint256 indexed index, address indexed sourceAccount, address indexed recipient);
    function snapshotInfo() external view returns(bytes32 root, uint256 sourceBlock, bytes32 sourceBlockHash, uint256 allocation, uint256 distributed) {
        Snapshot storage s = _snapshot(); return(s.root,s.sourceBlock,s.sourceBlockHash,s.allocation,s.distributed);
    }
    function bindSnapshot(bytes32 root, uint256 sourceBlock, bytes32 sourceBlockHash, uint256 allocation, uint256 historicalBurnReleases) external onlyOwner {
        Snapshot storage s = _snapshot(); Migration storage m = _migration();
        require(s.root == bytes32(0), "Snapshot already bound");
        require(m.paused && m.minted == historicalBurnReleases, "Settle and close old receipts first");
        require(root != bytes32(0) && sourceBlock > 0 && sourceBlockHash != bytes32(0) && allocation > 0, "Invalid snapshot");
        require(allocation <= _reserve().sourceLimit - m.minted && allocation <= balanceOf(address(this)), "Reserve overallocated");
        s.root=root;s.sourceBlock=sourceBlock;s.sourceBlockHash=sourceBlockHash;s.allocation=allocation;
        emit SnapshotBound(root,sourceBlock,sourceBlockHash,allocation,historicalBurnReleases);
    }
    function snapshotClaimed(uint256 index) public view returns(bool) {
        return (_snapshot().claimedWords[index >> 8] & (uint256(1) << (index & 255))) != 0;
    }
    function snapshotLeaf(uint256 index,address sourceAccount,address recipient,uint256 amount) public view returns(bytes32) {
        Snapshot storage s=_snapshot();
        return keccak256(bytes.concat(keccak256(abi.encode(block.chainid,address(this),SOURCE_CHAIN_ID,SOURCE_TOKEN,s.sourceBlock,s.sourceBlockHash,index,sourceAccount,recipient,amount))));
    }
    function snapshotRecipient(uint256 index) external view returns(address) {return _snapshot().resolvedRecipients[index];}
    /// @notice A zero-recipient leaf preserves a custody entitlement until its
    /// beneficiary has been verified. It cannot be delivered to an inaccessible
    /// same-address contract on a different chain. Resolution is public and final.
    function resolveSnapshotRecipient(SnapshotClaim calldata c,address recipient) external onlyOwner {
        Snapshot storage s=_snapshot();
        require(s.root!=bytes32(0) && c.recipient==address(0) && c.amount>0 && c.sourceAccount!=address(0),"Invalid custody allocation");
        require(recipient!=address(0) && recipient!=address(this) && recipient!=SOURCE_TOKEN && recipient!=address(0xdead),"Invalid recipient");
        require(!snapshotClaimed(c.index) && s.resolvedRecipients[c.index]==address(0),"Recipient already final");
        require(MerkleProof.verifyCalldata(c.proof,s.root,snapshotLeaf(c.index,c.sourceAccount,address(0),c.amount)),"Invalid snapshot proof");
        s.resolvedRecipients[c.index]=recipient;
        emit SnapshotRecipientResolved(c.index,c.sourceAccount,recipient);
    }
    /// @notice Any gas payer can deliver. Proofs fix the recipient and amount.
    function distributeSnapshot(SnapshotClaim[] calldata claims) external {
        Snapshot storage s=_snapshot(); require(s.root!=bytes32(0), "Snapshot not bound");
        require(claims.length>0 && claims.length<=80, "Invalid batch size");
        for(uint256 i;i<claims.length;++i){
            SnapshotClaim calldata c=claims[i];
            require(c.amount>0 && c.sourceAccount!=address(0), "Invalid allocation");
            require(MerkleProof.verifyCalldata(c.proof,s.root,snapshotLeaf(c.index,c.sourceAccount,c.recipient,c.amount)), "Invalid snapshot proof");
            if(snapshotClaimed(c.index))continue; // Safe to resume or race another relayer.
            address recipient=c.recipient==address(0)?s.resolvedRecipients[c.index]:c.recipient;
            require(recipient!=address(0) && recipient!=address(this) && recipient!=SOURCE_TOKEN && recipient!=address(0xdead), "Invalid recipient");
            require(c.amount<=s.allocation-s.distributed, "Snapshot allocation exceeded");
            s.claimedWords[c.index >> 8] |= uint256(1) << (c.index & 255);
            s.distributed+=c.amount;
            _transfer(address(this),recipient,c.amount);
            emit SnapshotDistributed(c.index,c.sourceAccount,recipient,c.amount);
        }
    }
    function _snapshot() private pure returns(Snapshot storage s){bytes32 slot=SNAPSHOT_SLOT;assembly{s.slot:=slot}}

    // General issuance is explicitly authorized by the token owner, not by the
    // deployer, receipt signer or holder. It never consumes or settles a burn.
    // A future mining mechanism requires an owner-approved implementation change.
    struct Issuance { uint256 adminMinted; }
    bytes32 private constant ISSUANCE_SLOT = keccak256("claus.token.issuance.v1");
    event AdminMinted(address indexed administrator,address indexed recipient,uint256 amount);
    /// @notice Cumulative owner issuance, not reduced by subsequent holder burns.
    function adminMintedSupply() external view returns(uint256){return _issuance().adminMinted;}
    function mint(address recipient,uint256 amount) external onlyOwner {
        require(amount!=0,"Invalid amount");
        require(recipient!=address(0) && recipient!=address(this) && recipient!=SOURCE_TOKEN && recipient!=address(0xdead),"Invalid recipient");
        _issuance().adminMinted+=amount;
        _mint(recipient,amount);
        emit AdminMinted(msg.sender,recipient,amount);
    }
    function _issuance() private pure returns(Issuance storage s){bytes32 slot=ISSUANCE_SLOT;assembly{s.slot:=slot}}

    function name() public view override returns (string memory) { return _metadata().name; }
    function symbol() public view override returns (string memory) { return _metadata().symbol; }
    function tokenURI() external view returns (string memory) { return _metadata().uri; }
    function burn(uint256 amount) external { _burn(msg.sender, amount); }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IVenuePolicy).interfaceId;
    }
    function venueEnforcement() external pure returns (VenueEnforcement) { return VenueEnforcement.Preferred; }
    function venueAllowed(address, bytes32, bool) external pure returns (bool) { return true; }
    function externalVenues() external pure returns (bool, bool, ExternalVenue[] memory) {
        return (false, false, new ExternalVenue[](0));
    }
    function canonicalPools() external view returns (PoolKey[] memory) { return _venues().pools; }

    // The one-use launcher registers the actual initialized pool before the opening buy.
    // This grants no transfer authority and is consumed in the same launch transaction.
    function registerCanonicalPool(PoolKey calldata key) external {
        Venues storage v = _venues();
        require(msg.sender == v.registrar && v.registrar != address(0) && v.pools.length == 0, "Invalid registrar");
        _validatePool(key);
        v.registrar = address(0);
        v.pools.push(key);
        emit CanonicalPoolsChanged();
    }
    function setCanonicalPools(PoolKey[] calldata keys) external onlyOwner {
        require(keys.length <= 16, "Too many preferred pools");
        Venues storage v = _venues();
        // Owner changes also permanently close any unused bootstrap registration.
        v.registrar = address(0);
        delete v.pools;
        for (uint256 i; i < keys.length; ++i) {
            _validatePool(keys[i]);
            for (uint256 j; j < i; ++j) require(keccak256(abi.encode(keys[i])) != keccak256(abi.encode(keys[j])), "Duplicate pool");
            v.pools.push(keys[i]);
        }
        emit CanonicalPoolsChanged();
    }
    function _validatePool(PoolKey calldata key) private view {
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        require(c0 < c1 && (c0 == address(this) || c1 == address(this)), "Invalid currencies");
        require(key.tickSpacing > 0 && key.tickSpacing <= 32767, "Invalid spacing");
        require(key.fee <= 1_000_000 || key.fee == 0x800000, "Invalid pool fee");
    }
    function _venues() private pure returns (Venues storage v) {
        bytes32 slot = VENUES_SLOT;
        assembly { v.slot := slot }
    }

    function updateMetadata(string calldata n, string calldata s, string calldata uri) external onlyOwner {
        _setMetadata(n, s, uri);
    }

    function _setMetadata(string memory n, string memory s, string memory uri) private {
        require(bytes(n).length > 0 && bytes(n).length <= 128 && bytes(s).length > 0
            && bytes(s).length <= 32 && bytes(uri).length <= 2048, "Invalid metadata");
        Metadata storage m = _metadata();
        m.name = n; m.symbol = s; m.uri = uri;
        emit MetadataUpdated(n, s, uri);
    }

    function _metadata() private pure returns (Metadata storage m) {
        bytes32 slot = METADATA_SLOT;
        assembly { m.slot := slot }
    }
}
