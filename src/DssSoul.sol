//
// TODO: ASCII ART
//

// SPDX-FileCopyrightText: © 2022 Nazzareno Massari @naszam
// SPDX-License-Identifier: AGPL-3.0-or-later

// dss-soul --- dss soulbound nfts

pragma solidity ^0.8.7;

// https://github.com/brianmcmichael/erc721
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
interface ERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 nft) external view returns (string memory);
}

interface ERC721Enumerable {
    function totalSupply() external view returns (uint256);
    function tokenByIndex(uint256 idx) external view returns (uint256);
    function tokenOfOwnerByIndex(address usr, uint256 idx) external view returns (uint256);
}

interface ERC721Events {
    event Transfer(address indexed src, address indexed dst, uint256 nft);
    event Approval(address indexed src, address indexed usr, uint256 nft);
    event ApprovalForAll(address indexed usr, address indexed op, bool ok);
}

interface ERC721TokenReceiver {
    function onERC721Received(address op, address src, uint256 nft, bytes calldata what) external returns(bytes4);
}

interface ERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface ERC721 is ERC165, ERC721Events, ERC721TokenReceiver {
    function balanceOf(address usr) external view returns (uint256);
    function ownerOf(uint256 nft) external view returns (address);
    function safeTransferFrom(address src, address dst, uint256 nft, bytes calldata what) external payable;
    function safeTransferFrom(address src, address dst, uint256 nft) external payable;
    function transferFrom(address src, address dst, uint256 nft) external payable;
    function approve(address usr, uint256 nft) external payable;
    function setApprovalForAll(address op, bool ok) external;
    function getApproved(uint256 nft) external returns (address);
    function isApprovedForAll(address usr, address op) external view returns (bool);
}

contract DssSoul is ERC721, ERC721Enumerable, ERC721Metadata {

    // --- Data ---
    mapping (address => uint256) public wards;

    struct Kin {
        string item;
        string tale;
        string loot;
    }
    mapping(uint256 => Kin) public kins;

    string public link; // Base URI

    uint256 public ids; // Item IDs

    bytes32 public root;

    mapping(uint256 => string) private _uris;

    mapping(uint256 => address) private _souls;

    uint256 private _nfts;

    // --- ERC721 ---

    string public name;
    string public symbol;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Init(uint256 kin, string item, string tale, string loot);
    event File(bytes32 indexed what, bytes32 data);
    event File(bytes32 indexed what, string data);
    event File(uint256 indexed id, bytes32 indexed what, string data);
    event Bind(uint256 indexed);

    constructor(string memory name_, string memory symbol_)
    {
        name = name_;     // "DSS Soulbound"
        symbol = symbol_; // "KIN"
        link = "https://ipfs.io/ipfs/";
    }

    // --- Auth ---
    modifier auth {
        require(wards[msg.sender] == 1, "DssSoul/not-authorized");
        _;
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    // --- Math ---
    function toUint96(uint256 x) internal pure returns (uint96 z) {
        require((z = uint96(x)) == x, "DssSoul/uint96-overflow");
    }

    // --- Admin ---
    function init(
        string calldata item,
        string calldata tale,
        string calldata loot
    ) external auth {
        uint256 id = ids++;

        kins[id].item = item;
        kins[id].tale = tale;
        kins[id].loot = loot;

        emit Init(id, item, tale, loot);
    }

    function file(bytes32 what, bytes32 data) external auth {
        if (what == "root") root = data;
        else revert("DssSoul/file-unrecognized-param");
        emit File(what, data);
    }

    function file(bytes32 what, string calldata data) external auth {
        if (what == "link") link = data;
        else revert("DssSoul/file-unrecognized-param");
        emit File(what, data);
    }

    function file(uint256 id, bytes32 what, string calldata data) external auth {
        require(ids > id, "DssSoul/invalid-kin-id");
        if      (what == "item") kins[id].item = data;
        else if (what == "tale") kins[id].tale = data;
        else if (what == "loot") kins[id].loot = data;
        else revert("DssSoul/file-unrecognized-param");
        emit File(id, what, data);
    }

    // --- Soulbound ---
    function bind(
        bytes32[] calldata proof,
        uint256 _kin,
        string calldata uri
    ) external {
        require(ids > _kin, "DssSoul/invalid-kin-id");
        require(
            proof.verify(root, msg.sender),
            "DssSoul/only-soul"
        );

        uint256 _nft = _bind(msg.sender, _kin);

        _mint(msg.sender, _nft, uri);

        emit Bind(_nft);
    }

    function nft(address _soul, uint256 _kin) external view returns (uint256 _nft) {
        require(ids > _kin, "DssSoul/invalid-kin-id");
        _nft = _bind(_soul, _kin);
        require(live(_nft), "DssSoul/invalid-nft-id");
    }

    function _bind(address _soul, uint256 _kin) private pure returns (uint256 _nft) {
        bytes memory _bound = abi.encodePacked(_soul, toUint96(_kin));
        assembly {
            _nft := mload(add(_bound, add(0x20, 0)))
        }
    }

    function soul(uint256 _nft) external view returns (address _soul) {
        require(live(_nft), "DssSoul/invalid-nft-id");
        (_soul, ) = _unbind(_nft);
    }
    function kin(uint256 _nft) external view returns (uint256 _kin) {
        require(live(_nft), "DssSoul/invalid-nft-id");
        (, _kin) = _unbind(_nft);
    }

    function _unbind(uint256 _nft) private pure returns (address _soul, uint256 _kin) {
        // shift _nft by 96 bits and convert to address
        _soul = address(uint160(_nft >> 96));
        // mask lower 96 bits
        _kin  = _nft & type(uint96).max;
    }

    function _mint(address _to, uint256 _nft, string calldata _uri) private {
        require(_to != address(0), "DssSoul/invalid-address");
        require(!live(_nft), "DssSoul/nft-already-minted");

        _nfts++;
        _souls[_nft] = _to;
        _uris[_nft] = _uri;

        emit Transfer(address(0), _to, _nft);
    }
    function live(uint256 _nft) public view returns (bool _live) {
        _live = _souls[_nft] != address(0);
    }

    // Implementation TODOs

    // --- ERC721 ---

    // --- MerkleProof ---
}
