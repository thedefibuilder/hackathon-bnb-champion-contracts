// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { IBucketHub } from "@bnb-chain/greenfield-contracts/contracts/interface/IBucketHub.sol";

import { IGnfdAccessControl } from "@bnb-chain/greenfield-contracts/contracts/interface/IGnfdAccessControl.sol";

import { GreenPressHub } from "../src/GreenPressHub.sol";

import { console2 } from "forge-std/src/console2.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    address private constant _BUCKET_HUB = 0x5BB17A87D03620b313C39C24029C94cB5714814A;
    bytes32 public constant ROLE_CREATE = keccak256("ROLE_CREATE");

    function run() public broadcast {
        GreenPressHub hub = GreenPressHub(0x61Ad6a70979404d2A7Ca26163EaB86d4A104A0e2);

        // IGnfdAccessControl(_BUCKET_HUB).grantRole(ROLE_CREATE, address(hub), block.timestamp + 10 * 365 days);

        uint256 fee = hub.getCreateSpaceFee();
        // hub.createSpace{ value: fee }("barabula-test-hub-bratan");

        // hub.publishTemplate{ value: fee }("barabula-template-bratan", 1);

        uint256 tokenId = hub.getTemplateId("barabula-template-bratan");
        uint256 price = hub.getTemplatePrice("barabula-template-bratan");
        // console2.log("Template ID: ", tokenId);
        hub.buyTemplate{ value: price + fee }(tokenId);
    }
}
