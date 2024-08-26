// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

interface IPermissionHub {
    function createPolicy(bytes calldata _data) external payable returns (bool);
}
