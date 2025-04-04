SnaxxIs
0x60Cc4efAFE04E887ccdF140B173a4f9945a56632
snaxxis NFT id1


0xC308E335320b45DeF684D9CEC97eE9c8b82142a0




// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./IERC721.sol";
import "./IERC3525.sol";
import "./IERC721Receiver.sol";
import "./IERC3525Receiver.sol";
import "./extensions/IERC721Enumerable.sol";
import "./extensions/IERC721Metadata.sol";
import "./extensions/IERC3525Metadata.sol";
import "./periphery/interface/IERC3525MetadataDescriptor.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract AssetRegistry is Context, IERC3525Metadata, IERC721Enumerable, Ownable {
    using Strings for address;
    using Strings for uint256;
    using Address for address payable;

    struct Asset {
        address owner;
        uint256 funds;
    }

    uint256 public protocolFee; // Protocol fee in percentage
    mapping(uint256 => Asset) public assets; // slotId => Asset
  mapping(uint256=>mapping(address => mapping(address => uint256)))   public _withdrawableFunds; // slotId=>assetOwner => (tokenAddress => funds)


    event AssetMinted(uint256 slot, address indexed to, uint256 tokenId);


    event SetMetadataDescriptor(address indexed metadataDescriptor);

    struct AssetData {
        uint256 id;
        uint256 slot;
        uint256 balance;
        address owner;
        address approved;
        address[] valueApprovals;
    }

    modifier onlyAssetOwner(address _caller,uint256 slotId){
        require(_caller==assets[slotId].owner,"Assets:Only Asset Owner");
        _;
    }

    mapping(uint256 => address[]) private _assetOwners;
    mapping(uint256 => mapping(address => uint256)) private _ownerIndices;

    address private constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;//5000000000000000000

    struct AddressData {
        uint256[] ownedTokens;
        mapping(uint256 => uint256) ownedTokensIndex;
        mapping(address => bool) approvals;
    }

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _tokenIdGenerator;
    mapping(uint256 => uint256) private _slotTotalValue;
    mapping(uint256 => uint256) private _slotValueCap;
    uint256[] private _allSlots;
    mapping(uint256 => string) private _slotURIs;

    



    // id => (approval => allowance)
    // @dev _approvedValues cannot be defined within AssetData, cause struct containing mappings cannot be constructed.
    mapping(uint256 => mapping(address => uint256)) private _approvedValues;

    mapping(uint256 => uint256) public assetFractionalPriceUSD;

    AssetData[] public _allTokens;
    mapping(uint256=>AssetData) asset;

    // key: id
    mapping(uint256 => uint256) public _allTokensIndex;

    mapping(address => AddressData) private _addressData;

    IERC3525MetadataDescriptor public metadataDescriptor;

    mapping(uint256 => string) private _tokenURIs;

   

    constructor(address initialOwner) Ownable(initialOwner){
        _tokenIdGenerator = 1;
        _name = "SnaxxIs";
        _symbol = "f_DOG";
        _decimals = 18;
    }

receive() external payable { }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC3525).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC3525Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId || 
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    /**
     * @dev Returns the token collection name.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }


    /**
     * @dev Returns the number of decimals the token uses for value.
     */
    function valueDecimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function balanceOf(uint256 tokenId_) public view virtual override returns (uint256) {
        _requireMinted(tokenId_);
        return _allTokens[_allTokensIndex[tokenId_]].balance;
    }

    function getTotalAssetTokensMinted(uint256 slotId) public view returns (uint256) {
    return _slotTotalValue[slotId];
}

