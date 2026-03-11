// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ProposalControl} from "../src/core/ProposalControl.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envOr(
            "DEPLOYER_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );

        address[] memory govs = new address[](3);
        govs[0] = vm.envOr("GOV_1", address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        govs[1] = vm.envOr("GOV_2", address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8));
        govs[2] = vm.envOr("GOV_3", address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC));

        vm.startBroadcast(deployerKey);
        ProposalControl control = new ProposalControl(govs, 2);
        vm.stopBroadcast();

        console.log("ProposalControl:", address(control));
        console.log("AresToken:      ", address(control.aresToken()));
    }
}