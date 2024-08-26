// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import { ITokenHub } from "@bnb-chain/greenfield-contracts/contracts/interface/ITokenHub.sol";
import { IBucketHub, BucketStorage } from "@bnb-chain/greenfield-contracts/contracts/interface/IBucketHub.sol";
import { IGnfdAccessControl } from "@bnb-chain/greenfield-contracts/contracts/interface/IGnfdAccessControl.sol";
import { GroupApp } from "@bnb-chain/greenfield-contracts-sdk/GroupApp.sol";
import { BucketApp } from "@bnb-chain/greenfield-contracts-sdk/BucketApp.sol";
import { GroupStorage } from "@bnb-chain/greenfield-contracts/contracts/interface/IGroupHub.sol";
import { PackageQueue } from
    "@bnb-chain/greenfield-contracts/contracts/middle-layer/resource-mirror/storage/PackageQueue.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IPermissionHub } from "./IPermissionHub.sol";

import { console2 } from "forge-std/src/console2.sol";

contract GreenPressHub is GroupApp, BucketApp {
    address private constant _TOKEN_HUB = 0xED8e5C546F84442219A5a987EE1D820698528E04;
    address private constant _CROSS_CHAIN = 0xa5B2c9194131A4E0BFaCbF9E5D6722c873159cb7;
    address private constant _BUCKET_HUB = 0x5BB17A87D03620b313C39C24029C94cB5714814A;
    address private constant _GROUP_HUB = 0x50B3BF0d95a8dbA57B58C82dFDB5ff6747Cc1a9E;
    address private constant _PERMISSION_HUB = 0x25E1eeDb5CaBf288210B132321FBB2d90b4174ad;
    address private constant _SP_ADDRESS_TESTNET = 0x5FFf5A6c94b182fB965B40C7B9F30199b969eD2f;
    address private constant _GREENFIELD_EXECUTOR = 0x3E3180883308e8B4946C9a485F8d91F8b15dC48e;

    uint64 private constant _chargedReadQuota = 10_000 * 1024 * 1024;
    uint256 private constant _callbackGasLimit = 1_000_000;
    PackageQueue.FailureHandleStrategy private constant _failureHandleStrategy =
        PackageQueue.FailureHandleStrategy.CacheOnFail;

    mapping(uint256 groupId => uint256 price) private _templatePrice;
    mapping(uint256 groupId => address creator) private _templateCreator;
    mapping(string groupName => uint256 groupId) private _groupNameToId;

    event TemplatePublished(string groupName, uint256 tokenId, uint256 price, address creator);
    event TemplatePurchased(address buyer, uint256 tokenId, uint256 price);
    event TemplatePurchaseFailed(address buyer, uint256 tokenId, uint256 price);

    constructor() initializer {
        IGnfdAccessControl(_BUCKET_HUB).grantRole(ROLE_CREATE, msg.sender, block.timestamp + 10 * 365 days);

        __base_app_init_unchained(_CROSS_CHAIN, _callbackGasLimit, uint8(_failureHandleStrategy));
        __group_app_init_unchained(_GROUP_HUB);
        __bucket_app_init_unchained(_BUCKET_HUB);
    }

    function greenfieldCall(
        uint32 status,
        uint8 resourceType,
        uint8 operationType,
        uint256 resourceId,
        bytes calldata callbackData
    )
        external
        override(BucketApp, GroupApp)
    {
        console2.log("BARABULA QWTF");
        if (msg.sender == _GROUP_HUB || msg.sender == _BUCKET_HUB) {
            console2.log("BARABULA QWTF 1");
            if (resourceType == RESOURCE_GROUP) {
                console2.log("BARABULA QWTF 2");
                _groupGreenfieldCall(status, operationType, resourceId, callbackData);
            } else if (resourceType == RESOURCE_BUCKET) {
                console2.log("BARABULA QWTF 3");
                _bucketGreenfieldCall(status, operationType, resourceId, callbackData);
            } else {
                revert("MarketPlace: invalid resource type");
            }
        } else {
            revert("invalid caller");
        }
    }

    function createSpace(string calldata name) external payable {
        uint256 totalfee = _getTotalFee();
        require(msg.value >= totalfee * 3, "relay fees not enough");

        ITokenHub(_TOKEN_HUB).transferOut{ value: totalfee * 2 }(msg.sender, totalfee);

        BucketStorage.CreateBucketSynPackage memory createPkg = BucketStorage.CreateBucketSynPackage({
            creator: msg.sender,
            name: name,
            visibility: BucketStorage.BucketVisibilityType.Private,
            paymentAddress: msg.sender,
            primarySpAddress: _SP_ADDRESS_TESTNET,
            primarySpApprovalExpiredHeight: 0,
            globalVirtualGroupFamilyId: 1,
            primarySpSignature: "",
            chargedReadQuota: _chargedReadQuota,
            extraData: ""
        });

        IBucketHub(_BUCKET_HUB).createBucket{ value: totalfee }(createPkg);
    }

    function buyTemplate(uint256 groupId) external payable {
        uint256 templatePrice = _templatePrice[groupId];
        uint256 relayFees = _getTotalFee();

        require(templatePrice > 0, "template does not exists");
        require(msg.value >= templatePrice + relayFees, "insufficient funds");

        address[] memory members = new address[](1);
        uint64[] memory expirations = new uint64[](1);
        members[0] = msg.sender;
        expirations[0] = 0;

        bytes memory callbackData = abi.encode(msg.sender);

        _updateGroup(
            address(this),
            groupId,
            GroupStorage.UpdateGroupOpType.AddMembers,
            members,
            expirations,
            msg.sender,
            _failureHandleStrategy,
            callbackData,
            _callbackGasLimit
        );
    }

    function publishTemplate(string calldata groupName, uint256 price) external payable {
        uint256 relayFees = _getTotalFee();
        require(price > 0, "invalid price");
        require(_groupNameToId[groupName] == 0, "template already exists");
        require(msg.value >= relayFees, "relay fees not enough");

        bytes memory callbackData = abi.encode(msg.sender, price, groupName);
        _createGroup(address(this), _failureHandleStrategy, callbackData, address(this), groupName, _callbackGasLimit);
    }

    function createPolicy(bytes calldata policyData) external payable {
        uint256 totalfee = _getTotalFee();
        require(msg.value >= totalfee, "relay fees not enough");
        IPermissionHub(_PERMISSION_HUB).createPolicy{ value: totalfee }(policyData);
    }

    function getTemplateId(string calldata groupName) public view returns (uint256) {
        return _groupNameToId[groupName];
    }

    function getTemplatePrice(string calldata groupName) public view returns (uint256) {
        return _templatePrice[getTemplateId(groupName)];
    }

    function getCreateSpaceFee() external view returns (uint256) {
        return _getTotalFee() * 3;
    }

    function getRelayFee() external view returns (uint256) {
        return _getTotalFee();
    }

    function _createGroupCallback(uint32 status, uint256 tokenId, bytes memory callbackData) internal override {
        if (status == STATUS_SUCCESS) {
            (address creator, uint256 price, string memory groupName) =
                abi.decode(callbackData, (address, uint256, string));

            _templatePrice[tokenId] = price;
            _templateCreator[tokenId] = creator;
            _groupNameToId[groupName] = tokenId;

            emit TemplatePublished(groupName, tokenId, price, creator);
        }
    }

    function _updateGroupCallback(uint32 status, uint256 tokenId, bytes memory callbackData) internal override {
        (address buyer) = abi.decode(callbackData, (address));
        uint256 price = _templatePrice[tokenId];

        if (status == STATUS_SUCCESS) {
            Address.sendValue(payable(_templateCreator[tokenId]), price);

            emit TemplatePurchased(buyer, tokenId, price);
        } else {
            // refund on failure
            Address.sendValue(payable(buyer), price);
            emit TemplatePurchaseFailed(buyer, tokenId, price);
        }
    }
}