function getAssetTotalSupply(uint256 slotId) public view returns (uint256) {
    return _slotValueCap[slotId];
}
    

    function ownerOf(uint256 tokenId_) public view virtual override returns (address owner_) {
        _requireMinted(tokenId_);
        owner_ = _allTokens[_allTokensIndex[tokenId_]].owner;
        require(owner_ != address(0), "AssetRegistry: invalid token ID");
    }

    function slotOf(uint256 tokenId_) public view virtual override returns (uint256) {
        _requireMinted(tokenId_);
        return _allTokens[_allTokensIndex[tokenId_]].slot;
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function _setSlotURI(uint256 slot, string memory uri) internal {
    _slotURIs[slot] = uri;
    }

    function getSlotFromTokenId(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "ERC3525: tokenId does not exist");
    return _allTokens[_allTokensIndex[tokenId]].slot;
}



    function contractURI() public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return 
            address(metadataDescriptor) != address(0) ? 
                metadataDescriptor.constructContractURI() :
                bytes(baseURI).length > 0 ? 
                    string(abi.encodePacked(baseURI, "contract/", Strings.toHexString(address(this)))) : 
                    "";
    }

    function slotURI(uint256 slot_) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return 
            address(metadataDescriptor) != address(0) ? 
                metadataDescriptor.constructSlotURI(slot_) : 
                bytes(baseURI).length > 0 ? 
                    string(abi.encodePacked(baseURI, "slot/", slot_.toString())) : 
                    "";
    }

    function getSlotURI(uint256 slot) public view returns (string memory) {
    require(_slotExists(slot), "AssetRegistry: Nonexistent slot");
    return _slotURIs[slot];
}

     function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "AssetRegistry: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
/*
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "AssetRegistry: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }*/

   

    function setTokenURI(uint256 tokenId_) public view returns (string memory) {
    string memory svgPart1 = '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600"  viewBox="0 0 600 400" fill="none"><rect width="150" height="400" fill="white"/><rect x="0.5" y="0.5" width="599" height="399"  stroke="#F9F9F9"/><g mask="url(#m_3525_1)"><rect x="150" width="450" height="400" fill="#41928E"/>';
    string memory svgPart2 = '<svg x="80" y="-25" width="600" height="600" viewBox="0 0 75 75" fill="#000000" stroke="#000000" stroke-width="0.00072"><path d="M60.64,28.1a1.24,1.24,0,0,0-1.27-1.22l-14.89-.33c.61-.91,1.51-2.05,2.78-3.57,6.16-7.36,4.19-9.8,4.19-9.8s-2.28-2-9.91,3.84c-1.31,1-2.34,1.76-3.19,2.31l.3-14.09a1.19,1.19,0,1,0-2.38,0l-.34,15.33c-2,.44-3-1.25-7.33-3.31,0,0-2.34.91-2.86,2.77a39.41,39.41,0,0,1,3.39,6.24l-14.5-.31a1.2,1.2,0,1,0-.05,2.39l14.6.31a1.28,1.28,0,0,0,.35.59L19.84,41.61l-4.57-3.24.54-1.25S12,39.7,11.5,41.34l-.14,2,1.37-.48.41-1.31L16,45.91s-.79.9-.24,1.47,1.55-.1,1.55-.1l4.35,3.1-1.32.35-.54,1.35,2,0c1.65-.39,4.4-4.13,4.4-4.13l-1.28.49-3-4.71,12.81-9.15a1.31,1.31,0,0,0,1,.45l-.32,15a1.19,1.19,0,1,0,2.38,0L38,35.23a42.17,42.17,0,0,1,5.67,3.47c1.88-.44,2.87-2.75,2.87-2.75-1.71-4.1-3.24-5.34-3.09-7l15.87.34A1.25,1.25,0,0,0,60.64,28.1Z"/></svg></g>';
    string memory svgPart3 = '  <text fill="#202020" font-family="Arial" font-size="12"><tspan x="16" y="41" font-size="16" font-weight="bold">VMANNFT</tspan><tspan x="16" y="88" font-size="15" font-weight="bold">PRODUCT NAME</tspan><tspan x="16" y="123" font-size="14" font-weight="bold" fill="#41328E">VMAN</tspan><tspan x="16" y="142">#';
    
    svgPart3 = string(
        abi.encodePacked(
            svgPart3,
            tokenId_.toString(),
            '</tspan><tspan x="16" y="260">Slot</tspan><tspan x="16" y="280">AssetId</tspan> <tspan x="16" y="300">Value</tspan><tspan x="120" y="260" text-anchor="end">',
            slotOf(tokenId_).toString(),
            '</tspan><tspan x="120" y="280" text-anchor="end">', _allTokens[_allTokensIndex[tokenId_]].id.toString(),'</tspan><tspan x="120" y="300" text-anchor="end">',_allTokens[_allTokensIndex[tokenId_]].balance.toString(),'</tspan><tspan x="16" y="344" font-size="7">Owner:'  ,
          getPartialAddress(ownerOf(tokenId_)),'</tspan><tspan x="16" y="356" font-size="7">Serial No</tspan><tspan x="516" y="380" font-size="7" fill="black" fill-opacity="0.6">Demo VMAN NFT </tspan></text></svg>'
        )
    );

    return string(abi.encodePacked(svgPart1, svgPart2, svgPart3));
}

    function getPartialAddress(address _addr) public pure returns (string memory) {
        string memory addrStr = Strings.toHexString(uint160(_addr), 20);
        bytes memory addrBytes = bytes(addrStr);
        bytes memory partialAddr = new bytes(13); // 5 chars + 5 dots + 5 chars
        for (uint256 i = 0; i < 5; i++) {
            partialAddr[i] = addrBytes[i];
        }
        partialAddr[5] = '.';
        partialAddr[6] = '.';
        partialAddr[7] = '.';
        for (uint256 i = 0; i < 5; i++) {
            partialAddr[i + 8] = addrBytes[42 - 5 + i];
        }
        return string(partialAddr);
    }


    function tokenURI(uint256 tokenId_)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{ "image":"data:image/svg+xml;base64,',
                                Base64.encode(bytes(setTokenURI(tokenId_))),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

   function getPurchasedAssets(address user) public view returns (uint256[] memory) {
    require(user != address(0), "AssetRegistry: address zero is not a valid owner");

    AddressData storage addressData = _addressData[user];
    uint256[] memory ownedTokens = addressData.ownedTokens;
    uint256[] memory tempSlots = new uint256[](ownedTokens.length);
    uint256 uniqueSlotCount = 0;

    for (uint256 i = 0; i < ownedTokens.length; i++) {
        uint256 slot = slotOf(ownedTokens[i]);
        bool isUnique = true;

        // Check if the slot is already in tempSlots
        for (uint256 j = 0; j < uniqueSlotCount; j++) {
            if (tempSlots[j] == slot) {
                isUnique = false;
                break;
            }
        }

        // If the slot is unique, add it to tempSlots
        if (isUnique) {
            tempSlots[uniqueSlotCount] = slot;
            uniqueSlotCount++;
        }
    }

    // Create an array with the exact size of unique slots
    uint256[] memory uniqueSlots = new uint256[](uniqueSlotCount);
    for (uint256 i = 0; i < uniqueSlotCount; i++) {
        uniqueSlots[i] = tempSlots[i];
    }

    return uniqueSlots;
}

function getUserAssetTokenBalance(address user, uint256 slot) public view returns (uint256) {
    require(user != address(0), "AssetRegistry: address zero is not a valid owner");

    AddressData storage addressData = _addressData[user];
    uint256[] memory ownedTokens = addressData.ownedTokens;
    uint256 totalValue = 0;

    for (uint256 i = 0; i < ownedTokens.length; i++) {
        uint256 tokenId = ownedTokens[i];
        if (slotOf(tokenId) == slot) {
            totalValue += balanceOf(tokenId);
        }
    }

    return totalValue;
}



function _isTokenExists(uint256 tokenId) public view returns (bool) {
        try this.ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

     function getAssetOwners(
        uint256 _assetId
    ) public view returns (address[] memory) {
        require(_slotExists(_assetId), "AssetRegistry: Nonexistent Asset");
        return _assetOwners[_assetId];
    }

     function _addOwner(uint256 _assetId, address _owner) internal {
    // Check if the owner already exists for this asset
    if (_ownerIndices[_assetId][_owner] == 0 && (_assetOwners[_assetId].length == 0 || _assetOwners[_assetId][0] != _owner)) {
        _assetOwners[_assetId].push(_owner);
        _ownerIndices[_assetId][_owner] = _assetOwners[_assetId].length - 1;
    }
}


    function _removeOwner(uint256 _assetId, address _owner) internal {
        uint256 index = _ownerIndices[_assetId][_owner];
        uint256 lastIndex = _assetOwners[_assetId].length - 1;
        address lastOwner = _assetOwners[_assetId][lastIndex];

        _assetOwners[_assetId][index] = lastOwner;
        _ownerIndices[_assetId][lastOwner] = index;

        _assetOwners[_assetId].pop();
        delete _ownerIndices[_assetId][_owner];
    }

    function approve(uint256 tokenId_, address to_, uint256 value_) public payable virtual override {
        address owner = AssetRegistry.ownerOf(tokenId_);
        require(to_ != owner, "AssetRegistry: approval to current owner");

        require(_isApprovedOrOwner(_msgSender(), tokenId_), "AssetRegistry: approve caller is not owner nor approved");

        _approveValue(tokenId_, to_, value_);
    }

    function allowance(uint256 tokenId_, address operator_) public view virtual override returns (uint256) {
        _requireMinted(tokenId_);
        return _approvedValues[tokenId_][operator_];
    }

    function _addSlot(uint256 slot) private {
    if (_slotTotalValue[slot] == 0) {
        _allSlots.push(slot);
    }
    }

    function getAllSlots() public view returns (uint256[] memory) {
    return _allSlots;
    }

        // Function to set the price of a given assetId in USD by admin.
    function setAssetFractionalPriceUSD(uint256 _slotId, uint256 priceUSD) public onlyAssetOwner(msg.sender,_slotId) {
        require(
            _slotExists(_slotId),
            "Asset doesn't exist"
        );

        assetFractionalPriceUSD[_slotId] = priceUSD;
    }

    // Function to get the price of a given assetId in USD.
    function getAssetFractionalPriceUSD(uint256 _slotId) public view returns (uint256) {
        require(
            _slotExists(_slotId),
            "LeasingContract: Nonexistent token"
        );

        return assetFractionalPriceUSD[_slotId];
    }



    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256 newTokenId) {
        uint256 slot=getSlotFromTokenId(fromTokenId_);
        address sender=ownerOf(fromTokenId_);
        _spendAllowance(_msgSender(), fromTokenId_, value_);
        newTokenId = _createDerivedTokenId(fromTokenId_);
        _mint(to_, newTokenId, AssetRegistry.slotOf(fromTokenId_), 0);
        _transferValue(fromTokenId_, newTokenId, value_);
          // Remove 'from' address from owners if balance is zero
        if (getUserAssetTokenBalance(sender,slot) == 0) {
            _removeOwner(slot, sender);
        }

        // Add 'to' address to owners if this is their first tokens
        if (getUserAssetTokenBalance(to_,slot) == value_) {
            _addOwner(slot, to_);
        }
    }

    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
        uint256 fromSlot=getSlotFromTokenId(fromTokenId_);
        uint256 toSlot=getSlotFromTokenId(toTokenId_);
        address sender=ownerOf(fromTokenId_);
        address reciever=ownerOf(toTokenId_);
        require(fromSlot==toSlot,"Cannot transfer value between nfts of different assets");
        _spendAllowance(_msgSender(), fromTokenId_, value_);
        _transferValue(fromTokenId_, toTokenId_, value_);

      // Remove 'from' address from owners if balance is zero
        if (getUserAssetTokenBalance(sender,fromSlot) == 0) {
            _removeOwner(fromSlot, sender);
        }

        // Add 'to' address to owners if this is their first tokens
        if (getUserAssetTokenBalance(reciever,fromSlot) == value_) {
            _addOwner(fromSlot, reciever);
        }


    }

    function balanceOf(address owner_) public view virtual override returns (uint256 balance) {
        require(owner_ != address(0), "AssetRegistry: balance query for the zero address");
        return _addressData[owner_].ownedTokens.length;
    }

    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public payable virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "AssetRegistry: transfer caller is not owner nor approved");
        uint256 slot=getSlotFromTokenId(tokenId_);
        _transferTokenId(from_, to_, tokenId_);
        // Remove 'from' address from owners if balance is zero
        _removeOwner(slot, from_);

        _addOwner(slot, to_);
    }

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) public payable virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "AssetRegistry: transfer caller is not owner nor approved");
        _safeTransferTokenId(from_, to_, tokenId_, data_);
    }

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public payable virtual override {
        safeTransferFrom(from_, to_, tokenId_, "");
    }

    function approve(address to_, uint256 tokenId_) public payable virtual override {
        address owner = AssetRegistry.ownerOf(tokenId_);
        require(to_ != owner, "AssetRegistry: approval to current owner");

        require(
            _msgSender() == owner || AssetRegistry.isApprovedForAll(owner, _msgSender()),
            "AssetRegistry: approve caller is not owner nor approved for all"
        );

        _approve(to_, tokenId_);
    }

    function getApproved(uint256 tokenId_) public view virtual override returns (address) {
        _requireMinted(tokenId_);
        return _allTokens[_allTokensIndex[tokenId_]].approved;
    }

    function setApprovalForAll(address operator_, bool approved_) public virtual override {
        _setApprovalForAll(_msgSender(), operator_, approved_);
    }

    function isApprovedForAll(address owner_, address operator_) public view virtual override returns (bool) {
        return _addressData[owner_].approvals[operator_];
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index_) public view virtual override returns (uint256) {
        require(index_ < AssetRegistry.totalSupply(), "AssetRegistry: global index out of bounds");
        return _allTokens[index_].id;
    }

    function tokenOfOwnerByIndex(address owner_, uint256 index_) public view virtual override returns (uint256) {
        require(index_ < AssetRegistry.balanceOf(owner_), "AssetRegistry: owner index out of bounds");
        return _addressData[owner_].ownedTokens[index_];
    }

    function _setApprovalForAll(
        address owner_,
        address operator_,
        bool approved_
    ) internal virtual {
        require(owner_ != operator_, "AssetRegistry: approve to caller");

        _addressData[owner_].approvals[operator_] = approved_;

        emit ApprovalForAll(owner_, operator_, approved_);
    }

    function _isApprovedOrOwner(address operator_, uint256 tokenId_) internal view virtual returns (bool) {
        address owner = AssetRegistry.ownerOf(tokenId_);
        return (
            operator_ == owner ||
            AssetRegistry.isApprovedForAll(owner, operator_) ||
            AssetRegistry.getApproved(tokenId_) == operator_
        );
    }

    function _spendAllowance(address operator_, uint256 tokenId_, uint256 value_) internal virtual {
        uint256 currentAllowance = AssetRegistry.allowance(tokenId_, operator_);
        if (!_isApprovedOrOwner(operator_, tokenId_) && currentAllowance != type(uint256).max) {
            require(currentAllowance >= value_, "AssetRegistry: insufficient allowance");
            _approveValue(tokenId_, operator_, currentAllowance - value_);
        }
    }

    function _exists(uint256 tokenId_) internal view virtual returns (bool) {
        return _allTokens.length != 0 && _allTokens[_allTokensIndex[tokenId_]].id == tokenId_;
    }

    function _slotExists(uint256 slot_) public view returns (bool) {
    for (uint i = 0; i < _allSlots.length; i++) {
        if (_allSlots[i] == slot_) {
            return true;
        }
    }
    return false;
}


    function _requireMinted(uint256 tokenId_) internal view virtual {
        require(_exists(tokenId_), "AssetRegistry: invalid token ID");
    }

    function registerAsset(address to_, uint256 slot_,string memory uri) public virtual returns (uint256 tokenId) {
        require(!_slotExists(slot_), "AssetRegistry: Asset already registered");
         if (bytes(_slotURIs[slot_]).length == 0) {
        _setSlotURI(slot_, uri);
    }
        tokenId = _createOriginalTokenId();
        _mint(to_, tokenId, slot_,0);  
        _addSlot(slot_);
        _setTokenURI(tokenId, _slotURIs[slot_]);
        setAssetOwner(slot_,to_);
    }

    // function _mint(address to_, uint256 tokenId_, uint256 slot_, uint256 value_) internal virtual override {
    // super._mint(to_, tokenId_, value_);

    // // Set the URI for the newly minted token
    // _setTokenURI(tokenId_, _slotURIs[slot_]);
    // }

function setAssetOwner(uint256 slotId,address _caller)internal{
    assets[slotId].owner=_caller;
}

function getAssetOwner(uint256 slotId)external view returns(address){
    return assets[slotId].owner;
}

    function fractionalizeAsset(uint256 slot_, uint256 totalSupply_) onlyAssetOwner(msg.sender,slot_) public virtual {
        require(_slotExists(slot_), "AssetRegistry: Asset not registered yet");
        // tokenId = _createOriginalTokenId();
        _slotValueCap[slot_] = totalSupply_;
    }

    function isFractionalized(uint256 slotId)public view returns (bool){
         require(_slotValueCap[slotId]>0,"Asset: is not registered");
         return true;
         }

    function mintAsset(uint256 slot, uint256 value, address erc20TokenAddress) public payable {
        require(assets[slot].owner != address(0), "Asset not registered");       
     //   require(msg.sender!=assets[slot].owner,"Asset:Should not be asset owner");
        require(isFractionalized(slot),"Asset: asset is not fractionalized"); 
        uint256 slotFractionalPrice=getAssetFractionalPriceUSD(slot);
        require(slotFractionalPrice!=0,"Asset:Fractional Price is not set");
        uint256 amountToBePaid=slotFractionalPrice*value;
        //

      //  require(protocolFee!=0,"ProtocolFee is not set");
        // Calculate protocol fee and net amount
        uint256 fee = (amountToBePaid* protocolFee) / 100;
        uint256 netAmount = amountToBePaid - fee;
        
        if(erc20TokenAddress == NATIVE_CURRENCY) {
            require(msg.value >= amountToBePaid, "Insufficient payment");
            // Directly transfer the protocol fee to the protocol owner
            payable(owner()).sendValue(fee);
        } else {
            // Transfer the ERC20 tokens to this contract
            IERC20(erc20TokenAddress).transferFrom(msg.sender, address(this), amountToBePaid);
            // Transfer the protocol fee portion to the protocol owner
            IERC20(erc20TokenAddress).transfer(owner(), fee);
        }

        // Allocate net amount to asset owner's balance
        _withdrawableFunds[slot][assets[slot].owner][erc20TokenAddress] += netAmount;

        // Mint the asset/NFT here and emit an event (token minting logic to be implemented)
        uint256 tokenId = 0; // Placeholder for actual token minting logic
        emit AssetMinted(slot, msg.sender, tokenId);

        // Refund any excess payment for native currency
        if(erc20TokenAddress == NATIVE_CURRENCY && msg.value > amountToBePaid) {
            payable(msg.sender).sendValue(msg.value - amountToBePaid);
        }
         tokenId = _createOriginalTokenId();
           _mint(msg.sender, tokenId, slot, value); 
        _setTokenURI(tokenId, _slotURIs[slot]);
        _slotTotalValue[slot] += value;
         if (getUserAssetTokenBalance(msg.sender,slot) == value) {
            _addOwner(slot, msg.sender);
        }  
            }

function setProtocolFee(uint256 _protocolFee)public onlyOwner{
    protocolFee=_protocolFee;
}

function getProtocolFee()public view returns(uint256){
   return protocolFee;
}
    function _mint(address to_, uint256 tokenId_, uint256 slot_, uint256 value_) internal virtual {
        require(to_ != address(0), "AssetRegistry: mint to the zero address");
        require(tokenId_ != 0, "AssetRegistry: cannot mint zero tokenId");
        require(!_exists(tokenId_), "AssetRegistry: token already minted");

        _beforeValueTransfer(address(0), to_, 0, tokenId_, slot_, value_);
        __mintToken(to_, tokenId_, slot_);
        __mintValue(tokenId_, value_);
        _afterValueTransfer(address(0), to_, 0, tokenId_, slot_, value_);
    }

    function _mintValue(uint256 tokenId_, uint256 value_) internal virtual {
        address owner = AssetRegistry.ownerOf(tokenId_);
        uint256 slot = AssetRegistry.slotOf(tokenId_);
        _beforeValueTransfer(address(0), owner, 0, tokenId_, slot, value_);
        __mintValue(tokenId_, value_);
        _afterValueTransfer(address(0), owner, 0, tokenId_, slot, value_);
    }

    function __mintValue(uint256 tokenId_, uint256 value_) private {
        _allTokens[_allTokensIndex[tokenId_]].balance += value_;
        emit TransferValue(0, tokenId_, value_);
    }

    function __mintToken(address to_, uint256 tokenId_, uint256 slot_) private {
        AssetData memory assetData = AssetData({
            id: tokenId_,
            slot: slot_,
            balance: 0,
            owner: to_,
            approved: address(0),
            valueApprovals: new address[](0)
        });

        _addTokenToAllTokensEnumeration(assetData);
        _addTokenToOwnerEnumeration(to_, tokenId_);

        emit Transfer(address(0), to_, tokenId_);
        emit SlotChanged(tokenId_, 0, slot_);
    }

    function _burn(uint256 tokenId_) internal virtual {
        _requireMinted(tokenId_);

        AssetData storage assetData = _allTokens[_allTokensIndex[tokenId_]];
        address owner = assetData.owner;
        uint256 slot = assetData.slot;
        uint256 value = assetData.balance;

        _beforeValueTransfer(owner, address(0), tokenId_, 0, slot, value);

        _clearApprovedValues(tokenId_);
        _removeTokenFromOwnerEnumeration(owner, tokenId_);
        _removeTokenFromAllTokensEnumeration(tokenId_);

        emit TransferValue(tokenId_, 0, value);
        emit SlotChanged(tokenId_, slot, 0);
        emit Transfer(owner, address(0), tokenId_);

        _afterValueTransfer(owner, address(0), tokenId_, 0, slot, value);
    }

    function _burnValue(uint256 tokenId_, uint256 burnValue_) internal virtual {
        _requireMinted(tokenId_);

        AssetData storage assetData = _allTokens[_allTokensIndex[tokenId_]];
        address owner = assetData.owner;
        uint256 slot = assetData.slot;
        uint256 value = assetData.balance;

        require(value >= burnValue_, "AssetRegistry: burn value exceeds balance");

        _beforeValueTransfer(owner, address(0), tokenId_, 0, slot, burnValue_);
        
        assetData.balance -= burnValue_;
        emit TransferValue(tokenId_, 0, burnValue_);
        
        _afterValueTransfer(owner, address(0), tokenId_, 0, slot, burnValue_);
    }

    function _addTokenToOwnerEnumeration(address to_, uint256 tokenId_) private {
        _allTokens[_allTokensIndex[tokenId_]].owner = to_;

        _addressData[to_].ownedTokensIndex[tokenId_] = _addressData[to_].ownedTokens.length;
        _addressData[to_].ownedTokens.push(tokenId_);
    }

    function _removeTokenFromOwnerEnumeration(address from_, uint256 tokenId_) private {
        _allTokens[_allTokensIndex[tokenId_]].owner = address(0);

        AddressData storage ownerData = _addressData[from_];
        uint256 lastTokenIndex = ownerData.ownedTokens.length - 1;
        uint256 lastTokenId = ownerData.ownedTokens[lastTokenIndex];
        uint256 tokenIndex = ownerData.ownedTokensIndex[tokenId_];

        ownerData.ownedTokens[tokenIndex] = lastTokenId;
        ownerData.ownedTokensIndex[lastTokenId] = tokenIndex;

        delete ownerData.ownedTokensIndex[tokenId_];
        ownerData.ownedTokens.pop();
    }

    function _addTokenToAllTokensEnumeration(AssetData memory assetData_) private {
        _allTokensIndex[assetData_.id] = _allTokens.length;
        _allTokens.push(assetData_);
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId_) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId_];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        AssetData memory lastassetData = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastassetData; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastassetData.id] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId_];
        _allTokens.pop();
    }

    function _approve(address to_, uint256 tokenId_) internal virtual {
        _allTokens[_allTokensIndex[tokenId_]].approved = to_;
        emit Approval(AssetRegistry.ownerOf(tokenId_), to_, tokenId_);
    }

    function _approveValue(
        uint256 tokenId_,
        address to_,
        uint256 value_
    ) internal virtual {
        require(to_ != address(0), "AssetRegistry: approve value to the zero address");
        if (!_existApproveValue(to_, tokenId_)) {
            _allTokens[_allTokensIndex[tokenId_]].valueApprovals.push(to_);
        }
        _approvedValues[tokenId_][to_] = value_;

        emit ApprovalValue(tokenId_, to_, value_);
    }

    function _clearApprovedValues(uint256 tokenId_) internal virtual {
        AssetData storage assetData = _allTokens[_allTokensIndex[tokenId_]];
        uint256 length = assetData.valueApprovals.length;
        for (uint256 i = 0; i < length; i++) {
            address approval = assetData.valueApprovals[i];
            delete _approvedValues[tokenId_][approval];
        }
        delete assetData.valueApprovals;
    }

    function _existApproveValue(address to_, uint256 tokenId_) internal view virtual returns (bool) {
        uint256 length = _allTokens[_allTokensIndex[tokenId_]].valueApprovals.length;
        for (uint256 i = 0; i < length; i++) {
            if (_allTokens[_allTokensIndex[tokenId_]].valueApprovals[i] == to_) {
                return true;
            }
        }
        return false;
    }

    function _transferValue(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) internal virtual {
        require(_exists(fromTokenId_), "AssetRegistry: transfer from invalid token ID");
        require(_exists(toTokenId_), "AssetRegistry: transfer to invalid token ID");

        AssetData storage fromAssetData = _allTokens[_allTokensIndex[fromTokenId_]];
        AssetData storage toAssetData = _allTokens[_allTokensIndex[toTokenId_]];

        require(fromAssetData.balance >= value_, "AssetRegistry: insufficient balance for transfer");
        require(fromAssetData.slot == toAssetData.slot, "AssetRegistry: transfer to token with different slot");

        _beforeValueTransfer(
            fromAssetData.owner,
            toAssetData.owner,
            fromTokenId_,
            toTokenId_,
            fromAssetData.slot,
            value_
        );

        fromAssetData.balance -= value_;
        toAssetData.balance += value_;

        emit TransferValue(fromTokenId_, toTokenId_, value_);

        _afterValueTransfer(
            fromAssetData.owner,
            toAssetData.owner,
            fromTokenId_,
            toTokenId_,
            fromAssetData.slot,
            value_
        );

        require(
            _checkOnERC3525Received(fromTokenId_, toTokenId_, value_, ""),
            "AssetRegistry: transfer rejected by ERC3525Receiver"
        );
    }

    function _transferTokenId(
        address from_,
        address to_,
        uint256 tokenId_
    ) internal virtual {
        require(AssetRegistry.ownerOf(tokenId_) == from_, "AssetRegistry: transfer from invalid owner");
        require(to_ != address(0), "AssetRegistry: transfer to the zero address");

        uint256 slot = AssetRegistry.slotOf(tokenId_);
        uint256 value = AssetRegistry.balanceOf(tokenId_);

        _beforeValueTransfer(from_, to_, tokenId_, tokenId_, slot, value);

        _approve(address(0), tokenId_);
        _clearApprovedValues(tokenId_);

        _removeTokenFromOwnerEnumeration(from_, tokenId_);
        _addTokenToOwnerEnumeration(to_, tokenId_);

        emit Transfer(from_, to_, tokenId_);

        _afterValueTransfer(from_, to_, tokenId_, tokenId_, slot, value);
    }

    function _safeTransferTokenId(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) internal virtual {
        _transferTokenId(from_, to_, tokenId_);
        require(
            _checkOnERC721Received(from_, to_, tokenId_, data_),
            "AssetRegistry: transfer to non ERC721Receiver"
        );
    }

    function _checkOnERC3525Received( 
        uint256 fromTokenId_, 
        uint256 toTokenId_, 
        uint256 value_, 
        bytes memory data_
    ) internal virtual returns (bool) {
        address to = AssetRegistry.ownerOf(toTokenId_);
        if (_isContract(to)) {
            try IERC165(to).supportsInterface(type(IERC3525Receiver).interfaceId) returns (bool retval) {
                if (retval) {
                    bytes4 receivedVal = IERC3525Receiver(to).onERC3525Received(_msgSender(), fromTokenId_, toTokenId_, value_, data_);
                    return receivedVal == IERC3525Receiver.onERC3525Received.selector;
                } else {
                    return true;
                }
            } catch (bytes memory /** reason */) {
                return true;
            }
        } else {
            return true;
        }
    }
    function _checkOnERC721Received(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) private returns (bool) {
        if (_isContract(to_)) {
            try 
                IERC721Receiver(to_).onERC721Received(_msgSender(), from_, tokenId_, data_) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /* solhint-disable */
    function _beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual {}

    function _afterValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual {}
    /* solhint-enable */

    function _setMetadataDescriptor(address metadataDescriptor_) internal virtual {
        metadataDescriptor = IERC3525MetadataDescriptor(metadataDescriptor_);
        emit SetMetadataDescriptor(metadataDescriptor_);
    }

    function _createOriginalTokenId() internal virtual returns (uint256) {
        return _tokenIdGenerator++;
    }

    function _createDerivedTokenId(uint256 fromTokenId_) internal virtual returns (uint256) {
        fromTokenId_;
        return _createOriginalTokenId();
    }

     function withdrawFunds(uint256 slotId,address erc20TokenAddress, uint256 amount) public onlyAssetOwner(msg.sender,slotId) {
        uint256 availableFunds = _withdrawableFunds[slotId][msg.sender][erc20TokenAddress];
        require(amount <= availableFunds, "Insufficient funds to withdraw");

        _withdrawableFunds[slotId][msg.sender][erc20TokenAddress] -= amount;
        
        if(erc20TokenAddress == NATIVE_CURRENCY) {
            payable(msg.sender).sendValue(amount);
        } else {
            IERC20(erc20TokenAddress).transfer(msg.sender, amount);
        }
    }

    function _isContract(address addr_) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr_)
        }
        return (size > 0);
    }

    fallback() external payable { }
}